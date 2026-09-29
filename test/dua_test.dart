import 'dart:io';

import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/screens/dua_screens.dart';
import 'package:ayah_reminder/services/duas.dart';
import 'package:ayah_reminder/services/quran.dart';
import 'package:ayah_reminder/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Items of sections 1–15 in dua-list.md (section 16 is the exclude list).
int listCount() {
  var section = 0, n = 0;
  for (final raw in File('dua-list.md').readAsLinesSync()) {
    final line = raw.trim();
    final m = RegExp(r'^(\d+)\.\s').firstMatch(line);
    if (m != null) {
      section = int.parse(m[1]!);
      continue;
    }
    if (section < 1 || section > 15 || line.isEmpty) continue;
    if (section == 15) {
      n += line.split(',').where((r) => r.trim().isNotEmpty).length;
    } else if (line.contains('|')) {
      n++;
    }
  }
  return n;
}

Widget app(Widget home) => MaterialApp(theme: buildTheme(Brightness.light), home: home);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppState.load();
    await Quran.loadMeta();
    await Duas.load();
  });

  test('every dua of dua-list.md sections 1–15 is in the app', () {
    expect(Duas.sections.length, 15);
    expect(Duas.all.length, listCount());
    for (final s in Duas.sections) {
      expect(Duas.inSection(s.n).length, s.count, reason: s.title);
    }
    expect(Duas.all.map((d) => d.id).toSet().length, Duas.all.length);
  });

  test('grades, review marks and sources', () {
    expect(Duas.all.every((d) => const {'S', 'H', 'Q', 'A', 'R'}.contains(d.grade)), isTrue);
    expect(Duas.all.every((d) => d.needsReview), isTrue);
    expect(Duas.all.every((d) => d.source.isNotEmpty), isTrue);
    expect(Duas.all.where((d) => d.grade == 'R').length, 11);
    expect(Duas.all.where((d) => d.grade == 'R').every((d) => d.reviewReason.isNotEmpty), isTrue);
    expect(Duas.all.where((d) => d.grade == 'A').every((d) => d.athar), isTrue);
    expect(Duas.byId('01-05')!.source, 'সহিহ বুখারি ৬৩০৬');
  });

  test('Quranic duas use the Quran text; hadith duas have উচ্চারণ', () {
    for (final d in Duas.all) {
      if (d.isQuranText) {
        expect(d.uccharon, isEmpty, reason: d.id);
        expect(d.arabic, isNotEmpty, reason: d.id);
        expect(d.translator, isNotEmpty, reason: d.id);
      } else if (d.arabic.isNotEmpty && !d.info) {
        expect(d.uccharon, isNotEmpty, reason: d.id);
        expect(d.bangla, isNotEmpty, reason: d.id);
      }
    }
    // 2:255 exactly as in the bundled Tanzil text.
    final kursi = Duas.byId('01-01')!;
    expect(kursi.quran.single, (surah: 2, from: 255, to: 255));
    expect(Duas.uccharonNote, 'উচ্চারণ শুধু সহায়ক; সঠিক পড়ার জন্য আরবি ও অডিও অনুসরণ করুন');
  });

  test('counters and the morning / evening sets', () {
    expect(Duas.byId('02-09')!.total, 100);
    expect(Duas.byId('03-30')!.total, 100);
    expect(Duas.byId('01-16')!.total, 100);
    final morning = Duas.adhkar(evening: false).map((d) => d.id);
    final evening = Duas.adhkar(evening: true).map((d) => d.id);
    expect(morning, contains('01-19'));
    expect(morning, isNot(contains('01-21')));
    expect(evening, contains('01-21'));
    expect(evening, isNot(contains('01-19')));
    expect(Duas.byId('01-03')!.evening, isNotNull);
  });

  test('search in Bangla, Arabic without marks and by situation', () {
    for (final w in ['ভয়', 'ঋণ', 'সফর', 'অসুস্থ']) {
      expect(Duas.search(w), isNotEmpty, reason: w);
    }
    expect(Duas.search('সফর').map((d) => d.section), contains(5));
    expect(Duas.search('অসুস্থ').map((d) => d.section), contains(6));
    expect(Duas.search('ঋণ').map((d) => d.id), contains('07-13'));
    expect(Duas.search('سبحان الله وبحمده').map((d) => d.id), contains('01-16'));
    expect(Duas.search('ইস্তিখারা').map((d) => d.id), contains('03-35'));
  });

  testWidgets('home, a dua page and the counter', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(app(const DuaHomeScreen()));
    await t.pumpAndSettle();
    expect(find.text('সকাল-সন্ধ্যার জিকির'), findsOneWidget);
    expect(find.text('জিকির শুরু করুন'), findsOneWidget);

    await t.pumpWidget(app(DuaPagerScreen(duas: Duas.inSection(1), index: 4)));
    await t.pumpAndSettle();
    expect(find.text('সাইয়্যিদুল ইস্তিগফার'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text(Duas.uccharonNote),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(Duas.uccharonNote), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('সহিহ বুখারি ৬৩০৬ · সহিহ'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('সহিহ বুখারি ৬৩০৬ · সহিহ'), findsOneWidget);

    // Three taps finish a ৩-বার dua and the next one opens.
    final two = [Duas.byId('01-12')!, Duas.byId('01-05')!];
    await t.pumpWidget(app(DuaCounterScreen(duas: two, title: 'পরীক্ষা')));
    await t.pumpAndSettle();
    expect(find.text('০/৩'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.text('চাপ দিন'));
      await t.pump();
    }
    expect(find.text('৩/৩'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('সাইয়্যিদুল ইস্তিগফার'), findsOneWidget);
    expect(find.text('০/১'), findsOneWidget);
  });
}
