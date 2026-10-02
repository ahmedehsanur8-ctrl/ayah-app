// Screenshots of the main screens in light and dark mode, for reviewing the
// design. Off by default; to (re)make them:
//   SHOTS=1 flutter test test/screenshots_test.dart --update-goldens
// Pictures go to docs/redesign/<name>-light.png / -dark.png.
import 'dart:io';

import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/features/learn/ui/screens/learn_screens.dart';
import 'package:ayah_reminder/screens/arabic_screens.dart';
import 'package:ayah_reminder/screens/dua_screens.dart';
import 'package:ayah_reminder/screens/favorites_screen.dart';
import 'package:ayah_reminder/screens/home_shell.dart';
import 'package:ayah_reminder/screens/mood_screen.dart';
import 'package:ayah_reminder/screens/prayer_screen.dart';
import 'package:ayah_reminder/screens/qibla_screen.dart';
import 'package:ayah_reminder/screens/quran_reader_screen.dart';
import 'package:ayah_reminder/screens/quran_screen.dart';
import 'package:ayah_reminder/screens/search_screen.dart';
import 'package:ayah_reminder/screens/settings_screen.dart';
import 'package:ayah_reminder/screens/setup_screen.dart';
import 'package:ayah_reminder/screens/stories_screen.dart';
import 'package:ayah_reminder/screens/tasbih_screen.dart';
import 'package:flutter/material.dart';
import 'package:ayah_reminder/widgets/night.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';
import 'learn_test_helpers.dart';

final shots = <String, Widget Function()>{
  'components': () => const _Gallery(),
  'home': () => const HomeShell(),
  'prayer': () => const PrayerScreen(),
  'qibla': () => const QiblaScreen(),
  'quran': () => const QuranScreen(),
  'reader': () => const QuranReaderScreen(surah: 1),
  'duas': () => const DuaHomeScreen(),
  'tasbih': () => const TasbihScreen(),
  'learn': () => const LearnDashboardScreen(),
  'arabic': () => const ArabicHomeScreen(),
  'mood': () => const MoodScreen(),
  'stories': () => const StoriesScreen(),
  'search': () => const SearchScreen(),
  'saved': () => const FavoritesScreen(),
  'settings': () => const SettingsScreen(),
  'setup': () => const SetupScreen(),
};

void main() {
  final on = Platform.environment['SHOTS'] != null;
  final only = (Platform.environment['SHOTS'] ?? '')
      .split(',')
      .where((s) => s.isNotEmpty && s != '1');

  setUpAll(() async {
    if (!on) return;
    await setUpTestApp(icons: true);
    await AppState.instance.settings.setLocation(23.8103, 90.4125, 'ঢাকা', 'city');
  });

  for (final b in Brightness.values) {
    final mode = b == Brightness.dark ? 'dark' : 'light';
    for (final e in shots.entries) {
      if (only.isNotEmpty && !only.contains(e.key)) continue;
      testWidgets('${e.key} $mode', skip: !on, (t) async {
        t.view.devicePixelRatio = 2;
        t.view.physicalSize = const Size(780, 1688);
        t.view.padding = const FakeViewPadding(top: 48, bottom: 32);
        t.view.viewPadding = const FakeViewPadding(top: 48, bottom: 32);
        addTearDown(t.view.reset);
        HomeShell.tab.value = 0;
        await t.pumpWidget(themedApp(e.value(), b));
        await settleLearn(t, 12);
        await t.pump(const Duration(milliseconds: 600));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../docs/redesign/${e.key}-$mode.png'),
        );
      });
    }
  }
}

/// The shared Night & Gold components on one page.
class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          NightHeader(
            title: 'NightHeader',
            subtitle: 'নেভি, সোনালি গিরিহ নকশা, সাদা লেখা',
            actions: [
              NightIconButton(icon: Icons.search_rounded, tooltip: 'খুঁজুন', onPressed: () {}),
              NightIconButton(icon: Icons.settings_outlined, tooltip: 'সেটিংস', onPressed: () {}),
            ],
            lip: true,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const StarBadge('১১৪', onNight: true),
                const StarBadge('৭', onNight: true, size: 48),
                GoldButton(label: 'চালিয়ে যান', icon: Icons.play_arrow_rounded, onPressed: () {}),
                NightPill(icon: Icons.location_on_outlined, text: 'ঢাকা', onTap: () {}),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('শুনুন'),
                    ),
                    OutlinedButton(onPressed: () {}, child: const Text('পরে')),
                    const StarBadge('২৫৫'),
                    const OctagramIcon(size: 24),
                  ],
                ),
                const SizedBox(height: 16),
                ListSection(
                  children: [
                    ListRow(
                      icon: Icons.menu_book_outlined,
                      title: 'কুরআন',
                      subtitle: '১১৪টি সূরা',
                      onTap: () {},
                    ),
                    ListRow(
                      icon: Icons.explore_outlined,
                      title: 'কিবলা',
                      subtitle: 'দিক দেখুন',
                      onTap: () {},
                    ),
                    ListRow(
                      leading: const StarBadge('১'),
                      title: 'আল-ফাতিহা',
                      subtitle: 'সূচনা · ৭ আয়াত · মাক্কী',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), label: 'আজ'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'কুরআন'),
          NavigationDestination(icon: Icon(Icons.front_hand_outlined), label: 'দোয়া'),
          NavigationDestination(icon: Icon(Icons.sentiment_satisfied_outlined), label: 'মন'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'জীবনী'),
        ],
      ),
    );
  }
}
