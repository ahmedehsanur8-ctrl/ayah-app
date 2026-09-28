import 'dart:convert';
import 'dart:io';

import 'package:ayah_reminder/models/content.dart';
import 'package:ayah_reminder/models/story.dart';
import 'package:ayah_reminder/models/surah_names.dart';
import 'package:ayah_reminder/models/topics.dart';
import 'package:ayah_reminder/services/audio.dart';
import 'package:ayah_reminder/services/bangla_tts.dart';
import 'package:ayah_reminder/services/prayer.dart';
import 'package:ayah_reminder/services/rotation.dart';
import 'package:ayah_reminder/services/settings.dart';
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
    await s.setAzanMode('asr', 'notify');
    await s.setAzanMode('isha', 'off');
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
}
