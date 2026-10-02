import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/pattern.dart';
import '../widgets/ui.dart';
import 'dua_screens.dart';
import 'quran_bookmarks_screen.dart';
import 'reader_screen.dart';

/// প্রিয়: everything saved, in one place. Three tabs: ayahs and hadiths saved
/// with the heart button, saved duas, and Quran bookmarks.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, this.initialTab = 0});

  /// 0 = আয়াত ও হাদিস, 1 = দোয়া, 2 = কুরআন বুকমার্ক.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('প্রিয়'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'আয়াত ও হাদিস'),
              Tab(text: 'দোয়া'),
              Tab(text: 'বুকমার্ক'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([state.settings, state.settings.quran]),
          builder: (context, _) => TabBarView(
            children: [
              const _ItemsTab(),
              favoriteDuas().isEmpty
                  ? const _Empty(
                      'এখনো কোনো দোয়া রাখা হয়নি',
                      'দোয়ার পাতায় ‘প্রিয়’ বোতামে চাপ দিলে দোয়াটি এখানে জমা থাকবে।',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: const [DuaFavoriteList()],
                    ),
              state.settings.quran.bookmarks.isEmpty
                  ? const _Empty(
                      'এখনো কোনো বুকমার্ক নেই',
                      'কুরআন পড়ার সময় আয়াতের পাশের বুকমার্ক চিহ্নে চাপ দিলে সেটি এখানে জমা থাকবে।',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: const [QuranBookmarkList()],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemsTab extends StatelessWidget {
  const _ItemsTab();

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final p = context.palette;
    final items = state.settings.favorites.map(state.data.byId).nonNulls.toList();
    if (items.isEmpty) {
      return const _Empty(
        'এখনো কিছু রাখা হয়নি',
        'যে আয়াত বা হাদিস মনে ধরে, তার পাশের হৃদয় চিহ্নে চাপ দিন। সেটি এখানে জমা থাকবে।',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.border),
                InkWell(
                  onTap: () => push(context, ReaderScreen(items: items, index: i, title: 'প্রিয়')),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${items[i].isAyah ? 'আয়াত' : 'হাদিস'} · ${items[i].title}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: p.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  items[i].banglaPlain,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, color: p.text, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'প্রিয় থেকে সরান',
                            onPressed: () => state.settings.toggleFavorite(items[i].id),
                            icon: Icon(Icons.favorite_rounded, color: p.rose.foreground),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.text);

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 140,
                      child: ColoredBox(
                        color: p.rose.background,
                        child: Stack(
                          children: [
                            PatternLayer(color: p.rose.foreground, opacity: 0.10, cell: 34),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.favorite_border_rounded, size: 52, color: p.rose.foreground),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(title, style: titleStyle(p, size: 20), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
