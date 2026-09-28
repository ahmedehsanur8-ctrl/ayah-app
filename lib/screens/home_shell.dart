import 'package:flutter/material.dart';

import 'more_screen.dart';
import 'mood_screen.dart';
import 'stories_screen.dart';
import 'today_screen.dart';
import 'topics_screen.dart';

/// Bottom navigation: আজ, মন, বিষয়, জীবনী, আরও.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// The selected tab. Other screens can switch tabs by setting it.
  static final tab = ValueNotifier<int>(0);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _pages = [
    TodayScreen(),
    MoodScreen(),
    TopicsScreen(),
    StoriesScreen(),
    MoreScreen(),
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
            duration: const Duration(milliseconds: 220),
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
                icon: Icon(Icons.sentiment_satisfied_outlined),
                selectedIcon: Icon(Icons.sentiment_satisfied_outlined),
                label: 'মন',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_outlined),
                label: 'বিষয়',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories_outlined),
                label: 'জীবনী',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                selectedIcon: Icon(Icons.more_horiz_rounded),
                label: 'আরও',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
