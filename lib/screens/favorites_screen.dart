import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/pattern.dart';
import '../widgets/ui.dart';
import 'dua_screens.dart';
import 'quran_bookmarks_screen.dart';
import 'reader_screen.dart';

/// Quran bookmarks, and the ayahs and hadiths saved with the heart button.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('প্রিয়')),
      body: ListenableBuilder(
        listenable: Listenable.merge([state.settings, state.settings.quran]),
        builder: (context, _) {
          final items = state.settings.favorites.map(state.data.byId).nonNulls.toList();
          final bookmarks = state.settings.quran.bookmarks.isNotEmpty;
          final duas = favoriteDuas().isNotEmpty;
          if (items.isEmpty && !bookmarks && !duas) return const _Empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (duas) ...[const SectionLabel('প্রিয় দোয়া'), const DuaFavoriteList()],
              if (bookmarks) ...[const SectionLabel('কুরআন বুকমার্ক'), const QuranBookmarkList()],
              if (items.isNotEmpty && (bookmarks || duas))
                const SectionLabel('প্রিয় আয়াত ও হাদিস'),
              if (items.isNotEmpty)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: p.border),
                        InkWell(
                          onTap: () =>
                              push(context, ReaderScreen(items: items, index: i, title: 'প্রিয়')),
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
                                            fontSize: 13,
                                            color: p.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          items[i].banglaPlain,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: p.text,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'প্রিয় থেকে সরান',
                                    onPressed: () => state.settings.toggleFavorite(items[i].id),
                                    icon: const Icon(
                                      Icons.favorite_rounded,
                                      color: Color(0xFFD6455F),
                                    ),
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
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
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
            Text('এখনো কিছু রাখা হয়নি', style: titleStyle(p, size: 20)),
            const SizedBox(height: 8),
            Text(
              'যে আয়াত বা হাদিস মনে ধরে, তার পাশের হৃদয় চিহ্নে চাপ দিন; কুরআনের আয়াতে বুকমার্ক চিহ্নে। সেটি এখানে জমা থাকবে।',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
