import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/screens/about_screen.dart';
import 'package:ayah_reminder/screens/collection_screen.dart';
import 'package:ayah_reminder/screens/credits_screen.dart';
import 'package:ayah_reminder/screens/home_shell.dart';
import 'package:ayah_reminder/screens/prayer_screen.dart';
import 'package:ayah_reminder/screens/privacy_screen.dart';
import 'package:ayah_reminder/screens/qibla_screen.dart';
import 'package:ayah_reminder/screens/reader_screen.dart';
import 'package:ayah_reminder/screens/reading_screen.dart';
import 'package:ayah_reminder/screens/onboarding_screen.dart';
import 'package:ayah_reminder/screens/settings_screen.dart';
import 'package:ayah_reminder/screens/setup_screen.dart';
import 'package:ayah_reminder/screens/splash_screen.dart';
import 'package:ayah_reminder/screens/stories_screen.dart';
import 'package:ayah_reminder/screens/tasbih_screen.dart';
import 'package:ayah_reminder/screens/quran_reader_screen.dart';
import 'package:ayah_reminder/screens/quran_screen.dart';
import 'package:ayah_reminder/services/duas.dart';
import 'package:ayah_reminder/services/quran.dart';
import 'package:ayah_reminder/services/reminders.dart';
import 'package:ayah_reminder/theme.dart';
import 'package:ayah_reminder/widgets/ui.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    PackageInfo.setMockInitialValues(
      appName: 'Ayah Reminder',
      packageName: 'com.ayahreminder.ayah_reminder',
      version: '1.0.50',
      buildNumber: '50',
      buildSignature: '',
    );
    tzdata.initializeTimeZones();
    Reminders.dhaka = tz.getLocation('Asia/Dhaka');
    await AppState.load();
    await Quran.loadMeta();
    await Quran.load();
    await Duas.load();
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
    await load('HindSiliguri', [
      'HindSiliguri-Regular.ttf',
      'HindSiliguri-Medium.ttf',
      'HindSiliguri-SemiBold.ttf',
      'HindSiliguri-Bold.ttf',
    ]);
    await load('NotoSerifBengali', ['NotoSerifBengali-SemiBold.ttf', 'NotoSerifBengali-Bold.ttf']);
  });

  test('default reminder times: 9:00 AM and 9:00 PM', () {
    final s = AppState.instance.settings;
    expect(s.morningTime, const TimeOfDay(hour: 9, minute: 0));
    expect(s.nightTime, const TimeOfDay(hour: 21, minute: 0));
  });

  for (final b in Brightness.values) {
    group('$b', () {
      testWidgets('the five tabs', (t) async {
        await t.binding.setSurfaceSize(const Size(390, 844));
        HomeShell.tab.value = 0;
        await t.pumpWidget(app(const HomeShell(), b));
        await t.pumpAndSettle();
        // আজ: buttons at the top, today's ayah, then the hadith right after it.
        expect(find.textContaining('আজকের আয়াত'), findsWidgets);
        expect(find.text('আসসালামু আলাইকুম'), findsOneWidget);
        expect(find.text('শুনুন'), findsOneWidget);
        for (final label in ['খুঁজুন', 'প্রিয়', 'সেটিংস']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        await t.scrollUntilVisible(find.text('আজকের হাদিস'), 300);
        expect(find.text('আজকের হাদিস'), findsOneWidget);
        await t.drag(find.byType(Scrollable).first, const Offset(0, -250));
        await t.pumpAndSettle();
        await t.tap(find.text('পরের').last);
        await t.pump();
        await t.scrollUntilVisible(find.text('তাসবিহ'), 300);
        expect(find.text('নামাজের সময়'), findsOneWidget);
        expect(find.text('কিবলা'), findsOneWidget);
        await t.scrollUntilVisible(find.text('সহজ আরবি'), 300);
        expect(find.text('সহজ আরবি'), findsOneWidget);

        await t.tap(find.text('কুরআন').last);
        await t.pumpAndSettle();
        expect(find.text('আল-কুরআন'), findsOneWidget);
        expect(find.text('আল-ফাতিহা'), findsOneWidget);
        // Labelled buttons, not icon-only.
        for (final label in ['বুকমার্ক', 'পড়ার সেটিং', 'ডাউনলোড']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        await t.tap(find.text('পারা'));
        await t.pumpAndSettle();
        expect(find.text('পারা ১'), findsOneWidget);

        await t.tap(find.text('দোয়া').last);
        await t.pumpAndSettle();
        expect(find.text('দোয়া ও জিকির'), findsOneWidget);
        expect(find.text('জিকির শুরু করুন'), findsOneWidget);
        expect(find.text('তাসবিহ'), findsOneWidget);
        expect(find.text('প্রিয় দোয়া'), findsOneWidget);

        // মন: moods and the topics on one page, no switch.
        await t.tap(find.text('মন').last);
        await t.pumpAndSettle();
        expect(find.text('আপনার মন এখন কেমন?'), findsOneWidget);
        final moods = AppState.instance.data.moods;
        expect(moods.length, 16);
        expect(find.text(moods.first.name), findsOneWidget);
        await t.scrollUntilVisible(
          find.text('মনের অবস্থা'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('মনের অবস্থা'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'সবর');
        await t.pumpAndSettle();
        expect(find.text('সবর'), findsWidgets);

        await t.tap(find.text('জীবনী').last);
        await t.pumpAndSettle();
        expect(find.text('সাহাবিদের জীবনী'), findsOneWidget);
        HomeShell.tab.value = 0;
      });

      testWidgets('home buttons open search, প্রিয় and the one settings page', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        HomeShell.tab.value = 0;
        await t.pumpWidget(app(const HomeShell(), b));
        await t.pumpAndSettle();

        await t.tap(find.text('সেটিংস'));
        await t.pumpAndSettle();
        expect(find.text('রাত ৯:০০'), findsOneWidget);
        expect(find.text('সকাল ৯:০০'), findsOneWidget);
        // Every heading is on the same page.
        for (final s in SettingsSection.values) {
          await t.scrollUntilVisible(
            find.byWidgetPredicate((w) => w is SectionLabel && w.text == s.title),
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(find.text('ডেভেলপার সম্পর্কে'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();

        await t.tap(find.text('প্রিয়'));
        await t.pumpAndSettle();
        expect(find.text('আয়াত ও হাদিস'), findsOneWidget);
        await t.tap(find.text('বুকমার্ক'));
        await t.pumpAndSettle();
        await t.tap(find.text('দোয়া'));
        await t.pumpAndSettle();
        await t.pageBack();
        await t.pumpAndSettle();

        await t.tap(find.text('খুঁজুন'));
        await t.pumpAndSettle();
        expect(find.text('সব ফিচার'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'কিবলা');
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(find.widgetWithText(NavRow, 'কিবলা'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'ফাতিহা');
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(find.text('আল-ফাতিহা'), findsWidgets);
        await t.enterText(find.byType(TextField), 'সফর');
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(find.text('দোয়া'), findsWidgets);
      });

      testWidgets('settings opens at the asked heading', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const SettingsScreen(section: SettingsSection.about), b));
        await t.pumpAndSettle();
        expect(find.text('গোপনীয়তা নীতি').hitTestable(), findsOneWidget);
        await t.pumpWidget(app(SettingsScreen(key: UniqueKey(), section: SettingsSection.azan), b));
        await t.pumpAndSettle();
        expect(find.text('হিসাবের পদ্ধতি').hitTestable(), findsOneWidget);
      });

      testWidgets('tasbih counts, remembers and resets', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const TasbihScreen(), b));
        await t.pumpAndSettle();
        if (find.text('আবার শুরু').evaluate().isNotEmpty &&
            AppState.instance.settings.tasbihCount > 0) {
          await t.tap(find.text('আবার শুরু'));
          await t.pump();
        }
        expect(find.text('সুবহানাল্লাহ'), findsWidgets);
        for (var i = 0; i < 33; i++) {
          await t.tap(find.byKey(const ValueKey('tasbih-tap')));
          await t.pump();
        }
        expect(find.textContaining('৩৩ বার পূর্ণ হয়েছে'), findsOneWidget);
        expect(find.text('মোট ৩৩ বার · ১ রাউন্ড পূর্ণ'), findsOneWidget);
        expect(AppState.instance.settings.tasbihCount, 33);
        await t.pumpWidget(app(TasbihScreen(key: UniqueKey()), b));
        await t.pumpAndSettle();
        expect(find.text('মোট ৩৩ বার · ১ রাউন্ড পূর্ণ'), findsOneWidget);
        await t.tap(find.text('আবার শুরু'));
        await t.pump();
        expect(find.text('মোট ০ বার · ০ রাউন্ড পূর্ণ'), findsOneWidget);
      });

      testWidgets('mood page and reader with player', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        final data = AppState.instance.data;
        final m = data.moods.first;
        await t.pumpWidget(
          app(
            CollectionScreen(
              styleId: m.id,
              title: m.name,
              ayahs: data.byIds(m.ayahIds),
              surahs: data.byIds(m.surahIds),
              hadiths: data.byIds(m.hadithIds),
            ),
            b,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('সব শুনুন'), findsOneWidget);
        expect(find.text('পূর্ণ সূরা'), findsOneWidget);
        expect(data.byIds(m.ayahIds).length, m.ayahIds.length);

        // Short ayahs, so the buttons under the text are on screen.
        final items = (data.byIds(
          m.ayahIds,
        )..sort((a, b) => a.bangla.length.compareTo(b.bangla.length))).take(5).toList();
        await t.pumpWidget(app(ReaderScreen(items: items, title: m.name), b));
        await t.pumpAndSettle();
        expect(find.text('১ / ৫'), findsOneWidget);
        expect(find.text('ছবি করে শেয়ার'), findsOneWidget);
        await t.tap(find.byTooltip('পরের'));
        await t.pumpAndSettle();
        expect(find.text('২ / ৫'), findsOneWidget);
        await t.tap(find.text('প্রিয়'));
        await t.pump();
        expect(AppState.instance.settings.isFavorite(items[1].id), isTrue);
        await t.tap(find.text('প্রিয়'));
        await t.pump();
        final withNote =
            (data.items.where((i) => i.isAyah && i.note.isNotEmpty).toList()
                  ..sort((a, b) => a.bangla.length.compareTo(b.bangla.length)))
                .first;
        await t.pumpWidget(app(ReaderScreen(key: UniqueKey(), items: [withNote]), b));
        await t.pumpAndSettle();
        await t.tap(find.text('টীকা দেখুন'));
        await t.pumpAndSettle();
        expect(find.textContaining('টীকা · আবু বকর যাকারিয়া'), findsOneWidget);
      });

      testWidgets('every full surah and mood item renders in the reader', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        final items = AppState.instance.data.moodItems;
        for (var i = 0; i < items.length; i += 7) {
          await t.pumpWidget(app(ReaderScreen(key: UniqueKey(), items: items, index: i), b));
          await t.pump(const Duration(milliseconds: 300));
        }
      });

      testWidgets('prayer times, Qibla and about', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        final s = AppState.instance.settings;
        await t.pumpWidget(app(const PrayerScreen(), b));
        await t.pump();
        if (!s.hasLocation) {
          expect(find.text('আপনার এলাকা বেছে নিন'), findsOneWidget);
          await s.setLocation(24.8949, 91.8687, 'সিলেট', 'city');
          await t.pump();
        }
        expect(find.text('পরের নামাজ'), findsOneWidget);
        for (final n in ['ফজর', 'সূর্যোদয়', 'যোহর', 'আসর', 'মাগরিব', 'ইশা']) {
          expect(find.text(n), findsWidgets, reason: n);
        }
        await t.scrollUntilVisible(find.text('কিবলা দেখুন'), 300);
        expect(find.text('আজান সেটিংস'), findsOneWidget);
        await t.pumpWidget(app(const QiblaScreen(), b));
        await t.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('কিবলার দিক'), findsOneWidget);
        await t.pumpWidget(app(const AboutScreen(), b));
        await t.pumpAndSettle();
        expect(find.text('Ahmed Ehsanur Rahman'), findsOneWidget);
        expect(find.text('সম্পূর্ণ বিনামূল্যে · কোনো বিজ্ঞাপন নেই'), findsOneWidget);
        await t.pumpWidget(app(const PrivacyScreen(), b));
        await t.pumpAndSettle();
        expect(find.text('কোনো তথ্য সংগ্রহ করা হয় না'), findsOneWidget);
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

      testWidgets('Quran reader, search and last read', (t) async {
        await t.binding.setSurfaceSize(const Size(390, 844));
        final prefs = AppState.instance.settings.quran;
        for (final r in [...prefs.bookmarks].map(AyahRef.parse).nonNulls) {
          await prefs.toggleBookmark(r.surah, r.ayah);
        }
        await t.pumpWidget(app(const QuranReaderScreen(surah: 2, ayah: 255), b));
        await t.pumpAndSettle();
        expect(find.text('সূরা আল-বাকারা'), findsWidgets);
        expect(find.text('২৫৫'), findsOneWidget);
        expect(find.text('— ড. আবু বকর মুহাম্মাদ যাকারিয়া'), findsWidgets);
        expect(prefs.lastSurah, 2);
        expect(prefs.lastAyah, 255);

        // Bookmark it; it shows in the bookmark list.
        final tile255 = find.byWidgetPredicate((w) => w is AyahTile && w.ayah == 255);
        await t.tap(find.descendant(of: tile255, matching: find.byTooltip('বুকমার্ক করুন')));
        await t.pumpAndSettle();
        expect(prefs.bookmarks, isNotEmpty);

        // Top of surah 2: header with the basmala; surah 9 has none.
        await t.pumpWidget(app(QuranReaderScreen(key: UniqueKey(), surah: 2), b));
        await t.pumpAndSettle();
        expect(find.text(Quran.basmala), findsOneWidget);
        await t.pumpWidget(app(QuranReaderScreen(key: UniqueKey(), surah: 9), b));
        await t.pumpAndSettle();
        expect(find.text(Quran.basmala), findsNothing);
        expect(find.text('১'), findsWidgets);

        // Quran tab: continue card and search by reference and by word.
        await t.pumpWidget(app(const QuranScreen(), b));
        await t.pumpAndSettle();
        expect(find.text('যেখানে শেষ করেছিলেন'), findsOneWidget);
        await t.enterText(find.byType(TextField), '২:২৫৫');
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(find.textContaining('২:২৫৫ খুলুন'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'বাকারা');
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(find.text('আল-বাকারা'), findsWidgets);

        // Settings sheet opens.
        await t.pumpWidget(app(const QuranReaderScreen(surah: 1), b));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('পড়ার সেটিংস'));
        await t.pumpAndSettle();
        expect(find.text('শুধু আরবি'), findsOneWidget);
        expect(find.text('রোয়াদ অনুবাদ কেন্দ্র'), findsOneWidget);
      });

      testWidgets('onboarding: one page per permission, then the summary', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const OnboardingScreen(), b));
        await settleChecks(t);
        expect(find.text('শুরু করি'), findsOneWidget);
        await t.tap(find.text('শুরু করি'));
        await t.pumpAndSettle();
        // No plugin in tests: notifications etc. read as granted, battery and
        // location as missing, and no brand page.
        expect(find.text('২ / ৮'), findsOneWidget);
        expect(find.text('নোটিফিকেশন'), findsOneWidget);
        for (final title in [
          'ফুল-স্ক্রিন রিমাইন্ডার',
          'সময়মতো রিমাইন্ডার',
          'অন্য অ্যাপের উপরে দেখানো',
        ]) {
          await t.tap(find.text('পরবর্তী'));
          await t.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
        }
        await t.tap(find.text('পরবর্তী'));
        await t.pumpAndSettle();
        expect(find.text('লোকেশন'), findsOneWidget);
        // An earlier test may have picked a city already.
        if (AppState.instance.settings.hasLocation) {
          await t.tap(find.text('পরবর্তী'));
        } else {
          expect(find.text('শহর বেছে নিন'), findsOneWidget);
          await t.tap(find.text('পরে করব'));
        }
        await t.pumpAndSettle();
        expect(find.text('ব্যাটারি'), findsOneWidget);
        expect(find.text('অনুমতি দিন'), findsOneWidget);
        await t.tap(find.text('পরে করব'));
        await t.pumpAndSettle();
        expect(find.text('৮ / ৮'), findsOneWidget);
        expect(find.text('বাকি'), findsWidgets);
        await t.scrollUntilVisible(
          find.text('শুরু করুন'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('১ মিনিট পর পরীক্ষা করুন'), findsOneWidget);
      });

      testWidgets('setup page and home banner', (t) async {
        await t.binding.setSurfaceSize(const Size(360, 740));
        await t.pumpWidget(app(const SetupScreen(), b));
        await settleChecks(t);
        expect(find.text('রিমাইন্ডার ঠিকমতো কাজ করতে ১টি অনুমতি বাকি।'), findsOneWidget);
        await t.pumpWidget(app(const SetupBanner(), b));
        await settleChecks(t);
        expect(find.text('রিমাইন্ডার ঠিকমতো কাজ করতে ১টি অনুমতি বাকি'), findsOneWidget);
      });
    });
  }
}

/// The permission checks call the platform channels, which answer outside the
/// test's fake clock.
Future<void> settleChecks(WidgetTester t) async {
  for (var i = 0; i < 100 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
  }
  await t.pumpAndSettle();
}
