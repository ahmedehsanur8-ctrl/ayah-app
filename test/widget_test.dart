import 'dart:convert';
import 'dart:io';

import 'package:ayah_reminder/models/content.dart';
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
}
