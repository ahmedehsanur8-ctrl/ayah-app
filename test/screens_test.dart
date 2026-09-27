import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/screens/categories_screen.dart';
import 'package:ayah_reminder/screens/credits_screen.dart';
import 'package:ayah_reminder/screens/home_shell.dart';
import 'package:ayah_reminder/screens/reading_screen.dart';
import 'package:ayah_reminder/screens/setup_screen.dart';
import 'package:ayah_reminder/screens/splash_screen.dart';
import 'package:ayah_reminder/screens/stories_screen.dart';
import 'package:ayah_reminder/services/reminders.dart';
import 'package:ayah_reminder/theme.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Widget app(Widget home, Brightness b) => MaterialApp(
  theme: buildTheme(Brightness.light),
  darkTheme: buildTheme(Brightness.dark),
  themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tzdata.initializeTimeZones();
    Reminders.dhaka = tz.getLocation('Asia/Dhaka');
    await AppState.load();
    // Use the real fonts so text is measured like on a phone.
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
    await load('NotoSansBengali', ['NotoSansBengali-Regular.ttf', 'NotoSansBengali-Bold.ttf']);
    await load('HindSiliguri', ['HindSiliguri-SemiBold.ttf', 'HindSiliguri-Bold.ttf']);
  });

  test('default reminder times: 9:00 AM and 9:00 PM', () {
    final s = AppState.instance.settings;
    expect(s.morningTime, const TimeOfDay(hour: 9, minute: 0));
    expect(s.nightTime, const TimeOfDay(hour: 21, minute: 0));
  });

  for (final b in Brightness.values) {
    group('$b', () {
      testWidgets('home, categories, favourites and settings tabs', (t) async {
        await t.binding.setSurfaceSize(const Size(390, 844));
        await t.pumpWidget(app(const HomeShell(), b));
        await t.pumpAndSettle();
        expect(find.text('আজকের আয়াত'), findsWidgets);
        await t.scrollUntilVisible(find.text('আজকের হাদিস'), 300);
        expect(find.text('আজকের হাদিস'), findsOneWidget);

        await t.tap(find.text('পরের').last);
        await t.pumpAndSettle();

        await t.tap(find.text('বিষয়সমূহ').last);
        await t.pumpAndSettle();
        expect(find.text('আশা ও রহমত'), findsOneWidget);
        await t.tap(find.text('হাদিসের বিষয়'));
        await t.pumpAndSettle();

        await t.tap(find.text('প্রিয়'));
        await t.pumpAndSettle();
        expect(find.text('এখনো কিছু রাখা হয়নি'), findsOneWidget);

        await t.tap(find.text('সেটিংস'));
        await t.pumpAndSettle();
        expect(find.text('সকাল ৯:০০'), findsOneWidget);
        expect(find.text('রাত ৯:০০'), findsOneWidget);
        await t.scrollUntilVisible(find.text('ক্বারী (আরবি তিলাওয়াত)'), 200);
        expect(find.text('মিশারি রাশিদ আলাফাসি'), findsOneWidget);
        expect(find.text('আরবি + বাংলা অর্থ'), findsOneWidget);
      });

      testWidgets('stories list and a story page', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const StoriesScreen(), b));
        await t.pumpAndSettle();
        expect(find.text('সাহাবিদের জীবনী'), findsOneWidget);
        for (final s in AppState.instance.stories) {
          await t.pumpWidget(app(StoryScreen(key: UniqueKey(), story: s), b));
          await t.pump(const Duration(milliseconds: 300));
        }
        expect(find.text('শুনুন'), findsOneWidget);
        // The stories are long: jump to the end of the page (the list grows as it builds).
        for (
          var i = 0;
          i < 20 && find.textContaining('needs scholar review').evaluate().isEmpty;
          i++
        ) {
          final pos = t.state<ScrollableState>(find.byType(Scrollable)).position;
          pos.jumpTo(pos.maxScrollExtent);
          await t.pump();
        }
        expect(find.textContaining('needs scholar review'), findsOneWidget);
      });

      testWidgets('category page', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        final c = AppState.instance.data.ayahCategories.first;
        await t.pumpWidget(app(CategoryItemsScreen(category: c), b));
        await t.pumpAndSettle();
        expect(find.text(c.name), findsWidgets);
      });

      testWidgets('reading: countdown, favourite and share', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        final item = AppState.instance.data.items.first;
        await t.pumpWidget(app(ReadingScreen(item: item), b));
        await t.pump(const Duration(seconds: 1));
        expect(find.text('আমি পড়েছি'), findsNothing);
        await t.pump(const Duration(seconds: 12));
        await t.pumpAndSettle();
        expect(find.text('আমি পড়েছি'), findsOneWidget);

        await t.tap(find.byTooltip('প্রিয়তে রাখুন'));
        await t.pumpAndSettle();
        expect(AppState.instance.settings.isFavorite(item.id), isTrue);
        await t.tap(find.byTooltip('প্রিয় থেকে সরান'));
        await t.pumpAndSettle();

        await t.tap(find.byTooltip('ছবি হিসেবে শেয়ার করুন'));
        await t.pumpAndSettle();
        expect(find.text('শেয়ার করুন'), findsOneWidget);
      });

      testWidgets('every item renders on the reading screen', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        for (final item in AppState.instance.data.items.take(40)) {
          await t.pumpWidget(app(ReadingScreen(key: UniqueKey(), item: item), b));
          await t.pump(const Duration(milliseconds: 800));
        }
      });

      testWidgets('splash and credits', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const SplashScreen(next: CreditsScreen()), b));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text('আয়াত রিমাইন্ডার'), findsOneWidget);
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text('কৃতজ্ঞতা ও উৎস'), findsOneWidget);
      });

      testWidgets('setup', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const SetupScreen(firstTime: true), b));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('শুরু করুন'), 300);
        expect(find.text('শুরু করুন'), findsOneWidget);
      });
    });
  }
}
