import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ayah_reminder/models/content.dart';
import 'package:ayah_reminder/models/story.dart';
import 'package:ayah_reminder/models/surah_names.dart';
import 'package:ayah_reminder/models/topics.dart';
import 'package:ayah_reminder/services/audio.dart';
import 'package:ayah_reminder/services/bangla_tts.dart';
import 'package:ayah_reminder/services/fasting.dart';
import 'package:ayah_reminder/services/prayer.dart';
import 'package:ayah_reminder/services/rotation.dart';
import 'package:ayah_reminder/services/settings.dart';
import 'package:ayah_reminder/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ayah_reminder/services/permissions.dart';

void main() {
  final data = ContentData.fromJson(
    jsonDecode(File('assets/content.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final rotation = Rotation(data);

  test('content has 20 ayah categories, each with items', () {
    expect(data.ayahCategories.length, 20);
    for (final c in data.ayahCategories) {
      expect(data.itemsIn(c.id), isNotEmpty, reason: c.name);
    }
  });

  test('every item has Arabic and Bangla text', () {
    for (final i in data.items) {
      expect(i.arabic.trim(), isNotEmpty, reason: i.id);
      expect(i.bangla.trim(), isNotEmpty, reason: i.id);
    }
  });

  test('same category never repeats on two days in a row', () {
    for (var d = -50; d < 800; d++) {
      expect(rotation.morning(d)!.categoryId, isNot(rotation.morning(d + 1)!.categoryId));
      for (final h in [true, false]) {
        expect(
          rotation.night(d, hadith: h)!.categoryId,
          isNot(rotation.night(d + 1, hadith: h)!.categoryId),
        );
      }
      // With hadith off, the night ayah is from another category than the morning one.
      expect(rotation.night(d, hadith: false)!.categoryId, isNot(rotation.morning(d)!.categoryId));
    }
  });

  test('every ayah appears in the rotation', () {
    final seen = <String>{};
    for (var d = 0; d < 20 * 20; d++) {
      seen.add(rotation.morning(d)!.id);
    }
    expect(seen.length, data.items.where((i) => i.isAyah).length);
  });

  test('phone brands get their own setup steps', () {
    expect(PhoneBrand.of('OPPO'), PhoneBrand.colorOs);
    expect(PhoneBrand.of('realme'), PhoneBrand.colorOs);
    expect(PhoneBrand.of('OnePlus'), PhoneBrand.colorOs);
    expect(PhoneBrand.of('Xiaomi'), PhoneBrand.miui);
    expect(PhoneBrand.of('POCO'), PhoneBrand.miui);
    expect(PhoneBrand.of('vivo'), PhoneBrand.vivo);
    expect(PhoneBrand.of('samsung'), PhoneBrand.samsung);
    expect(PhoneBrand.of('Google'), isNull);
    expect(PhoneBrand.colorOs.steps.map((s) => s.id), [
      'autostart',
      'popup',
      'lockscreen',
      'background',
    ]);
  });

  test('Bangla digits', () {
    expect(toBanglaDigits('39:53'), '৩৯:৫৩');
    expect(toArabicDigits(12), '١٢');
  });

  test('basmala in front of verse 1 is put on its own line, text unchanged', () {
    final d = ContentData.fromJson({
      'meta': {
        'sources': {
          'tanzil': {'basmala': 'B M'},
        },
      },
      'ayahCategories': [
        {'id': 'A1', 'name': 'x'},
      ],
      'items': [
        {
          'id': 'a',
          'type': 'ayah',
          'categoryId': 'A1',
          'category': 'x',
          'reference': '94:1',
          'arabicVerses': [
            {'n': 1, 'text': 'B M first'},
          ],
          'banglaVerses': [
            {'n': 1, 'text': 'bn'},
          ],
        },
      ],
    });
    expect(d.items.single.arabic, 'B M\nfirst');
  });

  test('Sahaba life stories have text, lesson, a source or note, and the draft mark', () {
    final stories = Story.listFromJson(File('assets/stories.json').readAsStringSync(), {});
    expect(stories, isNotEmpty);
    expect(stories.map((s) => s.id).toSet().length, stories.length);
    for (final s in stories) {
      expect(s.body.trim(), isNotEmpty, reason: s.id);
      expect(s.lesson, isNotEmpty, reason: s.id);
      expect(s.source.isNotEmpty || s.note.isNotEmpty, isTrue, reason: s.id);
      expect(s.status, 'draft - needs scholar review', reason: s.id);
    }
  });

  test('story audio is picked up from bundled assets', () {
    final stories = Story.listFromJson(File('assets/stories.json').readAsStringSync(), {
      'assets/story_audio/s01.mp3',
    });
    expect(stories.first.hasAudio, isTrue);
    expect(stories[1].hasAudio, isFalse);
  });

  test('EveryAyah URL for a verse', () {
    expect(
      AudioController.ayahUrl('Alafasy_128kbps', 39, 53).toString(),
      'https://everyayah.com/data/Alafasy_128kbps/039053.mp3',
    );
  });

  test('footnote markers are not read aloud', () {
    expect(BanglaTts.clean('দয়ালু [১]। আর---আল্লাহ'), 'দয়ালু । আর, আল্লাহ');
  });

  test('16 moods; every listed item exists', () {
    expect(data.moods.length, 16);
    for (final m in data.moods) {
      expect(m.ayahIds, isNotEmpty, reason: m.name);
      expect(
        data.byIds([...m.ayahIds, ...m.surahIds, ...m.hadithIds]).length,
        m.ayahIds.length + m.surahIds.length + m.hadithIds.length,
        reason: m.name,
      );
    }
    // Full surahs start at verse 1 and are marked.
    final duha = data.byId('s-93')!;
    expect(duha.fullSurah, isTrue);
    expect(duha.ayahStart, 1);
    expect(duha.ayahEnd, 11);
    expect(duha.title, 'সূরা আদ-দুহা (সম্পূর্ণ)');
  });

  test('every topic group covers each category and theme exactly once', () {
    final ids = [
      for (final g in topicGroups)
        for (final t in g.topics) ...[...t.ayahCats, ...t.hadithThemes],
    ];
    expect(ids.toSet().length, ids.length);
    for (final c in data.ayahCategories) {
      expect(ids, contains(c.id));
    }
    for (final h in data.hadithThemes) {
      expect(ids, contains(h.id));
    }
  });

  test('Bangla surah names and footnote-free text', () {
    expect(surahNamesBn.length, 114);
    expect(surahNameBn(2), 'আল-বাকারা');
    expect(withoutFootnoteMarks('দয়ালু [১]। আর [2]'), 'দয়ালু। আর');
    final item = data.items.firstWhere((i) => i.surah == 2 && i.ayahStart == 153);
    expect(item.title, 'সূরা আল-বাকারা · ২:১৫৩');
  });

  test('prayer times for Sylhet are in order (Karachi, Hanafi)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    await s.setLocation(24.8949, 91.8687, 'সিলেট', 'city');
    final times = Prayers.forDay(s, DateTime(2026, 3, 21));
    expect(times.map((p) => p.key), ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']);
    for (var i = 1; i < times.length; i++) {
      expect(times[i].time.isAfter(times[i - 1].time), isTrue);
    }
    final q = Prayers.qibla(s)!;
    expect(q, inInclusiveRange(270, 285)); // west-north-west from Bangladesh
  });

  test('azan events: per-prayer modes, Fajr flag, no sunrise', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    await s.setLocation(24.8949, 91.8687, 'সিলেট', 'city');
    await s.setAzanSound('asr', 'notify');
    await s.setAzanSound('isha', 'off');
    Prayers.azanBundled = true;
    final now = DateTime(2026, 3, 21, 0, 1);
    final events = (jsonDecode(Prayers.eventsJson(s, now)) as List).cast<Map<String, dynamic>>();
    // 4 prayers (isha off) for 30 days; the first day may already have started.
    expect(events.length, inInclusiveRange(30 * 4 - 4, 30 * 4));
    expect(events.map((e) => e['key']).toSet(), {'fajr', 'dhuhr', 'asr', 'maghrib'});
    expect(events.where((e) => e['key'] == 'asr').every((e) => e['mode'] == 'notify'), isTrue);
    expect(
      events
          .where((e) => e['key'] == 'fajr')
          .every((e) => e['fajr'] == true && e['mode'] == 'azan'),
      isTrue,
    );
    expect(s.azanInSilent, isTrue);
  });

  test('azan: sound, adjustment, fixed time, reminders before and iqamah', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    await s.setLocation(24.8949, 91.8687, 'সিলেট', 'city');
    Prayers.azanBundled = true;
    // Older setting carries over: "azan" -> Masjid an-Nabawi.
    expect(s.azanSound('asr'), 'nabawi');
    await s.setAzanSound('dhuhr', 'haram');
    await s.setAzanSound('isha', 'off');
    await s.setAzanOffset('asr', 10);
    await s.setAzanOffset('maghrib', 99); // clamped to +30
    expect(s.azanOffset('maghrib'), 30);
    await s.setAzanFixedMinutes('dhuhr', 13 * 60 + 30); // 1:30 pm every day
    await s.setAzanBefore('fajr', 15);
    await s.setIqamahAfter('asr', 20);

    final day = DateTime(2026, 3, 21);
    final today = {for (final p in Prayers.forDay(s, day)) p.key: p};
    expect(Prayers.azanTime(s, today['asr']!), today['asr']!.time.add(const Duration(minutes: 10)));
    expect(Prayers.azanTime(s, today['dhuhr']!), DateTime(2026, 3, 21, 13, 30));
    expect(Prayers.azanTime(s, today['fajr']!), today['fajr']!.time);
    expect(Prayers.isAdjusted(s, 'asr'), isTrue);
    expect(Prayers.isAdjusted(s, 'fajr'), isFalse);

    final now = DateTime(2026, 3, 21, 0, 1);
    final events = (jsonDecode(Prayers.eventsJson(s, now)) as List).cast<Map<String, dynamic>>();
    List<Map<String, dynamic>> on(String key, String mode) => [
      for (final e in events)
        if (e['key'] == key && e['mode'] == mode) e,
    ];
    int first(String key, String mode) => on(key, mode).first['t'] as int;
    final ms = Duration.millisecondsPerMinute;
    // Isha off: no azan; Dhuhr plays Masjid al-Haram at 1:30.
    expect(on('isha', 'azan'), isEmpty);
    expect(on('dhuhr', 'azan').every((e) => e['sound'] == 'haram'), isTrue);
    expect(first('dhuhr', 'azan'), DateTime(2026, 3, 21, 13, 30).millisecondsSinceEpoch);
    expect(first('asr', 'azan'), Prayers.azanTime(s, today['asr']!).millisecondsSinceEpoch);
    // Reminder 15 minutes before Fajr, iqamah 20 minutes after the moved Asr azan.
    final fajrBefore = on('fajr', 'before').first;
    expect(fajrBefore['mins'], 15);
    expect(fajrBefore['azan'] - fajrBefore['t'], 15 * ms);
    final asrIqamah = on('asr', 'iqamah').first;
    expect(asrIqamah['t'] - asrIqamah['azan'], 20 * ms);
    expect(asrIqamah['azan'], first('asr', 'azan'));
    // Sorted by time, all in the future.
    for (var i = 1; i < events.length; i++) {
      expect(events[i]['t'] as int, greaterThan(events[i - 1]['t'] as int));
    }
    expect(events.every((e) => (e['t'] as int) > now.millisecondsSinceEpoch), isTrue);

    // Two events at the same moment both stay (one second apart): the Dhuhr
    // azan at 1:30 and a reminder 10 minutes before an Asr azan fixed at 1:40.
    await s.setAzanFixedMinutes('asr', 13 * 60 + 40);
    await s.setAzanBefore('asr', 10);
    final clash = (jsonDecode(Prayers.eventsJson(s, now)) as List).cast<Map<String, dynamic>>();
    final at = DateTime(2026, 3, 21, 13, 30).millisecondsSinceEpoch;
    final dhuhr = clash.firstWhere((e) => e['key'] == 'dhuhr' && e['mode'] == 'azan');
    final asrBefore = clash.firstWhere((e) => e['key'] == 'asr' && e['mode'] == 'before');
    expect({dhuhr['t'], asrBefore['t']}, {at, at + 1000});
    await s.setAzanFixedMinutes('asr', null);

    // Turning the fixed time off goes back to the calculated time.
    await s.setAzanFixedMinutes('dhuhr', null);
    expect(Prayers.azanTime(s, today['dhuhr']!), today['dhuhr']!.time);
    expect(s.azanVolume, 1.0);
    expect(s.azanVibrate, isTrue);
    expect(s.azanInSilent, isTrue);
  });

  test('Night & Gold: every text colour is at least 4.5:1 in light and dark', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final p in [Palette.light, Palette.dark]) {
      final pairs = <String, (Color, Color)>{
        'ink on ground': (p.text, p.background),
        'ink on surface': (p.text, p.surface),
        'muted on ground': (p.muted, p.background),
        'muted on surface': (p.muted, p.surface),
        'muted on soft emerald': (p.muted, p.pill),
        'emerald on surface': (p.primary, p.surface),
        'emerald on ground': (p.primary, p.background),
        'emerald on soft emerald': (p.primary, p.pill),
        'gold text on surface': (p.goldText, p.surface),
        'gold text on ground': (p.goldText, p.background),
        'gold on night': (p.gold, p.night),
        'white on night': (p.onNight, p.night),
        'soft white on night': (Color.alphaBlend(p.onNightMuted, p.night), p.night),
        'white on emerald button': (p.onPrimary, p.action),
        'navy on gold button': (p.night, p.gold),
      };
      for (final e in pairs.entries) {
        expect(
          ratio(e.value.$1, e.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${p.isDark ? 'dark' : 'light'}: ${e.key}',
        );
      }
    }
  });

  test('sehri = Fajr minus precaution, iftar = Maghrib', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    await s.setLocation(23.8103, 90.4125, 'ঢাকা', 'city');
    final day = DateTime(2026, 3, 1);
    final t = {for (final p in Prayers.forDay(s, day)) p.key: p.time};
    var f = Fasting.forDay(s, day)!;
    expect(f.sehriEnd, t['fajr']);
    expect(f.iftar, t['maghrib']);
    for (final m in Fasting.precautions) {
      await s.setSehriPrecaution(m);
      f = Fasting.forDay(s, day)!;
      expect(f.sehriEnd, t['fajr']!.subtract(Duration(minutes: m)), reason: '$m');
      expect(f.iftar, t['maghrib']);
    }
  });

  test('Ramadan detection follows the Hijri adjustment', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    // Calculated: 1 Ramadan 1447 = 18 Feb 2026, 1 Shawwal = 20 Mar 2026.
    expect(Fasting.isRamadan(s, DateTime(2026, 2, 17)), isFalse);
    expect(Fasting.isRamadan(s, DateTime(2026, 2, 18)), isTrue);
    expect(Fasting.hijri(s, DateTime(2026, 2, 18)), (1447, 9, 1));
    expect(Fasting.isRamadan(s, DateTime(2026, 3, 19)), isTrue);
    expect(Fasting.isRamadan(s, DateTime(2026, 3, 20)), isFalse);
    // Moon seen a day later in Bangladesh: -1 day moves Ramadan one day later.
    await s.setHijriOffset(-1);
    expect(Fasting.isRamadan(s, DateTime(2026, 2, 18)), isFalse);
    expect(Fasting.isRamadan(s, DateTime(2026, 2, 19)), isTrue);
    expect(Fasting.hijri(s, DateTime(2026, 2, 19)).$3, 1);
    expect(Fasting.isRamadan(s, DateTime(2026, 3, 20)), isTrue);
    await s.setHijriOffset(2);
    expect(Fasting.isRamadan(s, DateTime(2026, 2, 16)), isTrue);
    await s.setHijriOffset(9); // clamped
    expect(s.hijriOffset, 2);
  });

  test('home display, nafl day, alarms and the Ramadan timetable', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppSettings.load();
    await s.setLocation(23.8103, 90.4125, 'ঢাকা', 'city');
    Prayers.azanBundled = true;
    final ramadan = DateTime(2026, 3, 1, 9);
    final shawwal = DateTime(2026, 4, 10, 9);
    // Default: only in Ramadan.
    expect(s.sehriShowMode, 'ramadan');
    expect(Fasting.showOnHome(s, ramadan), isTrue);
    expect(Fasting.showOnHome(s, shawwal), isFalse);
    // A nafl fast marked for today shows it and counts as a fasting day.
    await Fasting.setNafl(s, shawwal, true);
    expect(Fasting.naflOn(s, shawwal), isTrue);
    expect(Fasting.showOnHome(s, shawwal), isTrue);
    expect(Fasting.isFastingDay(s, shawwal), isTrue);
    expect(Fasting.isFastingDay(s, shawwal.add(const Duration(days: 1))), isFalse);
    // After iftar the switch is for tomorrow.
    final night = DateTime(2026, 4, 10, 22);
    expect(Fasting.naflIsTomorrow(s, night), isTrue);
    await s.setSehriShowMode('off');
    expect(Fasting.showOnHome(s, ramadan), isFalse);
    await s.setSehriShowMode('always');
    expect(Fasting.showOnHome(s, DateTime(2026, 6, 1, 9)), isTrue);

    // Alarms on fasting days only.
    await s.setSehriPrecaution(5);
    await s.setSehriAlarm(45);
    await s.setIftarBefore(10);
    final now = DateTime(2026, 3, 1, 0, 1);
    final events = (jsonDecode(Prayers.eventsJson(s, now)) as List).cast<Map<String, dynamic>>();
    final sehri = events.where((e) => e['mode'] == 'sehri').toList();
    final before = events.where((e) => e['mode'] == 'iftar_before').toList();
    final iftar = events.where((e) => e['mode'] == 'iftar').toList();
    // Ramadan days in the 30-day window (1 – 19 March), alarms still ahead of now.
    int count(DateTime Function(FastingDay) at) => [
      for (var d = 0; d < Prayers.daysAhead; d++)
        if (Fasting.isRamadan(s, DateTime(2026, 3, 1 + d)))
          if (at(Fasting.forDay(s, DateTime(2026, 3, 1 + d))!).isAfter(now)) d,
    ].length;
    expect(sehri.length, count((f) => f.sehriEnd.subtract(const Duration(minutes: 45))));
    expect(sehri.length, inInclusiveRange(18, 19));
    expect(before.length, count((f) => f.iftar.subtract(const Duration(minutes: 10))));
    expect(iftar.length, 19);
    final f = Fasting.forDay(s, DateTime(2026, 3, 1))!;
    final firstSehri = sehri.firstWhere(
      (e) => e['azan'] == f.sehriEnd.millisecondsSinceEpoch,
      orElse: () => sehri.first,
    );
    expect(firstSehri['azan'] - firstSehri['t'], 45 * Duration.millisecondsPerMinute);
    // Events at the same moment (iftar = Maghrib azan) are kept one second apart.
    expect(
      (before.first['t'] as int) -
          f.iftar.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
      inInclusiveRange(0, 2000),
    );
    expect((iftar.first['t'] as int) - f.iftar.millisecondsSinceEpoch, inInclusiveRange(0, 2000));
    expect(iftar.first['azan'], f.iftar.millisecondsSinceEpoch);
    // The azan switch pauses azan, not sehri/iftar.
    await s.setAzanEnabled(false);
    final paused = (jsonDecode(Prayers.eventsJson(s, now)) as List).cast<Map<String, dynamic>>();
    expect(paused.where((e) => e['mode'] == 'azan'), isEmpty);
    expect(paused.where((e) => e['mode'] == 'sehri').length, sehri.length);

    // Timetable: the whole Ramadan, 1 to 30, with today inside.
    final table = Fasting.ramadanTimetable(s, ramadan);
    expect(table.first.hijriDay, 1);
    expect(table.first.date, DateTime(2026, 2, 18));
    expect(table.length, 30);
    expect(Fasting.ramadanTimetable(s, shawwal), isEmpty);
  });

  test('"Display over other apps" is optional: a blocked overlay is not "missing"', () {
    final all = {for (final k in PermKey.values) k: true};
    expect(PermissionStatus(all, null).missingForReminders, 0);
    expect(PermissionStatus({...all, PermKey.overlay: false}, null).missingForReminders, 0);
    expect(Permissions.info(PermKey.overlay).optional, isTrue);
    // The ones reminders really need still count.
    expect(PermissionStatus({...all, PermKey.fullScreen: false}, null).missingForReminders, 1);
    expect(PermissionStatus({...all, PermKey.notifications: false}, null).missingForReminders, 1);
    expect(PermissionStatus({...all, PermKey.exactAlarm: false}, null).missingForReminders, 1);
    // Location only affects prayer times.
    expect(PermissionStatus({...all, PermKey.location: false}, null).missingForReminders, 0);
  });
}
