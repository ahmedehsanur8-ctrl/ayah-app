import 'package:flutter/material.dart';

import '../widgets/night.dart';

import 'dua_screens.dart';
import 'mood_screen.dart';
import 'quran_screen.dart';
import 'stories_screen.dart';
import 'today_screen.dart';

/// Bottom navigation: আজ, কুরআন, দোয়া, মন (with বিষয়), জীবনী.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// The selected tab. Other screens can switch tabs by setting it.
  static final tab = ValueNotifier<int>(0);

  static const today = 0;
  static const quran = 1;
  static const duas = 2;
  static const mood = 3;
  static const stories = 4;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _pages = [
    TodayScreen(),
    QuranScreen(),
    DuaHomeScreen(inTab: true),
    MoodScreen(),
    StoriesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: HomeShell.tab,
      builder: (context, tab, _) => PopScope(
        // Back from another tab goes to আজ first.
        canPop: tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) HomeShell.tab.value = 0;
        },
        child: Scaffold(
          body: AnimatedSwitcher(
            duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
            child: KeyedSubtree(key: ValueKey(tab), child: _pages[tab]),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => HomeShell.tab.value = i,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                selectedIcon: Icon(Icons.wb_sunny_outlined),
                label: 'আজ',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_outlined),
                label: 'কুরআন',
              ),
              NavigationDestination(
                icon: Icon(Icons.front_hand_outlined),
                selectedIcon: Icon(Icons.front_hand_outlined),
                label: 'দোয়া',
              ),
              NavigationDestination(
                icon: Icon(Icons.sentiment_satisfied_outlined),
                selectedIcon: Icon(Icons.sentiment_satisfied_outlined),
                label: 'মন',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories_outlined),
                label: 'জীবনী',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
