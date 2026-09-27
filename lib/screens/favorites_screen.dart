import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/pattern.dart';
import 'categories_screen.dart';

/// Ayahs and hadiths the user saved with the heart button.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('প্রিয় তালিকা')),
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) {
          final items = state.settings.favorites.map(state.data.byId).nonNulls.toList();
          if (items.isEmpty) return const _Empty();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => ItemListCard(items[i], showCategory: true),
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
                        color: p.surfaceSoft,
                        child: Stack(
                          children: [PatternLayer(color: p.pattern, opacity: 0.12, cell: 34)],
                        ),
                      ),
                    ),
                  ),
                  const Icon(Icons.favorite_rounded, size: 52, color: Color(0xFFE0506B)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('এখনো কিছু রাখা হয়নি', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'যে আয়াত বা হাদিস মনে ধরে, তার পাশের ♡ চিহ্নে চাপ দিন। সেটি এখানে জমা থাকবে।',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
