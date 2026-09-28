import 'package:flutter/material.dart';

import 'more_screen.dart';
import 'mood_screen.dart';
import 'quran_screen.dart';
import 'stories_screen.dart';
import 'today_screen.dart';
import 'topics_screen.dart';

/// Bottom navigation: আজ, কুরআন, মন (with বিষয়), জীবনী, আরও.
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
    QuranScreen(),
    MoodTopicsScreen(),
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
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: 'কুরআন',
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

/// মন tab: a "মন | বিষয়" switch at the top, then the moods or the topics.
class MoodTopicsScreen extends StatelessWidget {
  const MoodTopicsScreen({super.key});

  /// 0 = মন, 1 = বিষয়. Other screens can switch it.
  static final section = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: section,
      builder: (context, i, _) => Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.sentiment_satisfied_outlined),
                        label: Text('মন'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.grid_view_outlined),
                        label: Text('বিষয়'),
                      ),
                    ],
                    selected: {i},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => section.value = v.first,
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: i == 0 ? const MoodScreen() : const TopicsScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
