import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/content.dart';
import 'reminders.dart';
import 'settings.dart';

/// One of the six daily times.
class PrayerTime {
  const PrayerTime(this.key, this.name, this.time);

  /// 'fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'.
  final String key;
  final String name;

  /// Local time on the phone.
  final DateTime time;

  bool get isSunrise => key == 'sunrise';
}

/// A calculation method the user can choose.
class CalcMethodOption {
  const CalcMethodOption(this.id, this.name, this.method);

  final String id;
  final String name;
  final CalculationMethod method;
}

/// Offline prayer times (the `adhan` package) and azan notifications.
class Prayers {
  Prayers._();

  static const names = {
    'fajr': 'ফজর',
    'sunrise': 'সূর্যোদয়',
    'dhuhr': 'যোহর',
    'asr': 'আসর',
    'maghrib': 'মাগরিব',
    'isha': 'ইশা',
  };

  /// "ফজরের", "ইশার" …
  static String genitive(String key) => key == 'isha' ? 'ইশার' : '${names[key]}ের';

  /// The five prayers that can have an azan.
  static const azanPrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  static const methods = [
    CalcMethodOption(
      'karachi',
      'ইউনিভার্সিটি অব ইসলামিক সায়েন্সেস, করাচি',
      CalculationMethod.karachi,
    ),
    CalcMethodOption(
      'muslim_world_league',
      'মুসলিম ওয়ার্ল্ড লীগ',
      CalculationMethod.muslim_world_league,
    ),
    CalcMethodOption('umm_al_qura', 'উম্মুল কুরা, মক্কা', CalculationMethod.umm_al_qura),
    CalcMethodOption('egyptian', 'মিশরীয় জেনারেল অথরিটি', CalculationMethod.egyptian),
    CalcMethodOption('north_america', 'ইসনা (উত্তর আমেরিকা)', CalculationMethod.north_america),
    CalcMethodOption('dubai', 'দুবাই', CalculationMethod.dubai),
    CalcMethodOption('kuwait', 'কুয়েত', CalculationMethod.kuwait),
    CalcMethodOption('qatar', 'কাতার', CalculationMethod.qatar),
    CalcMethodOption('singapore', 'সিঙ্গাপুর', CalculationMethod.singapore),
    CalcMethodOption('turkey', 'তুরস্ক (দিয়ানেত)', CalculationMethod.turkey),
  ];

  static CalcMethodOption methodById(String id) =>
      methods.firstWhere((m) => m.id == id, orElse: () => methods.first);

  static CalculationParameters _params(AppSettings s) {
    final p = methodById(s.calcMethod).method.getParameters();
    p.madhab = s.asrMethod == 'shafi' ? Madhab.shafi : Madhab.hanafi;
    return p;
  }

  /// The six times for the calendar day [day] (phone's local date).
  static List<PrayerTime> forDay(AppSettings s, DateTime day) {
    if (!s.hasLocation) return const [];
    final t = PrayerTimes.utc(
      Coordinates(s.latitude!, s.longitude!),
      DateComponents(day.year, day.month, day.day),
      _params(s),
    );
    PrayerTime pt(String k, DateTime d) => PrayerTime(k, names[k]!, d.toLocal());
    return [
      pt('fajr', t.fajr),
      pt('sunrise', t.sunrise),
      pt('dhuhr', t.dhuhr),
      pt('asr', t.asr),
      pt('maghrib', t.maghrib),
      pt('isha', t.isha),
    ];
  }

  /// The next prayer (not sunrise) after [now], looking into tomorrow if needed.
  static PrayerTime? next(AppSettings s, DateTime now) {
    for (var d = 0; d < 2; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      for (final p in forDay(s, day)) {
        if (!p.isSunrise && p.time.isAfter(now)) return p;
      }
    }
    return null;
  }

  /// Qibla direction in degrees from true north (clockwise).
  static double? qibla(AppSettings s) =>
      s.hasLocation ? Qibla(Coordinates(s.latitude!, s.longitude!)).direction : null;

  // ---------------------------------------------------------------- azan

  /// Old azan notifications (before the full azan) used these ids.
  static const _oldFirstId = 3000;

  /// How many days of prayer times are handed to the Android alarm.
  static const daysAhead = 30;

  static const _channel = MethodChannel('ayah_reminder/azan');

  /// True when a licensed azan recording is bundled (res/raw/azan.mp3).
  static bool azanBundled = false;

  /// True when a separate Fajr azan is bundled (res/raw/azan_fajr.mp3).
  static bool fajrBundled = false;

  /// Licence details of the bundled azan (for the credits page); the Fajr
  /// recording, if any, is under the "fajr" key.
  static Map<String, dynamic> azanLicense = const {};

  static Future<void> loadAzanInfo() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/azan_license.json'));
      azanLicense = (j as Map<String, dynamic>);
      azanBundled = (azanLicense['title'] ?? '').toString().isNotEmpty;
      fajrBundled = ((azanLicense['fajr'] as Map?)?['title'] ?? '').toString().isNotEmpty;
    } catch (_) {
      azanBundled = false;
    }
  }

  /// The prayer times the Android side should act on, as JSON.
  static String eventsJson(AppSettings s, DateTime now) {
    final events = <Map<String, Object>>[];
    for (var d = 0; d < daysAhead; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      for (final p in forDay(s, day)) {
        final mode = s.azanMode(p.key);
        if (p.isSunrise || mode == 'off' || !p.time.isAfter(now)) continue;
        events.add({
          't': p.time.millisecondsSinceEpoch,
          'key': p.key,
          'name': p.name,
          'mode': mode == 'azan' && azanBundled ? 'azan' : 'notify',
          'fajr': p.key == 'fajr',
        });
      }
    }
    return jsonEncode(events);
  }

  /// Hands the next [daysAhead] days of prayer times to Android, which sets an
  /// alarm for the next one (and the one after that when it rings).
  static Future<void> schedule(AppSettings s) async {
    // Remove notifications planned by older versions of the app.
    for (var i = 0; i < 80; i++) {
      try {
        await Reminders.plugin.cancel(id: _oldFirstId + i);
      } catch (_) {}
    }
    try {
      await _channel.invokeMethod('schedule', {
        'events': s.hasLocation && s.azanEnabled ? eventsJson(s, DateTime.now()) : '[]',
        'inSilent': s.azanInSilent,
        'fullScreen': s.azanFullScreen,
      });
    } on MissingPluginException {
      // Tests / non-Android.
    } on PlatformException catch (e) {
      debugPrint('azan schedule failed: $e');
    }
  }

  /// Plays the full azan now (the same way it plays at prayer time).
  static Future<void> playNow({bool fajr = false}) async {
    try {
      await _channel.invokeMethod('playNow', {'name': fajr ? 'ফজর' : 'আজান', 'fajr': fajr});
    } on MissingPluginException {
      // Tests / non-Android.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on MissingPluginException {
      // Tests / non-Android.
    }
  }
}

/// "৫:১২" style 12-hour clock with a Bangla part of day, e.g. "ভোর ৪:৪৫".
String formatClock(DateTime t, {bool withPart = true}) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final clock = toBanglaDigits('$h:$m');
  if (!withPart) return clock;
  return '${partOfDay(t.hour)} $clock';
}

String partOfDay(int hour) {
  if (hour < 4) return 'রাত';
  if (hour < 6) return 'ভোর';
  if (hour < 12) return 'সকাল';
  if (hour < 16) return 'দুপুর';
  if (hour < 18) return 'বিকাল';
  if (hour < 20) return 'সন্ধ্যা';
  return 'রাত';
}

/// "২ ঘণ্টা ১৫ মিনিট" / "১২ মিনিট" / "৪৫ সেকেন্ড".
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${toBanglaDigits(h)} ঘণ্টা ${toBanglaDigits(m)} মিনিট';
  if (m > 0) return '${toBanglaDigits(m)} মিনিট ${toBanglaDigits(s)} সেকেন্ড';
  return '${toBanglaDigits(s)} সেকেন্ড';
}

/// A city the user can pick when location is not allowed.
class City {
  const City(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;

  static const all = [
    City('ঢাকা', 23.8103, 90.4125),
    City('চট্টগ্রাম', 22.3569, 91.7832),
    City('সিলেট', 24.8949, 91.8687),
    City('রাজশাহী', 24.3745, 88.6042),
    City('খুলনা', 22.8456, 89.5403),
    City('বরিশাল', 22.7010, 90.3535),
    City('রংপুর', 25.7439, 89.2752),
    City('ময়মনসিংহ', 24.7471, 90.4203),
    City('কুমিল্লা', 23.4607, 91.1809),
    City('গাজীপুর', 23.9999, 90.4203),
    City('নারায়ণগঞ্জ', 23.6238, 90.5000),
    City('কক্সবাজার', 21.4272, 92.0058),
    City('বগুড়া', 24.8465, 89.3773),
    City('যশোর', 23.1664, 89.2081),
    City('দিনাজপুর', 25.6217, 88.6354),
    City('ফেনী', 23.0159, 91.3976),
    City('নোয়াখালী', 22.8696, 91.0995),
    City('টাঙ্গাইল', 24.2513, 89.9167),
    City('ফরিদপুর', 23.6070, 89.8429),
    City('কুষ্টিয়া', 23.9013, 89.1205),
    City('পাবনা', 24.0064, 89.2372),
    City('মৌলভীবাজার', 24.4829, 91.7774),
    City('হবিগঞ্জ', 24.3749, 91.4155),
    City('সুনামগঞ্জ', 25.0715, 91.3992),
    City('ব্রাহ্মণবাড়িয়া', 23.9571, 91.1119),
    City('চাঁদপুর', 23.2333, 90.6713),
    City('জামালপুর', 24.9375, 89.9372),
    City('পটুয়াখালী', 22.3596, 90.3299),
    City('রাঙ্গামাটি', 22.6533, 92.1789),
    City('সাতক্ষীরা', 22.7185, 89.0705),
    City('মক্কা', 21.4225, 39.8262),
    City('মদিনা', 24.4672, 39.6112),
    City('রিয়াদ', 24.7136, 46.6753),
    City('জেদ্দা', 21.4858, 39.1925),
    City('দুবাই', 25.2048, 55.2708),
    City('আবুধাবি', 24.4539, 54.3773),
    City('দোহা', 25.2854, 51.5310),
    City('কুয়েত সিটি', 29.3759, 47.9774),
    City('মাসকাট', 23.5880, 58.3829),
    City('কুয়ালালামপুর', 3.1390, 101.6869),
    City('সিঙ্গাপুর', 1.3521, 103.8198),
    City('কলকাতা', 22.5726, 88.3639),
    City('লন্ডন', 51.5074, -0.1278),
    City('নিউ ইয়র্ক', 40.7128, -74.0060),
    City('টরন্টো', 43.6532, -79.3832),
    City('সিডনি', -33.8688, 151.2093),
    City('রোম', 41.9028, 12.4964),
  ];
}
