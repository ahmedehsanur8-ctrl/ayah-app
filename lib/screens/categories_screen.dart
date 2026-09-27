import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';
import '../widgets/item_view.dart';
import 'reading_screen.dart';

/// Browse the 20 ayah categories and the hadith themes.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppState.instance.data;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('বিষয়সমূহ'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.gold,
            labelStyle: TextStyle(
              fontFamily: banglaFont,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            tabs: [
              Tab(text: 'আয়াতের বিষয়'),
              Tab(text: 'হাদিসের বিষয়'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CategoryList(categories: data.ayahCategories, data: data),
            _CategoryList(categories: data.nonEmpty(data.hadithThemes), data: data),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.data});

  final List<Category> categories;
  final ContentData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = categories[i];
        final count = data.itemsIn(c.id).length;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.green,
              child: Text(
                toBanglaDigits(i + 1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [if (c.nameEn.isNotEmpty) c.nameEn, '${toBanglaDigits(count)}টি'].join(' · '),
              style: const TextStyle(color: AppColors.muted),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.green),
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => CategoryItemsScreen(category: c))),
          ),
        );
      },
    );
  }
}

class CategoryItemsScreen extends StatelessWidget {
  const CategoryItemsScreen({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final items = AppState.instance.data.itemsIn(category.id);
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ReadingScreen(item: item))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BanglaText(item.title, size: 14, color: AppColors.green),
                    const SizedBox(height: 8),
                    ArabicText(item.arabic, size: 21, maxLines: 3),
                    const SizedBox(height: 6),
                    BanglaText(item.bangla, size: 15, maxLines: 3),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
