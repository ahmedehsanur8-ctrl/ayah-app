import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/content.dart';
import 'planner.dart';
import 'prayer.dart';
import 'quran.dart';
import 'reminders.dart';
import 'settings.dart';
import 'system_settings.dart';

/// A counter step, e.g. 33 × সুবহানাল্লাহ.
class DuaStep {
  const DuaStep(this.count, this.arabic, this.label);

  final int count;
  final String arabic;
  final String label;
}

/// The evening wording of a morning/evening dhikr.
class DuaText {
  const DuaText(this.arabic, this.bangla, this.uccharon);

  final String arabic;
  final String bangla;
  final String uccharon;
}

/// One dua or dhikr (assets/duas.json, built from dua-list.md).
class Dua {
  Dua(this.j)
    : steps = [
        for (final s in (j['steps'] as List).cast<Map<String, dynamic>>())
          DuaStep(s['count'] as int, s['arabic'] as String, s['label_bn'] as String),
      ],
      evening = j['evening'] == null
          ? null
          : DuaText(
              j['evening']['arabic'] as String,
              j['evening']['bangla_meaning'] as String,
              j['evening']['uccharon'] as String,
            ),
      quran = [
        for (final q in (j['quran'] as List).cast<Map<String, dynamic>>())
          (surah: q['surah'] as int, from: q['from'] as int, to: q['to'] as int),
      ];

  final Map<String, dynamic> j;
  final List<DuaStep> steps;
  final DuaText? evening;
  final List<({int surah, int from, int to})> quran;

  String get id => j['id'] as String;
  int get section => j['section'] as int;
  String get title => j['title_bn'] as String;
  String get when => (j['when_bn'] ?? '') as String;
  String get arabic => j['arabic'] as String;
  String get bangla => j['bangla_meaning'] as String;
  String get uccharon => (j['uccharon'] ?? '') as String;
  String get source => j['source_ref'] as String;

  /// S, H, Q, A or R.
  String get grade => j['grade'] as String;
  String get gradeBn => j['grade_bn'] as String;
  int? get repeat => j['repeat_count'] as int?;
  String get repeatNote => (j['repeat_note'] ?? '') as String;
  String get fadilah => (j['fadilah_bn'] ?? '') as String;
  bool get needsReview => j['needs_review'] == true;
  String get reviewReason => (j['review_reason'] ?? '') as String;
  bool get athar => j['athar'] == true;

  /// 'both', 'morning', 'evening' or ''.
  String get period => (j['period'] ?? '') as String;
  List<int> get openSurahs => (j['open_surahs'] as List).cast<int>();
  bool get info => j['info'] == true;
  String get translator => (j['translator_bn'] ?? '') as String;
  String get note => (j['note_bn'] ?? '') as String;
  bool get isQuranText => quran.isNotEmpty;

  /// Taps needed in the counter (1 when no count is given).
  int get total => steps.isNotEmpty ? steps.fold(0, (n, s) => n + s.count) : (repeat ?? 1);

  bool get hasCounter => total > 1;

  /// Arabic / Bangla / উচ্চারণ for the morning or the evening set.
  DuaText textFor({bool evening = false}) =>
      evening && this.evening != null ? this.evening! : DuaText(arabic, bangla, uccharon);

  late final String _searchBn = Quran.plainBangla(
    [title, when, bangla, fadilah, uccharon, source, evening?.bangla ?? ''].join(' '),
  ).toLowerCase();
  late final String _searchAr = Quran.plainArabic('$arabic ${evening?.arabic ?? ''}');
}

class DuaSection {
  const DuaSection(this.n, this.title, this.count);

  final int n;
  final String title;
  final int count;
}

/// All duas, loaded once from assets/duas.json.
class Duas {
  Duas._();

  static List<DuaSection> sections = const [];
  static List<Dua> all = const [];
  static String uccharonNote = '';
  static String credit = '';
  static Future<void>? _loading;

  static bool get loaded => all.isNotEmpty;

  static Future<void> load() => loaded ? Future.value() : (_loading ??= _load());

  static Future<void> _load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/duas.json')) as Map<String, dynamic>;
      sections = [
        for (final s in (j['sections'] as List).cast<Map<String, dynamic>>())
          DuaSection(s['n'] as int, s['title_bn'] as String, s['count'] as int),
      ];
      all = [for (final d in (j['duas'] as List).cast<Map<String, dynamic>>()) Dua(d)];
      uccharonNote = (j['uccharon_note'] ?? '') as String;
      credit = (j['credit'] ?? '') as String;
    } catch (e) {
      debugPrint('duas: $e');
    }
  }

  static Dua? byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static List<Dua> inSection(int n) => [
    for (final d in all)
      if (d.section == n) d,
  ];

  /// The সকালের জিকির / সন্ধ্যার জিকির set, in list order.
  static List<Dua> adhkar({required bool evening}) => [
    for (final d in inSection(1))
      if (d.period == 'both' || d.period == (evening ? 'evening' : 'morning')) d,
  ];

  /// Words for situations, so "ভয়" or "অসুস্থ" finds the right duas.
  static const situations = {
    'ভয়': ['ভয়', 'আতঙ্ক', 'শত্রু', 'জালিম', 'বিপদ', 'দুশ্চিন্তা'],
    'ঋণ': ['ঋণ', 'অভাব', 'দারিদ্র্য', 'রিজিক'],
    'সফর': ['সফর', 'যানবাহন', 'বাহন', 'মুসাফির', 'ভ্রমণ', 'জাহাজ', 'নৌকা'],
    'অসুস্থ': ['অসুস্থ', 'রোগ', 'রোগী', 'ব্যথা', 'সুস্থ', 'রুকইয়া', 'কষ্ট'],
    'দুঃখ': ['দুঃখ', 'দুশ্চিন্তা', 'বিপদ', 'কষ্ট'],
    'ঘুম': ['ঘুম', 'বিছানা', 'স্বপ্ন', 'জেগে'],
    'রাগ': ['রাগ'],
    'মৃত্যু': ['মৃত্যু', 'জানাজা', 'কবর', 'মৃত'],
  };

  /// Duas matching [q] in Bangla, Arabic (vowel marks ignored) or by situation.
  static List<Dua> search(String q) {
    final query = q.trim();
    if (query.length < 2) return const [];
    if (RegExp('[؀-ۿ]').hasMatch(query)) {
      final a = Quran.plainArabic(query);
      return [
        for (final d in all)
          if (d._searchAr.contains(a)) d,
      ];
    }
    final b = Quran.plainBangla(query).toLowerCase();
    final words = <String>{b};
    for (final e in situations.entries) {
      if (b.contains(e.key) || e.key.contains(b)) words.addAll(e.value);
    }
    final sectionHit = {
      for (final s in sections)
        if (words.any((w) => Quran.plainBangla(s.title).contains(w))) s.n,
    };
    final direct = [
      for (final d in all)
        if (d._searchBn.contains(b)) d,
    ];
    final related = [
      for (final d in all)
        if (!direct.contains(d) &&
            (sectionHit.contains(d.section) || words.any((w) => d._searchBn.contains(w))))
          d,
    ];
    return [...direct, ...related];
  }

  /// Morning (Fajr to Asr) or evening now.
  static bool isEveningNow(AppSettings s, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final day = Prayers.forDay(s, t);
    if (day.isNotEmpty) {
      final fajr = day.firstWhere((p) => p.key == 'fajr').time;
      final asr = day.firstWhere((p) => p.key == 'asr').time;
      return !(t.isAfter(fajr) && t.isBefore(asr));
    }
    return t.hour < 4 || t.hour >= 16;
  }
}

/// Optional notifications for morning adhkar (after Fajr) and evening adhkar
/// (after Asr), planned for the next days from the prayer times.
class AdhkarReminders {
  AdhkarReminders._();

  static const _firstId = 4000;

  /// Longer than Planner.minAdhkarDays by the top-up margin (and a day each for
  /// a late daily check, the last day ending early and today), so at least 14
  /// days are always planned.
  static const days = Planner.minAdhkarDays + Planner.refreshAfterDays + 4;
  static const channel = 'adhkar';

  /// Minutes after Fajr / Asr.
  static const delay = Duration(minutes: 20);

  static Future<void> schedule(AppSettings s) async {
    final plugin = Reminders.plugin;
    for (var i = 0; i < days * 2; i++) {
      try {
        await plugin.cancel(id: _firstId + i);
      } catch (_) {}
    }
    if (!s.adhkarMorning && !s.adhkarEvening) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        'সকাল-সন্ধ্যার জিকির',
        channelDescription: 'ফজরের পর সকালের জিকির, আসরের পর সন্ধ্যার জিকির মনে করিয়ে দেয়',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    // On time when "Alarms & reminders" is allowed; otherwise Android may
    // deliver it a little late.
    final exact = await SystemSettings.canScheduleExactAlarms();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final a in plan(s, DateTime.now())) {
      final evening = a.slot == 'evening';
      try {
        await plugin.zonedSchedule(
          id: a.id,
          scheduledDate: tz.TZDateTime.from(a.at, Reminders.dhaka),
          notificationDetails: details,
          androidScheduleMode: mode,
          title: evening ? 'সন্ধ্যার জিকির' : 'সকালের জিকির',
          body:
              '${evening ? 'সন্ধ্যার' : 'সকালের'} জিকিরের সময় হয়েছে — '
              '${toBanglaDigits(adhkarCount(evening))}টি জিকির',
          payload: 'adhkar|${a.slot}',
        );
      } catch (e) {
        debugPrint('adhkar reminder: $e');
      }
    }
  }

  /// The adhkar notifications of the next [days] days after [now]: 20 minutes
  /// after Fajr (morning) and after Asr (evening).
  static List<({int id, DateTime at, String slot})> plan(AppSettings s, DateTime now) {
    final out = <({int id, DateTime at, String slot})>[];
    for (var d = 0; d < days; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final times = Prayers.forDay(s, day);
      DateTime at(String key, int fallbackHour, int fallbackMinute) {
        for (final p in times) {
          if (p.key == key) return p.time.add(delay);
        }
        return DateTime(day.year, day.month, day.day, fallbackHour, fallbackMinute);
      }

      void add(int id, DateTime when, String slot) {
        if (when.isAfter(now)) out.add((id: id, at: when, slot: slot));
      }

      if (s.adhkarMorning) add(_firstId + d * 2, at('fajr', 6, 0), 'morning');
      if (s.adhkarEvening) add(_firstId + d * 2 + 1, at('asr', 16, 30), 'evening');
    }
    return out;
  }

  static int adhkarCount(bool evening) => Duas.loaded ? Duas.adhkar(evening: evening).length : 0;
}
