import 'dart:convert';
import 'dart:io';

import 'package:ayah_reminder/models/content.dart';
import 'package:ayah_reminder/models/story.dart';
import 'package:ayah_reminder/services/audio.dart';
import 'package:ayah_reminder/services/bangla_tts.dart';
import 'package:ayah_reminder/services/rotation.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('29 Sahaba stories, 150-250 words, with source, lesson and draft mark', () {
    final stories = Story.listFromJson(File('assets/stories.json').readAsStringSync(), {});
    expect(stories.length, 29);
    expect(stories.map((s) => s.id).toSet().length, 29);
    for (final s in stories) {
      final words = s.body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      expect(words, inInclusiveRange(150, 250), reason: s.id);
      expect(s.source, isNotEmpty, reason: s.id);
      expect(s.lesson, isNotEmpty, reason: s.id);
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
}
