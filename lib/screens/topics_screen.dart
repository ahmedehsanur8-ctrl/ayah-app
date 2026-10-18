import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../models/topics.dart';
import '../theme.dart';
import '../widgets/category_style.dart';
import '../widgets/night.dart';
import '../widgets/ui.dart';
import 'collection_screen.dart';
import 'reader_screen.dart';

/// বিষয় as its own page (from search).
class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('বিষয়')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: const [TopicsSection()],
    ),
  );
}

/// বিষয়: search, then all topics in three groups. Each topic shows its
/// ayahs and hadiths together. Sits inside a scrolling page (the মন tab).
class TopicsSection extends StatefulWidget {
  const TopicsSection({super.key});

  @override
  State<TopicsSection> createState() => _TopicsSectionState();
}

class _TopicsSectionState extends State<TopicsSection> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openTopic(Topic t) {
    final data = AppState.instance.data;
    final items = t.items(data);
    push(
      context,
      CollectionScreen(
        styleId: t.id,
        title: t.name,
        ayahs: items.where((i) => i.isAyah).toList(),
        hadiths: items.where((i) => !i.isAyah).toList(),
      ),
    );
  }

  String _counts(List<ContentItem> items) {
    final a = items.where((i) => i.isAyah).length;
    final h = items.length - a;
    return [
      if (a > 0) '${toBanglaDigits(a)} আয়াত',
      if (h > 0) '${toBanglaDigits(h)} হাদিস',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final data = AppState.instance.data;
    final q = _q.trim();
    final matchingTopics = [
      for (final g in topicGroups)
        for (final t in g.topics)
          if (q.isNotEmpty && t.name.contains(q)) t,
    ];
    final matchingItems = q.length < 2
        ? const <ContentItem>[]
        : [...data.items, ...data.moodItems]
              .where(
                (i) =>
                    i.banglaPlain.contains(q) ||
                    i.title.contains(q) ||
                    i.reference.toLowerCase().contains(q.toLowerCase()),
              )
              .take(40)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _q = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'বিষয় বা শব্দ খুঁজুন',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    tooltip: 'মুছুন',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _search.clear();
                      _q = '';
                    }),
                  ),
          ),
        ),
        if (q.isNotEmpty) ...[
          if (matchingTopics.isNotEmpty) ...[
            const SectionLabel('বিষয়'),
            _Grid(topics: matchingTopics, counts: (t) => _counts(t.items(data)), onTap: _openTopic),
          ],
          if (matchingItems.isNotEmpty) ...[
            const SectionLabel('আয়াত ও হাদিস'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < matchingItems.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    ListTile(
                      minTileHeight: 56,
                      title: Text(
                        matchingItems[i].title,
                        style: TextStyle(
                          fontSize: 14,
                          color: p.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        matchingItems[i].banglaPlain,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => push(
                        context,
                        ReaderScreen(items: matchingItems, index: i, title: 'খোঁজার ফল'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (matchingTopics.isEmpty && matchingItems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                'কিছু পাওয়া যায়নি',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted),
              ),
            ),
        ] else
          for (final g in topicGroups) ...[
            SectionLabel(g.name),
            _Grid(
              topics: g.topics.where((t) => t.items(data).isNotEmpty).toList(),
              counts: (t) => _counts(t.items(data)),
              onTap: _openTopic,
            ),
          ],
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.topics, required this.counts, required this.onTap});

  final List<Topic> topics;
  final String Function(Topic) counts;
  final void Function(Topic) onTap;

  @override
  Widget build(BuildContext context) {
    // Clean rows with dividers (no grid of tinted tiles).
    return ListSection(
      children: [
        for (final t in topics)
          ListRow(
            icon: CategoryStyle.of(t.id).icon,
            title: t.name,
            subtitle: counts(t),
            onTap: () => onTap(t),
          ),
      ],
    );
  }
}
