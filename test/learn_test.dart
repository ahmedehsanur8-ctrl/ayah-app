import 'dart:io';

import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/features/learn/data/content_repository.dart';
import 'package:ayah_reminder/features/learn/data/progress_repository.dart';
import 'package:ayah_reminder/features/learn/domain/models.dart';
import 'package:ayah_reminder/features/learn/srs/srs_service.dart';
import 'package:ayah_reminder/features/learn/state/learn_controller.dart';
import 'package:ayah_reminder/features/learn/ui/screens/learn_screens.dart';
import 'package:ayah_reminder/features/learn/ui/screens/lesson_screen.dart';
import 'package:ayah_reminder/screens/reading_screen.dart';
import 'package:ayah_reminder/features/learn/ui/widgets/learn_widgets.dart';
import 'package:ayah_reminder/features/learn/ui/widgets/word_sheet.dart';
import 'package:ayah_reminder/services/quran.dart';
import 'package:ayah_reminder/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget app(Widget home, Brightness b) => MaterialApp(
  theme: buildTheme(Brightness.light),
  darkTheme: buildTheme(Brightness.dark),
  themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

/// sqflite answers outside the test clock: let real time pass, then pump.
Future<void> settle(WidgetTester t, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

late ContentRepository content;

Future<ProgressRepository> freshProgress() =>
    ProgressRepository.open(inMemoryDatabasePath).then((p) async {
      for (final t in [
        'learn_card',
        'learn_review_log',
        'learn_lesson_progress',
        'learn_settings',
        'learn_activity',
      ]) {
        await p.db.delete(t);
      }
      return p;
    });

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await AppState.load();
    await Quran.loadMeta();
    content = ContentRepository(
      await databaseFactory.openDatabase(
        File(ContentRepository.asset).absolute.path,
        options: OpenDatabaseOptions(readOnly: true),
      ),
    );
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
    await load('NotoSerifBengali', ['NotoSerifBengali-SemiBold.ttf', 'NotoSerifBengali-Bold.ttf']);
  });

  group('content', () {
    test('30 lessons in three levels; every reference is a real Quran word', () async {
      final lessons = await content.lessons();
      expect(lessons.length, 30);
      expect(lessons.map((l) => l.level).toSet(), {1, 2, 3});
      final meta = await content.meta();
      expect(meta['tanzil_notice'], contains('Tanzil'));
      expect(meta['qac_notice'], contains('Quranic Arabic Corpus'));
      for (final l in lessons) {
        expect(l.steps.first, isA<AyahStep>(), reason: l.id);
        expect(l.steps.last, isA<AyahRecapStep>(), reason: l.id);
        for (final s in l.steps) {
          if (s is WordsStep) {
            final lemmas = await content.lemmas(s.lemmaIds);
            for (var i = 0; i < s.lemmaIds.length; i++) {
              final w = await content.word(s.refs[i].surah, s.refs[i].ayah, s.refs[i].index);
              expect(w, isNotNull, reason: '${l.id} ${s.refs[i]}');
              expect(w!.allLemmas, contains(s.lemmaIds[i]), reason: l.id);
              expect(lemmas[s.lemmaIds[i]]?.meaning, isNotNull, reason: l.id);
            }
          }
        }
      }
    });

    test('Bismillah: the prefix bi is a slice of the Tanzil word', () async {
      final w = (await content.ayahWords(1, 1)).first;
      expect(w.text, 'بِسْمِ');
      expect(w.segments.length, 2);
      final bi = w.segments.first.lemmaId!;
      expect(w.partFor(bi), 'بِ');
      final l = await content.lemma(bi);
      expect(l!.isDraft, isTrue);
      expect(l.meaning, isNotEmpty);
      // The ayah's words put together are the Tanzil ayah (basmala of 1:1).
      final words = await content.ayahWords(1, 1);
      await Quran.load();
      expect(words.map((w) => w.text).join(' '), Quran.displayArabic(1, 1));
    });

    test('roots: idea line and related words from the same root', () async {
      final w = (await content.ayahWords(2, 2))[1]; // ٱلْكِتَـٰبُ
      final l = (await content.lemma(w.lemmaId!))!;
      expect(l.root, isNotNull);
      final idea = await content.rootIdea(l.root!);
      expect(idea!.meaning, 'লেখা');
      final related = await content.sameRoot(l.root!, l.id);
      expect(related, isNotEmpty);
      expect(related.length, lessThanOrEqualTo(3));
    });
  });

  group('spaced repetition', () {
    test('new card, ratings, due order, daily cap of 30', () async {
      var now = DateTime.utc(2026, 10, 2, 6);
      final p = await freshProgress();
      final srs = SrsService(p, clock: () => now);
      expect(await srs.addCard(7, 'lesson'), isTrue);
      expect(await srs.addCard(7, 'lesson'), isFalse);
      final due = await srs.review(7, Rating.good, kind: 'lesson');
      expect(due.isAfter(now), isTrue);
      expect(due.isUtc, isTrue);
      // 40 cards due at different times: today's list is capped and most overdue first.
      for (var i = 100; i < 140; i++) {
        await srs.addCard(i, 'ayah_tap');
        now = now.add(const Duration(minutes: 1));
      }
      final list = await srs.dueCards();
      expect(list.length, 30);
      expect(list.first, 100);
      for (final id in list) {
        await srs.review(id, Rating.good);
      }
      expect(await srs.reviewedToday(), 30);
      expect(await srs.dueCards(), isEmpty, reason: 'cap reached');
      // Next day the cap resets.
      now = now.add(const Duration(days: 1));
      expect((await srs.dueCards()).length, greaterThan(0));
    });

    test('due dates are UTC, so a timezone change does not move them', () async {
      final p = await freshProgress();
      final t0 = DateTime.utc(2026, 10, 2, 22);
      final srs = SrsService(p, clock: () => t0);
      await srs.addCard(9, 'lesson');
      final due = await srs.review(9, Rating.easy, kind: 'lesson');
      final row = await p.card(9);
      expect(row!['due_utc'], due.toUtc().toIso8601String());
      expect((row['due_utc'] as String).endsWith('Z'), isTrue);
      // Same instant seen from another timezone: due or not depends only on the instant.
      final before = SrsService(p, clock: () => due.subtract(const Duration(minutes: 1)));
      final after = SrsService(p, clock: () => due.add(const Duration(minutes: 1)));
      expect(await before.dueCount(), 0);
      expect(await after.dueCount(), 1);
    });

    test('cards survive closing and reopening the database (app kill, reboot)', () async {
      final dir = await Directory.systemTemp.createTemp('learn');
      final path = '${dir.path}/learn_user.db';
      var p = await ProgressRepository.open(path);
      await SrsService(p).addCard(11, 'lesson');
      await p.saveLesson('L1-01', LessonStatus.done, 80, DateTime.now().toUtc().toIso8601String());
      await p.db.close();
      p = await ProgressRepository.open(path);
      expect(await p.card(11), isNotNull);
      expect((await p.lessonProgress())['L1-01']!.bestScore, 80);
      await p.db.close();
      await dir.delete(recursive: true);
    });

    test('streak: consecutive days, one free rest day a week', () {
      final now = DateTime(2026, 10, 10);
      String d(int back) => Learn.dayKey(now.subtract(Duration(days: back)));
      expect(Learn.computeStreak([], now), 0);
      expect(Learn.computeStreak([d(0), d(1), d(2)], now), 3);
      expect(Learn.computeStreak([d(1), d(2)], now), 2, reason: 'today not done yet');
      expect(Learn.computeStreak([d(0), d(2), d(3)], now), 3, reason: 'one rest day');
      expect(Learn.computeStreak([d(0), d(2), d(4)], now), 2, reason: 'two rest days in a week');
      expect(Learn.computeStreak([d(0), d(3)], now), 1);
    });
  });

  for (final b in Brightness.values) {
    group('$b', () {
      setUp(() async {
        final p = await freshProgress();
        await Learn.instance.attachForTests(content, p);
      });

      testWidgets('dashboard, path, and the whole of lesson 1', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const LearnDashboardScreen(), b));
        await settle(t);
        expect(find.text('১. বিসমিল্লাহর অর্থ'), findsOneWidget);
        expect(find.text('শুরু করুন'), findsOneWidget);
        expect(find.textContaining('প্রথম পাঠ শেষ করলে রিভিউ'), findsOneWidget);

        await t.tap(find.text('সব পাঠ'));
        await settle(t);
        expect(find.text('স্তর ১ · যা প্রতিদিন পড়ি'), findsOneWidget);
        expect(find.textContaining('আগের পাঠ শেষ করে এলে সহজ হবে'), findsWidgets);
        await t.pageBack();
        await settle(t);

        final lesson = Learn.instance.lessons.first;
        await t.tap(find.text('শুরু করুন'));
        await settle(t);
        // 1. ayah
        expect(find.text('আয়াত'), findsWidgets);
        await t.tap(find.text('বাংলা অর্থ দেখুন'));
        await settle(t);
        expect(find.textContaining('নামে'), findsOneWidget);
        expect(find.textContaining('[১]'), findsNothing);
        await t.tap(find.text('পরের ধাপ'));
        await settle(t);
        // 2. words
        expect(find.text('নাম'), findsOneWidget);
        expect(find.text('খসড়া'), findsWidgets);
        await t.tap(find.text('পরের ধাপ'));
        await settle(t);
        // 3. explain
        expect(find.text('বুঝি'), findsOneWidget);
        await t.tap(find.text('পরের ধাপ'));
        await settle(t);
        // 4. quiz: answer every item correctly.
        final quiz = lesson.steps.whereType<QuizStep>().first;
        final lemmas = await t.runAsync(
          () => content.lemmas({
            for (final it in quiz.items) ...[
              if (it.lemmaId != null) it.lemmaId!,
              ...it.distractors,
            ],
          }),
        );
        for (final it in quiz.items) {
          switch (it.kind) {
            case 'split':
              final w = (await t.runAsync(() => content.word(it.surah!, it.ayah!, it.wordIndex!)))!;
              final parts = await t.runAsync(() => content.lemmas(w.allLemmas));
              for (final s in w.segments) {
                await t.tap(find.text(parts![s.lemmaId]!.meaning!).last);
                await t.pump(const Duration(milliseconds: 800));
                await settle(t, 3);
              }
            case 'order':
              final words = (await t.runAsync(() => content.ayahWords(it.surah!, it.ayah!)))!;
              for (final w in words) {
                await t.tap(find.text(w.text).last);
                await t.pump();
              }
              await t.tap(find.text('মিলিয়ে দেখুন'));
              await t.pump();
            case 'mcq_bn_ar':
              final w = (await t.runAsync(() async {
                final l = lemmas![it.lemmaId]!;
                for (final s in lesson.steps.whereType<WordsStep>()) {
                  final i = s.lemmaIds.indexOf(l.id);
                  if (i >= 0) return content.word(s.refs[i].surah, s.refs[i].ayah, s.refs[i].index);
                }
                return null;
              }))!;
              await t.tap(find.text(w.partFor(it.lemmaId!)).last);
              await t.pump();
            default:
              await t.tap(find.text(lemmas![it.lemmaId]!.meaning!).last);
              await t.pump();
          }
          await settle(t, 2);
          expect(find.text('ঠিক হয়েছে!'), findsOneWidget, reason: it.kind);
          await t.tap(find.textContaining(RegExp('পরের প্রশ্ন|ফল দেখুন')));
          await settle(t, 2);
        }
        expect(find.textContaining('(১০০%)'), findsOneWidget);
        await t.tap(find.text('পরের ধাপ'));
        await settle(t);
        // 5. recall: rate every word.
        for (var i = 0; i < lesson.newLemmas.length; i++) {
          await t.tap(find.text('অর্থ দেখুন'));
          await t.pump();
          await t.tap(find.text('মনে আছে'));
          await settle(t, 2);
        }
        await t.tap(find.text('পরের ধাপ'));
        await settle(t);
        // 6. recap: every counted word of Bismillah is now known.
        expect(find.text('৪টি শব্দের ৪টি চিনেছেন'), findsOneWidget);
        await t.tap(find.text('পাঠ শেষ'));
        await settle(t, 20);

        final learn = Learn.instance;
        expect(learn.statusOf(lesson), LessonStatus.done);
        expect(learn.statusOf(learn.lessons[1]), LessonStatus.available);
        expect(learn.known, containsAll(lesson.newLemmas));
        expect(learn.learningMode, isTrue, reason: 'auto-on after lesson 1');
        expect(learn.streak, 1);
        expect(find.text('২. সব প্রশংসা আল্লাহর'), findsOneWidget);
      });

      testWidgets('tappable ayah, word sheet with roots, শিখব, review', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const LearnAyahScreen(surah: 2, ayah: 2), b));
        await settle(t);
        expect(find.text('৭টি শব্দের ০টি চেনেন'), findsOneWidget);
        await t.tap(find.text('ٱلْكِتَـٰبُ'));
        await settle(t);
        expect(find.byType(WordSheet), findsOneWidget);
        expect(find.text('কিতাব, বই'), findsOneWidget);
        await t.tap(find.text('মূল অক্ষর দেখুন'));
        await settle(t);
        expect(find.text('এই তিনটি অক্ষর থেকে ‘লেখা’ অর্থের শব্দ আসে'), findsOneWidget);
        expect(find.text('একই মূলের আরও শব্দ'), findsOneWidget);
        await t.tap(find.text('শিখব'));
        await settle(t);
        expect(find.text('রিভিউতে আছে'), findsOneWidget);
        await t.tapAt(const Offset(10, 10));
        await settle(t);
        expect(find.text('৭টি শব্দের ১টি চেনেন'), findsOneWidget);

        await t.pumpWidget(app(const LearnReviewScreen(), b));
        await settle(t);
        expect(find.text('১ / ১ · অর্থটা মনে মনে বলুন'), findsOneWidget);
        await t.tap(find.text('অর্থ দেখুন'));
        await t.pump();
        await t.tap(find.text('সহজ'));
        await settle(t);
        expect(find.textContaining('আজ ১টি শব্দ রিভিউ করেছেন'), findsOneWidget);

        await t.pumpWidget(app(const LearnWordsScreen(), b));
        await settle(t);
        expect(find.text('কিতাব, বই'), findsOneWidget);
        await t.pumpWidget(app(const LearnProgressScreen(), b));
        await settle(t);
        expect(find.text('সূরা ফাতিহা'), findsOneWidget);
        expect(find.text('৩০তম পারা'), findsOneWidget);
        await t.pumpWidget(app(const LearnCreditsScreen(), b));
        await settle(t);
        expect(find.text('Quranic Arabic Corpus (morphology v0.4)'), findsOneWidget);
        expect(find.text('FSRS (package:fsrs)'), findsOneWidget);
      });

      testWidgets('reminder screen: one button for ayahs; learning mode marks known words', (
        t,
      ) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        final data = AppState.instance.data;
        final ayah = data.items.firstWhere((i) => i.isAyah && i.surah > 0 && i.ayahStart > 0);
        final hadith = data.items.firstWhere((i) => !i.isAyah);
        await AppState.instance.settings.setLearnModeOn(false);

        await t.pumpWidget(app(ReadingScreen(key: UniqueKey(), item: hadith), b));
        await t.pump(const Duration(seconds: 1));
        expect(find.text('এই আয়াত বুঝুন'), findsNothing);

        await t.pumpWidget(app(ReadingScreen(key: UniqueKey(), item: ayah), b));
        await t.pump(const Duration(seconds: 1));
        expect(find.text('এই আয়াত বুঝুন'), findsOneWidget);
        expect(find.textContaining('শব্দের'), findsNothing, reason: 'learning mode off');

        // Learning mode on, with one word of the ayah known.
        final learn = Learn.instance;
        final words = (await t.runAsync(
          () => content.ayahWords(ayah.surah, ayah.ayahStart, ayah.ayahEnd),
        ))!;
        final first = words.firstWhere((w) => w.lemmaId != null);
        await t.runAsync(() async {
          await learn.setLearningMode(true);
          await learn.addWord(first.lemmaId!);
        });
        expect(AppState.instance.settings.learnModeOn, isTrue);
        await t.pumpWidget(app(ReadingScreen(key: UniqueKey(), item: ayah), b));
        await settle(t);
        final counted = words.where((w) => w.lemmaId != null).toList();
        final known = counted.where((w) => w.lemmaId == first.lemmaId).length;
        expect(find.text(knownLine(known, counted.length)), findsOneWidget);

        await t.ensureVisible(find.text('এই আয়াত বুঝুন'));
        await t.pump();
        await t.tap(find.text('এই আয়াত বুঝুন'));
        await settle(t);
        expect(find.byType(LearnAyahScreen), findsOneWidget);
        await t.runAsync(() => learn.setLearningMode(false));
        // Let the 12-second countdown and timers finish.
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 13));
      });

      testWidgets('every lesson opens on a small phone at 1.3× text', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        for (final l in Learn.instance.lessons) {
          await t.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(size: Size(360, 740), textScaler: TextScaler.linear(1.3)),
              child: app(LessonScreen(key: ValueKey(l.id), lesson: l), b),
            ),
          );
          // The lesson loads from the database; wait for it (bounded) rather
          // than a fixed number of rounds, which raced on a busy machine.
          for (var i = 0; i < 10 && find.text('পরের ধাপ').evaluate().isEmpty; i++) {
            await settle(t, 3);
          }
          expect(find.text('পরের ধাপ'), findsOneWidget, reason: l.id);
        }
      });
    });
  }
}
