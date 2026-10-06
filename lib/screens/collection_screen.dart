import 'package:flutter/material.dart';

import '../models/content.dart';
import '../theme.dart';
import '../widgets/category_style.dart';
import '../widgets/ui.dart';
import 'reader_screen.dart';

/// A mood or topic: "সব শুনুন", full surahs, then the ayahs and hadiths.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
    super.key,
    required this.styleId,
    required this.title,
    this.subtitle,
    required this.ayahs,
    required this.hadiths,
    this.surahs = const [],
  });

  /// Id used for the icon and colour (mood or topic id).
  final String styleId;
  final String title;
  final String? subtitle;
  final List<ContentItem> ayahs;
  final List<ContentItem> hadiths;
  final List<ContentItem> surahs;

  List<ContentItem> get _all => [...ayahs, ...hadiths];

  void _open(BuildContext context, List<ContentItem> list, int i, {bool play = false}) =>
      push(context, ReaderScreen(items: list, index: i, title: title, playAll: play));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = CategoryStyle.of(styleId);
    final tint = style.tintOf(p);
    final counts = [
      if (ayahs.isNotEmpty) '${toBanglaDigits(ayahs.length)}টি আয়াত',
      if (hadiths.isNotEmpty) '${toBanglaDigits(hadiths.length)}টি হাদিস',
    ].join(' · ');
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
        children: [
          Row(
            children: [
              IconBubble(style.icon, tint: tint, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle(p, size: 23)),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_all.isNotEmpty)
            Material(
              color: p.greenCard,
              borderRadius: BorderRadius.circular(radiusM),
              child: InkWell(
                borderRadius: BorderRadius.circular(radiusM),
                onTap: () => _open(context, _all, 0, play: true),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: p.gold, shape: BoxShape.circle),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Brand.greenDark,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'সব শুনুন',
                              style: TextStyle(
                                color: Brand.onNight,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              counts,
                              style: TextStyle(
                                color: Brand.onNight.withValues(alpha: 0.78),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (surahs.isNotEmpty) ...[
            const SectionLabel('পূর্ণ সূরা'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < surahs.length; i++)
                  ActionChip(
                    avatar: Icon(Icons.menu_book_outlined, size: 18, color: tint.foreground),
                    label: Text('সূরা ${surahs[i].surahName}'),
                    labelStyle: TextStyle(color: tint.foreground, fontWeight: FontWeight.w600),
                    backgroundColor: tint.background,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: () => _open(context, surahs, i),
                  ),
              ],
            ),
          ],
          if (ayahs.isNotEmpty) ...[
            SectionLabel(
              'আয়াত',
              trailing: Text(toBanglaDigits(ayahs.length), style: TextStyle(color: p.muted)),
            ),
            _ItemList(items: ayahs, onTap: (i) => _open(context, _all, i)),
          ],
          if (hadiths.isNotEmpty) ...[
            SectionLabel(
              'হাদিস',
              trailing: Text(toBanglaDigits(hadiths.length), style: TextStyle(color: p.muted)),
            ),
            _ItemList(items: hadiths, onTap: (i) => _open(context, _all, ayahs.length + i)),
          ],
          if (_all.isEmpty && surahs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'এখানে এখনো কিছু যোগ করা হয়নি।',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One short line per item: reference and the start of the Bangla meaning.
class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.onTap});

  final List<ContentItem> items;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.border),
            InkWell(
              onTap: () => onTap(i),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i].title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: p.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[i].banglaPlain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: p.text),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
