import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';
import '../widgets/category_style.dart';
import '../widgets/item_view.dart';
import '../widgets/pattern.dart';
import 'reading_screen.dart';

/// Browse the 20 ayah categories and the hadith themes as a colourful grid.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _hadith = false;

  @override
  Widget build(BuildContext context) {
    final data = AppState.instance.data;
    final cats = _hadith ? data.nonEmpty(data.hadithThemes) : data.ayahCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('বিষয়সমূহ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: _Segmented(value: _hadith, onChanged: (v) => setState(() => _hadith = v)),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: GridView.builder(
                key: ValueKey(_hadith),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.98,
                ),
                itemCount: cats.length,
                itemBuilder: (context, i) => _CategoryTile(
                  category: cats[i],
                  count: data.itemsIn(cats[i].id).length,
                  hadith: _hadith,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget seg(String label, IconData icon, bool v) {
      final selected = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? p.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? (p.isDark ? Brand.night : Colors.white) : p.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    color: selected ? (p.isDark ? Brand.night : Colors.white) : p.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          seg('আয়াতের বিষয়', Icons.menu_book_rounded, false),
          seg('হাদিসের বিষয়', Icons.format_quote_rounded, true),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count, required this.hadith});

  final Category category;
  final int count;
  final bool hadith;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = CategoryStyle.of(category.id);
    final fg = style.foreground(p);
    return Material(
      color: style.background(p),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => CategoryItemsScreen(category: category))),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              bottom: -24,
              width: 110,
              height: 110,
              child: Stack(children: [PatternLayer(color: fg, opacity: 0.16, cell: 36)]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: style.bubble(p),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(style.icon, color: fg, size: 25),
                  ),
                  const Spacer(),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.35,
                      color: p.isDark
                          ? p.text
                          : HSLColor.fromColor(fg).withLightness(0.2).toColor(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${toBanglaDigits(count)}টি ${hadith ? 'হাদিস' : 'আয়াত'}',
                    style: TextStyle(
                      fontFamily: headingFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryItemsScreen extends StatelessWidget {
  const CategoryItemsScreen({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = CategoryStyle.of(category.id);
    final items = AppState.instance.data.itemsIn(category.id);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 170,
            backgroundColor: style.background(p),
            foregroundColor: p.isDark ? p.text : style.foreground(p),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 16),
              title: Text(
                category.name,
                style: TextStyle(
                  fontFamily: headingFont,
                  fontWeight: FontWeight.w700,
                  color: p.isDark ? p.text : style.foreground(p),
                ),
              ),
              background: Stack(
                children: [
                  PatternLayer(color: style.foreground(p), opacity: 0.12, cell: 44),
                  Positioned(
                    right: 22,
                    bottom: 40,
                    child: Icon(
                      style.icon,
                      size: 70,
                      color: style.foreground(p).withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => ItemListCard(items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact card used in lists (category items, favourites).
class ItemListCard extends StatelessWidget {
  const ItemListCard(this.item, {super.key, this.showCategory = false});

  final ContentItem item;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ReadingScreen(item: item))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: showCategory
                        ? Align(alignment: Alignment.centerLeft, child: CategoryChip(item))
                        : BanglaText(
                            item.title,
                            size: 14,
                            color: p.primary,
                            weight: FontWeight.w700,
                          ),
                  ),
                  FavoriteButton(item),
                  ShareButton(item),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    ArabicText(item.arabic, size: 21, maxLines: 3),
                    const SizedBox(height: 6),
                    BanglaText(item.bangla, size: 15, maxLines: 3),
                    if (showCategory) ...[
                      const SizedBox(height: 6),
                      BanglaText(item.title, size: 13, color: p.primary, weight: FontWeight.w700),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
