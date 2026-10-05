import 'dart:convert';
import 'dart:io';

import 'learn_test_helpers.dart';

import 'dart:math' as math;

import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/screens/arabic_screens.dart';
import 'package:ayah_reminder/services/arabic.dart';
import 'package:ayah_reminder/services/quran.dart';
import 'package:ayah_reminder/theme.dart';
import 'package:ayah_reminder/widgets/arabic_games.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home, [Brightness b = Brightness.light]) => MaterialApp(
  theme: buildTheme(Brightness.light),
  darkTheme: buildTheme(Brightness.dark),
  themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Widget game(Widget g) => app(Scaffold(body: g));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppState.load();
    await Quran.loadMeta();
    await Quran.load();
    await ArabicCourse.load();
    await attachLearnForTests();
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(
          Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())),
        );
      }
      await loader.load();
    }

    await load('AmiriQuran', ['AmiriQuran-Regular.ttf']);
    await load('HindSiliguri', [
      'HindSiliguri-Regular.ttf',
      'HindSiliguri-Medium.ttf',
      'HindSiliguri-SemiBold.ttf',
      'HindSiliguri-Bold.ttf',
    ]);
    await load('NotoSansBengali', ['NotoSansBengali-Regular.ttf', 'NotoSansBengali-Bold.ttf']);
    await load('NotoSerifBengali', ['NotoSerifBengali-SemiBold.ttf', 'NotoSerifBengali-Bold.ttf']);
  });

  group('course data', () {
    test('level 1 has about 20 lessons; levels 2-4 are coming', () {
      expect(ArabicCourse.lessons.length, inInclusiveRange(18, 24));
      expect(ArabicCourse.levels.map((l) => l.ready), [true, false, false, false]);
      expect(ArabicCourse.levels.map((l) => l.title), [
        'পড়তে শিখি',
        'কুরআনের শব্দ',
        'সহজ ব্যাকরণ',
        'বুঝে পড়ি',
      ]);
    });

    test('all 28 letters and hamza, each with fatha, kasra and damma', () {
      final letters = ArabicCourse.items.values.where((i) => i.kind == 'letter').toList();
      expect(letters.length, 29);
      for (var n = 1; n <= 28; n++) {
        for (final v in ['a', 'i', 'u']) {
          final id = 'S${n.toString().padLeft(2, '0')}$v';
          expect(ArabicCourse.item(id), isNotNull, reason: id);
          expect(ArabicCourse.item(id)!.audio, isNotNull);
        }
      }
    });

    test('every lesson has an explanation and 2-4 games that use known items', () {
      for (final l in ArabicCourse.lessons) {
        expect(l.intro, isNotEmpty, reason: l.id);
        expect(l.games.length, inInclusiveRange(2, 4), reason: l.id);
        for (final g in l.games) {
          for (final key in ['items', 'pool']) {
            for (final id in ((g[key] ?? const []) as List).cast<String>()) {
              expect(ArabicCourse.item(id), isNotNull, reason: '${l.id} $id');
            }
          }
        }
      }
      final types = {
        for (final l in ArabicCourse.lessons)
          for (final g in l.games) g['type'],
      };
      expect(types, containsAll(['listen', 'match', 'arrange', 'trace']));
    });

    test('Quran words are spelled exactly as in the app\'s Tanzil text', () {
      final words = ArabicCourse.items.values.where((i) => i.kind == 'word').toList();
      expect(words.length, greaterThan(40));
      for (final w in words) {
        final p = w.ref!.split(':');
        final ayah = Quran.arabicOf(int.parse(p[0]), int.parse(p[1]));
        expect(ayah.split(' '), contains(w.ar), reason: '${w.id} ${w.ref}');
      }
    });

    test('the recording list names every audio file of the lessons', () {
      final list = File('docs/ARABIC_AUDIO_LIST.md').readAsStringSync();
      final files = {
        for (final i in ArabicCourse.items.values)
          if (i.audio != null) i.audio!,
      };
      expect(files.length, greaterThan(200));
      for (final f in files) {
        expect(list, contains('`$f`'));
      }
      expect(Directory('assets/arabic_audio').existsSync(), isTrue);
    });

    test('level 2 list: 300 lemmas with root, count and empty Bangla', () {
      final j = jsonDecode(
        File('assets/arabic/level2_words.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final words = (j['words'] as List).cast<Map<String, dynamic>>();
      expect(words.length, 300);
      expect(j['total_words'], 77429);
      expect(j['coverage_percent'], greaterThan(60));
      expect(j['source'], contains('Quranic Arabic Corpus'));
      expect(j['source'], contains('GNU'));
      expect(words.first['lemma'], 'مِن');
      expect(words.every((w) => w['bn'] == ''), isTrue);
      expect(
        words.map((w) => w['count'] as int).toList(),
        orderedEquals([...words.map((w) => w['count'] as int)]..sort((a, b) => b.compareTo(a))),
      );
    });
  });

  group('progress', () {
    final pr = ArabicProgress.instance;
    final day1 = DateTime(2026, 10, 1, 9);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await pr.reload();
    });

    test('stars from mistakes', () {
      expect(ArabicProgress.starsFor(0), 3);
      expect(ArabicProgress.starsFor(2), 3);
      expect(ArabicProgress.starsFor(3), 2);
      expect(ArabicProgress.starsFor(6), 2);
      expect(ArabicProgress.starsFor(7), 1);
    });

    test('lessons unlock one by one and keep the best stars', () async {
      final l = ArabicCourse.lessons;
      expect(pr.isUnlocked(0), isTrue);
      expect(pr.isUnlocked(1), isFalse);
      await pr.finishLesson(l[0].id, 2, now: day1);
      expect(pr.isUnlocked(1), isTrue);
      expect(pr.isUnlocked(2), isFalse);
      await pr.finishLesson(l[0].id, 1, now: day1);
      expect(pr.starsOf(l[0].id), 2);
      await pr.finishLesson(l[0].id, 3, now: day1);
      expect(pr.starsOf(l[0].id), 3);
      expect(pr.nextIndex, 1);
    });

    test('daily streak', () async {
      expect(pr.streak(now: day1), 0);
      await pr.practiced(now: day1);
      await pr.practiced(now: day1.add(const Duration(hours: 5)));
      expect(pr.streak(now: day1), 1);
      await pr.practiced(now: day1.add(const Duration(days: 1)));
      expect(pr.streak(now: day1.add(const Duration(days: 1))), 2);
      // Still shown the next day (not practised yet), gone after a missed day.
      expect(pr.streak(now: day1.add(const Duration(days: 2))), 2);
      expect(pr.streak(now: day1.add(const Duration(days: 3))), 0);
      await pr.practiced(now: day1.add(const Duration(days: 4)));
      expect(pr.streak(now: day1.add(const Duration(days: 4))), 1);
    });

    test('wrong answers come back later and leave after enough right answers', () async {
      await pr.markWrong(['L02', 'S03a', 'not-an-item'], now: day1);
      expect(pr.dueItems(now: day1), isEmpty);
      final d2 = day1.add(const Duration(days: 1));
      expect(pr.dueItems(now: d2).toSet(), {'L02', 'S03a'});
      await pr.markRight(['L02'], now: d2);
      expect(pr.dueItems(now: d2), ['S03a']);
      // Intervals grow: 2, 4, 7, 15 days.
      var t = d2;
      for (final gap in [2, 4, 7, 15]) {
        expect(pr.dueItems(now: t.add(Duration(days: gap - 1))), isNot(contains('L02')));
        t = t.add(Duration(days: gap));
        expect(pr.dueItems(now: t), contains('L02'));
        await pr.markRight(['L02'], now: t);
      }
      expect(pr.dueItems(now: t.add(const Duration(days: 100))), isNot(contains('L02')));
    });
  });

  group('games', () {
    List<ArItem> items(List<String> ids) => [for (final id in ids) ArabicCourse.item(id)!];

    setUp(() => ArabicAudio.files = {});

    testWidgets('শুনে বেছে নিন without recordings shows the Bangla sound', (t) async {
      GameResult? done;
      final its = items(['L02', 'L03', 'L04', 'L01']);
      await t.pumpWidget(
        game(
          ListenGame(
            items: its,
            pool: its,
            rounds: 4,
            onDone: (r) => done = r,
            random: math.Random(1),
          ),
        ),
      );
      expect(find.text('শুনে বেছে নিন'), findsOneWidget);
      expect(find.text('অডিও শীঘ্রই'), findsOneWidget);
      for (var k = 0; k < 4; k++) {
        final prompt = t.widget<Text>(find.byKey(const ValueKey('listen-prompt'))).data!;
        final target = its.firstWhere((i) => '"${i.bn}"' == prompt);
        await t.tap(find.text(target.ar));
        await t.pump(const Duration(milliseconds: 700));
      }
      expect(done, isNotNull);
      expect(done!.mistakes, 0);
      expect(done!.seen.length, 4);
    });

    testWidgets('a wrong answer counts and the letter comes again', (t) async {
      GameResult? done;
      final its = items(['L02', 'L03']);
      await t.pumpWidget(
        game(
          ListenGame(
            items: its,
            pool: its,
            rounds: 2,
            onDone: (r) => done = r,
            random: math.Random(3),
          ),
        ),
      );
      final prompt = t.widget<Text>(find.byKey(const ValueKey('listen-prompt'))).data!;
      final wrong = its.firstWhere((i) => '"${i.bn}"' != prompt);
      await t.tap(find.text(wrong.ar));
      await t.pump(const Duration(milliseconds: 1400));
      // Two more questions: the second letter and the repeated one.
      for (var k = 0; k < 2; k++) {
        final p = t.widget<Text>(find.byKey(const ValueKey('listen-prompt'))).data!;
        await t.tap(find.text(its.firstWhere((i) => '"${i.bn}"' == p).ar));
        await t.pump(const Duration(milliseconds: 700));
      }
      expect(done!.mistakes, 1);
      expect(done!.wrong.length, 1);
    });

    testWidgets('মেলান pairs Arabic with its meaning', (t) async {
      GameResult? done;
      final its = items(['W_baab', 'W_walad', 'W_kataba']);
      await t.pumpWidget(game(MatchGame(items: its, right: 'meaning', onDone: (r) => done = r)));
      // One wrong pair first.
      await t.tap(find.text(its[0].ar));
      await t.tap(find.text(its[1].meaning!));
      await t.pump(const Duration(milliseconds: 700));
      for (final i in its) {
        await t.tap(find.text(i.ar));
        await t.tap(find.text(i.meaning!));
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 600));
      expect(done!.mistakes, 1);
      expect(done!.wrong, {'W_baab'});
    });

    testWidgets('সাজান builds a word from its letters, right to left', (t) async {
      GameResult? done;
      final w = ArabicCourse.item('W_khalaqa')!;
      final parts = ['خَ', 'لَ', 'قَ'];
      await t.pumpWidget(
        game(
          ArrangeGame(
            puzzles: [
              {'item': w.id, 'parts': parts},
            ],
            hint: 'সাজান',
            onDone: (r) => done = r,
            random: math.Random(2),
          ),
        ),
      );
      for (var k = 0; k < parts.length; k++) {
        await t.tap(find.byKey(ValueKey('tile-$k')));
        await t.pump();
      }
      expect(find.text(w.ar), findsOneWidget);
      await t.tap(find.text('শেষ'));
      expect(done!.mistakes, 0);
    });

    testWidgets('সাজান: a wrong order is a mistake and sends tiles back', (t) async {
      GameResult? done;
      await t.pumpWidget(
        game(
          ArrangeGame(
            puzzles: [
              {
                'item': null,
                'parts': ['ا', 'ب', 'ت'],
              },
            ],
            hint: '',
            onDone: (r) => done = r,
            random: math.Random(2),
          ),
        ),
      );
      for (final k in [2, 1, 0]) {
        await t.tap(find.byKey(ValueKey('tile-$k')));
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 800));
      for (final k in [0, 1, 2]) {
        final tile = find.byKey(ValueKey('tile-$k'));
        if (tile.evaluate().isNotEmpty) {
          await t.tap(tile);
          await t.pump();
        }
      }
      expect(find.text('ঠিক হয়েছে!'), findsOneWidget);
      await t.tap(find.text('শেষ'));
      expect(done!.mistakes, 1);
    });

    testWidgets('quiz', (t) async {
      GameResult? done;
      await t.pumpWidget(
        game(
          QuizGame(
            questions: [
              {
                'q': 'কোনটি মোটা ত?',
                'ar': '',
                'options': ['ط', 'ت'],
                'answer': 0,
                'optionsAr': true,
                'explain': '',
              },
            ],
            onDone: (r) => done = r,
          ),
        ),
      );
      await t.tap(find.text('ت'));
      await t.pump();
      expect(find.text('ঠিক উত্তর সবুজ করে দেখানো হলো।'), findsOneWidget);
      await t.tap(find.text('শেষ'));
      expect(done!.mistakes, 1);
    });

    // A wide bar (like the base of ب) and a tall bar (like alif) on a 48x48 board.
    const grid = 48;
    const box = 288.0;
    const cell = box / grid;
    List<bool> maskOf(bool Function(int x, int y) on) =>
        List<bool>.generate(grid * grid, (i) => on(i % grid, i ~/ grid));
    final wideBar = TraceGuide(maskOf((x, y) => x >= 8 && x <= 40 && y >= 22 && y <= 25), box);
    final tallBar = TraceGuide(maskOf((x, y) => x >= 22 && x <= 25 && y >= 8 && y <= 40), box);
    List<Offset> along(double fromX, double toX, {double y = 23.5}) => [
      for (var k = 0; k <= 40; k++) Offset((fromX + (toX - fromX) * k / 40) * cell, y * cell),
    ];

    test('tracing: the usual way passes, and the hint points right to left', () {
      expect(wideBar.wide, isTrue);
      expect(wideBar.start.dx, greaterThan(box * 0.75)); // starts at the right
      final s = scoreTrace(wideBar, [along(40, 8)]);
      expect(s.coverage, greaterThan(0.9));
      expect(s.passed(), isTrue);
      expect(s.passed(strict: true), isTrue);
      expect(tallBar.wide, isFalse);
      expect(tallBar.start.dy, lessThan(box * 0.25)); // starts at the top
    });

    test('tracing: starting from the middle passes', () {
      // Middle to the left end, then middle to the right end.
      final s = scoreTrace(wideBar, [along(24, 8), along(24, 40)]);
      expect(s.counted, 2);
      expect(s.passed(), isTrue);
      // A single stroke from the middle that covers enough also passes.
      expect(scoreTrace(wideBar, [along(30, 6)]).passed(), isTrue);
    });

    test('tracing: drawing in reverse passes (not in strict mode)', () {
      final s = scoreTrace(wideBar, [along(8, 40)]);
      expect(s.passed(), isTrue);
      expect(s.directionOk, isFalse);
      expect(s.passed(strict: true), isFalse);
      final down = [for (var y = 8; y <= 40; y++) Offset(23.5 * cell, y * cell)];
      expect(scoreTrace(tallBar, [down.reversed.toList()]).passed(), isTrue);
      expect(scoreTrace(tallBar, [down]).passed(strict: true), isTrue);
    });

    test('tracing: several strokes add up', () {
      final parts = [along(40, 30), along(30, 20), along(20, 8)];
      // Each piece alone is not enough.
      for (final part in parts) {
        expect(scoreTrace(wideBar, [part]).passed(), isFalse);
      }
      final s = scoreTrace(wideBar, parts);
      expect(s.counted, 3);
      expect(s.passed(), isTrue);
    });

    test('tracing: a little outside is fine, far strokes are ignored', () {
      // About 4% of the board off the line.
      expect(scoreTrace(wideBar, [along(40, 8, y: 23.5 + 2)]).passed(), isTrue);
      // A stroke in a far corner does not count and does not block success.
      final far = [for (var x = 0; x < 10; x++) Offset(x * cell, 2 * cell)];
      final s = scoreTrace(wideBar, [far, along(40, 8)]);
      expect(s.ignored, 1);
      expect(s.passed(), isTrue);
      // Only far strokes: nothing traced.
      expect(scoreTrace(wideBar, [far]).coverage, 0);
      // Half the letter is not enough yet.
      expect(scoreTrace(wideBar, [along(40, 26)]).passed(), isFalse);
    });

    test('tracing: strict mode checks the start point and the direction', () {
      // Right way, right start.
      final good = scoreTrace(wideBar, [along(40, 8)]);
      expect(good.startOk && good.directionOk, isTrue);
      // Right direction but started in the middle.
      final middle = scoreTrace(wideBar, [along(24, 8), along(40, 24)]);
      expect(middle.passed(), isTrue);
      expect(middle.startOk, isFalse);
      expect(middle.passed(strict: true), isFalse);
      // Wrong direction.
      expect(scoreTrace(wideBar, [along(8, 40)]).passed(strict: true), isFalse);
    });

    testWidgets('tracing: letters with dots pass without the dots (ب ت ث ج ح خ)', (t) async {
      for (final (ch, dots) in const [
        ('ب', true),
        ('ت', true),
        ('ث', true),
        ('ج', true),
        ('ح', false),
        ('خ', true),
      ]) {
        final mask = (await t.runAsync(() => letterMask(ch, box)))!;
        final g = TraceGuide(mask, box);
        expect(g.body, isNotEmpty, reason: ch);
        expect(g.marks.isNotEmpty, dots, reason: '$ch dots');
        // A child tracing only the body, column by column the usual way.
        final cols = <int, List<int>>{};
        for (final c in g.body) {
          cols.putIfAbsent(c % grid, () => []).add(c);
        }
        final stroke = <Offset>[];
        for (final x in cols.keys.toList()..sort((a, b) => b - a)) {
          final ys = cols[x]!.map((c) => c ~/ grid).toList()..sort();
          // Down one column, up the next, through every cell of the body.
          final down = stroke.length.isEven;
          for (final y in down ? ys : ys.reversed) {
            stroke.add(g.center(y * grid + x));
          }
        }
        final s = scoreTrace(g, [stroke]);
        expect(s.passed(), isTrue, reason: '$ch: ${s.coverage}');
        // Adding the dots as an extra stroke is fine too.
        if (dots) {
          final dotStroke = [for (final c in g.marks) g.center(c)];
          final withDots = scoreTrace(g, [stroke, dotStroke]);
          expect(withDots.passed(), isTrue, reason: ch);
          expect(withDots.markTouched, isTrue, reason: ch);
        }
        // Dots alone are not the letter.
        if (dots) {
          expect(
            scoreTrace(g, [
              [for (final c in g.marks) g.center(c)],
            ]).passed(),
            isFalse,
            reason: ch,
          );
        }
      }
    });

    testWidgets('লিখে দেখুন shows the board and the letter name', (t) async {
      await t.pumpWidget(game(TraceGame(items: items(['L02']), onDone: (_) {})));
      expect(find.text('লিখে দেখুন'), findsOneWidget);
      expect(find.byKey(const ValueKey('trace-board')), findsOneWidget);
      expect(find.text('বা'), findsOneWidget);
      expect(find.text('দেখান'), findsOneWidget);
      expect(find.text('আবার লিখুন'), findsOneWidget);
      expect(find.byKey(const ValueKey('trace-progress')), findsOneWidget);
      await t.tap(find.text('হয়ে গেছে'));
      await t.pump();
      expect(find.text('আগে আঙুল দিয়ে অক্ষরটির ওপর দিয়ে টানুন।'), findsOneWidget);
      // Strict mode is off by default and can be turned on.
      expect(ArabicProgress.instance.traceStrict, isFalse);
      await t.ensureVisible(find.byKey(const ValueKey('trace-strict')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('trace-strict')));
      await t.pump();
      expect(ArabicProgress.instance.traceStrict, isTrue);
      await ArabicProgress.instance.setTraceStrict(false);
    });

    testWidgets('লিখে দেখুন: drawing up and down draws, it does not scroll the page', (t) async {
      await t.pumpWidget(game(TraceGame(items: items(['L01']), onDone: (_) {})));
      final board = find.byKey(const ValueKey('trace-board'));
      final before = t.getTopLeft(board);
      await t.drag(board, const Offset(0, 120));
      await t.pump();
      expect(t.getTopLeft(board), before);
      // The stroke can be cleared.
      await t.tap(find.text('আবার লিখুন'));
      await t.pump();
    });
  });

  for (final b in Brightness.values) {
    group('$b screens', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await ArabicProgress.instance.reload();
        ArabicAudio.files = {};
      });

      testWidgets('home: levels, coming soon, lesson list and a whole lesson', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const ArabicHomeScreen(), b));
        await t.pumpAndSettle();
        expect(find.text('সহজ আরবি'), findsOneWidget);
        expect(find.text('প্রথম পাঠ শুরু করি'), findsOneWidget);
        await t.scrollUntilVisible(find.text('৪. বুঝে পড়ি'), 200);
        // Levels 2–4 open কুরআন বুঝি; nothing says "coming soon".
        expect(find.text('শীঘ্রই আসছে'), findsNothing);
        expect(find.text('কুরআন বুঝি'), findsOneWidget);
        expect(find.text('২০টি পাঠ তৈরি'), findsOneWidget);
        expect(find.text('৫টি পাঠ তৈরি'), findsOneWidget);
        await t.tap(find.text('৩. সহজ ব্যাকরণ'));
        await settleLearn(t);
        expect(find.text('তৈরি: ২০টি পাঠ · শেষ: ০টি'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        await t.tap(find.text('৪. বুঝে পড়ি'));
        await settleLearn(t);
        expect(find.text('তৈরি: ৫টি পাঠ · শেষ: ০টি'), findsOneWidget);
        expect(find.text('৭. পুরো ফাতিহা বুঝি'), findsOneWidget);
        // A lesson out of order still opens, after a short tip.
        await t.tap(find.text('৭. পুরো ফাতিহা বুঝি'));
        await settleLearn(t);
        await t.tap(find.text('খুলুন'));
        await settleLearn(t, 20);
        expect(find.text('পরের ধাপ'), findsOneWidget);
        await t.pageBack();
        await settleLearn(t, 20);
        await t.tap(find.text('বের হই'));
        await settleLearn(t, 20);
        await t.pageBack();
        await settleLearn(t, 20);
        await t.scrollUntilVisible(
          find.text('১. পড়তে শিখি'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );

        await t.tap(find.text('১. পড়তে শিখি'));
        await t.pumpAndSettle();
        expect(find.text('আলিফ থেকে ছা'), findsOneWidget);
        // Lesson 2 is locked until lesson 1 is done.
        await t.tap(find.text('জীম থেকে যাল'));
        await t.pump();
        expect(find.text('আগের পাঠ শেষ করলে এই পাঠ খুলবে।'), findsOneWidget);
        await t.pumpAndSettle(const Duration(seconds: 5));

        await t.tap(find.text('আলিফ থেকে ছা'));
        await t.pumpAndSettle();
        expect(find.textContaining('ডান দিক থেকে বাঁ দিকে'), findsOneWidget);
        await t.tap(find.text('শুরু করি'));
        await t.pumpAndSettle();
        expect(find.text('অডিও শীঘ্রই'), findsWidgets);
        await t.tap(find.text('ب').first);
        await t.pumpAndSettle();
        expect(find.textContaining('দুই ঠোঁট মিলিয়ে'), findsOneWidget);
        Navigator.of(t.element(find.textContaining('দুই ঠোঁট মিলিয়ে'))).pop();
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('অনুশীলন শুরু করি'), 200);
        await t.tap(find.text('অনুশীলন শুরু করি'));
        await t.pumpAndSettle();
        expect(find.text('শুনে বেছে নিন'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('every lesson opens, shows its cards and first game', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        for (var i = 0; i < ArabicCourse.lessons.length; i++) {
          await t.pumpWidget(app(LessonScreen(key: ValueKey(i), index: i), b));
          await t.pumpAndSettle();
          await t.tap(find.text('শুরু করি'));
          await t.pumpAndSettle();
          await t.scrollUntilVisible(find.text('অনুশীলন শুরু করি'), 400);
          await t.tap(find.text('অনুশীলন শুরু করি'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 100));
          final type = ArabicCourse.lessons[i].games.first['type'] as String;
          expect(find.text(gameTitle(type)), findsOneWidget, reason: ArabicCourse.lessons[i].title);
          expect(t.takeException(), isNull, reason: ArabicCourse.lessons[i].title);
        }
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle(const Duration(seconds: 3));
      });

      testWidgets('review of wrong letters', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await ArabicProgress.instance.markWrong(['L02', 'L03', 'L05'], now: DateTime(2020));
        await t.pumpWidget(app(const ArabicHomeScreen(), b));
        await t.pumpAndSettle();
        expect(find.text('আজকের রিভিশন'), findsOneWidget);
        await t.tap(find.text('আজকের রিভিশন'));
        await t.pumpAndSettle();
        expect(find.text('শুনে বেছে নিন'), findsOneWidget);
      });
    });
  }
}
