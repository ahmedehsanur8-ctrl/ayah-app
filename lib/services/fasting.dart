import '../models/content.dart';
import '../utils/bangla.dart';
import 'prayer.dart';
import 'reminders.dart';
import 'settings.dart';

/// One day's sehri and iftar.
class FastingDay {
  const FastingDay(this.date, this.sehriEnd, this.iftar, this.hijriDay);

  /// The calendar day (local, midnight).
  final DateTime date;

  /// Fajr start (subh sadiq) minus the user's precaution.
  final DateTime sehriEnd;

  /// Maghrib.
  final DateTime iftar;

  /// Day of the Hijri month (with the user's adjustment).
  final int hijriDay;
}

/// সেহরি ও ইফতার: times from the prayer-time calculation, Ramadan from the
/// Hijri calculation (with the user's -2 … +2 day adjustment for local moon
/// sighting), and the user's own nafl fast days.
class Fasting {
  Fasting._();

  static const precautions = [0, 3, 5, 10];
  static const alarmOptions = [0, 30, 45, 60, 90];
  static const iftarOptions = [0, 5, 10];
  static const showModes = {'always': 'সবসময়', 'ramadan': 'শুধু রমজানে', 'off': 'বন্ধ'};

  /// The iftar dua (Sunan Abu Dawud 2357) in assets/duas.json.
  static const iftarDuaId = '13-01';

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Hijri (year, month, day) of [d] with the user's adjustment.
  static (int, int, int) hijri(AppSettings s, DateTime d) =>
      hijriOf(_day(d).add(Duration(days: s.hijriOffset)));

  /// e.g. "১৯ রবিউস সানি ১৪৪৮ হিজরি", with the user's adjustment.
  static String hijriText(AppSettings s, DateTime d) =>
      hijriDate(_day(d).add(Duration(days: s.hijriOffset)));

  static bool isRamadan(AppSettings s, DateTime d) => hijri(s, d).$2 == 9;

  /// A day the user fasts: Ramadan, or a day marked "রোজা রাখছি".
  static bool isFastingDay(AppSettings s, DateTime d) =>
      isRamadan(s, d) || (s.naflFastDay.isNotEmpty && s.naflFastDay == dateKey(_day(d)));

  /// Sehri end and iftar for [d] (null without a location).
  static FastingDay? forDay(AppSettings s, DateTime d) {
    final times = Prayers.forDay(s, _day(d));
    if (times.isEmpty) return null;
    final fajr = times.firstWhere((p) => p.key == 'fajr').time;
    final maghrib = times.firstWhere((p) => p.key == 'maghrib').time;
    return FastingDay(
      _day(d),
      fajr.subtract(Duration(minutes: s.sehriPrecaution)),
      maghrib,
      hijri(s, d).$3,
    );
  }

  /// The fast that comes next: today's until today's iftar, then tomorrow's.
  static DateTime nextFastDate(AppSettings s, DateTime now) {
    final today = forDay(s, now);
    if (today != null && now.isAfter(today.iftar)) return _day(now).add(const Duration(days: 1));
    return _day(now);
  }

  /// Show sehri and iftar on the home screen now?
  static bool showOnHome(AppSettings s, DateTime now) => switch (s.sehriShowMode) {
    'always' => true,
    'off' => false,
    _ => isFastingDay(s, nextFastDate(s, now)),
  };

  /// "আজ" or "কাল": the day the "রোজা রাখছি" switch applies to.
  static bool naflIsTomorrow(AppSettings s, DateTime now) =>
      !nextFastDate(s, now).isAtSameMomentAs(_day(now));

  static bool naflOn(AppSettings s, DateTime now) => s.naflFastDay == dateKey(nextFastDate(s, now));

  static Future<void> setNafl(AppSettings s, DateTime now, bool on) =>
      s.setNaflFastDay(on ? dateKey(nextFastDate(s, now)) : '');

  /// Every day of the Ramadan that contains [now] (empty outside Ramadan).
  static List<FastingDay> ramadanTimetable(AppSettings s, DateTime now) {
    if (!isRamadan(s, now)) return const [];
    var first = _day(now);
    while (isRamadan(s, first.subtract(const Duration(days: 1)))) {
      first = first.subtract(const Duration(days: 1));
    }
    final out = <FastingDay>[];
    for (var d = first; isRamadan(s, d); d = d.add(const Duration(days: 1))) {
      final f = forDay(s, d);
      if (f != null) out.add(f);
      if (out.length >= 30) break;
    }
    return out;
  }

  /// "৫ মিনিট আগে সতর্কতা" / "সতর্কতা নেই".
  static String precautionText(int min) => min == 0
      ? 'সতর্কতা নেই, ফজর শুরুর সময়েই'
      : 'ফজরের ${toBanglaDigits(min)} মিনিট আগে (সতর্কতা)';
}
