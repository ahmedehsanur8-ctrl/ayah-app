import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../models/content.dart';
import '../../../../theme.dart';
import '../../domain/models.dart';
import '../../state/learn_controller.dart';
import 'learn_widgets.dart';

/// Opens the word sheet for [word]. [lemmaId] picks a part of the word (a prefix
/// or pronoun); by default the main word.
Future<void> showWordSheet(BuildContext context, QuranWord word, {int? lemmaId}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WordSheet(word: word, lemmaId: lemmaId),
    );

class WordSheet extends StatefulWidget {
  const WordSheet({super.key, required this.word, this.lemmaId});

  final QuranWord word;
  final int? lemmaId;

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  final learn = Learn.instance;
  Map<int, Lemma> _lemmas = const {};
  int? _selected;
  bool _showRoot = false;
  ({String meaning, bool draft})? _rootIdea;
  List<(Lemma, QuranWord?)> _related = const [];

  QuranWord get w => widget.word;

  @override
  void initState() {
    super.initState();
    _selected = widget.lemmaId ?? w.lemmaId ?? w.allLemmas.firstOrNull;
    _load();
  }

  Future<void> _load() async {
    final lemmas = await learn.content!.lemmas(w.allLemmas);
    if (mounted) setState(() => _lemmas = lemmas);
  }

  Future<void> _loadRoot(Lemma l) async {
    final c = learn.content!;
    final idea = await c.rootIdea(l.root!);
    final same = await c.sameRoot(l.root!, l.id);
    final words = await c.wordsById(same.map((x) => x.displayWordId));
    if (!mounted) return;
    setState(() {
      _rootIdea = idea;
      _related = [for (final x in same) (x, words[x.displayWordId])];
    });
  }

  Future<void> _report(Lemma? l) async {
    await learn.countErrorReport();
    final text = [
      'কুরআন বুঝি: ভুল জানাচ্ছি',
      'শব্দ: ${w.text} (আয়াত ${w.surah}:${w.ayah}, শব্দ ${w.index})',
      if (l != null) 'অর্থ${l.isDraft ? ' (খসড়া)' : ''}: ${l.meaning ?? '—'}',
      if (l != null) 'নম্বর: ${l.id}',
      'কী ভুল মনে হচ্ছে: ',
    ].join('\n');
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = _selected == null ? null : _lemmas[_selected];
    final parts = [
      for (final s in w.segments)
        if (s.lemmaId != null && _lemmas[s.lemmaId]?.meaning != null) s,
    ];
    return ListenableBuilder(
      listenable: learn,
      builder: (context, _) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              ArabicWord(w, size: 42, highlight: _selected == null ? null : w.spanOf(_selected!)),
              Text(
                'আয়াত ${toBanglaDigits(w.surah)}:${toBanglaDigits(w.ayah)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 14),
              ),
              if (parts.length > 1) ...[
                const SizedBox(height: 10),
                Text('এই শব্দের অংশ', style: TextStyle(color: p.muted, fontSize: 14)),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in parts)
                        ChoiceChip(
                          selected: s.lemmaId == _selected,
                          onSelected: (_) => setState(() {
                            _selected = s.lemmaId;
                            _showRoot = false;
                          }),
                          label: Text(
                            w.partFor(s.lemmaId!),
                            style: const TextStyle(fontFamily: arabicFont, fontSize: 24),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (l == null)
                LessonText('অর্থ এখনো যোগ হয়নি', color: p.muted)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: LessonText(
                        l.meaning ?? 'অর্থ এখনো যোগ হয়নি',
                        size: 20,
                        weight: FontWeight.w700,
                        color: l.meaning == null ? p.muted : p.text,
                      ),
                    ),
                    if (l.meaning != null && l.isDraft) const DraftBadge(),
                  ],
                ),
                if (l.note != null) LessonText(l.note!, size: 16, color: p.muted),
                const SizedBox(height: 6),
                LessonText(
                  'কুরআনে ${toBanglaDigits(l.frequency)} বার আছে',
                  size: 16,
                  color: p.muted,
                ),
                const SizedBox(height: 12),
                if (learn.known.contains(l.id))
                  OutlinedButton.icon(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('রিভিউতে আছে'),
                  )
                else if (l.meaning != null)
                  FilledButton.icon(
                    onPressed: () async {
                      await learn.addWord(l.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('রিভিউতে যোগ হলো')));
                      }
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('শিখব', style: TextStyle(fontSize: 17)),
                  ),
                if (l.root != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _showRoot = !_showRoot);
                        if (_showRoot && _related.isEmpty) _loadRoot(l);
                      },
                      icon: Icon(_showRoot ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                      label: Text(_showRoot ? 'মূল অক্ষর লুকান' : 'মূল অক্ষর দেখুন'),
                    ),
                  ),
                  if (_showRoot) _rootBox(p, l),
                ],
              ],
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => _report(l),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('ভুল জানান'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rootBox(Palette p, Lemma l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surfaceSoft, borderRadius: BorderRadius.circular(radiusM)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l.root!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFont,
                fontSize: 32,
                color: p.arabic,
                letterSpacing: 6,
              ),
            ),
          ),
          if (_rootIdea != null)
            Row(
              children: [
                Expanded(
                  child: LessonText(
                    'এই তিনটি অক্ষর থেকে ‘${_rootIdea!.meaning}’ অর্থের শব্দ আসে',
                    size: 16,
                  ),
                ),
                if (_rootIdea!.draft) const DraftBadge(),
              ],
            ),
          if (_related.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('একই মূলের আরও শব্দ', style: TextStyle(color: p.muted, fontSize: 14)),
            for (final (x, word) in _related)
              if (word != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: LessonText(
                          [
                            if (x.meaning != null) x.meaning!,
                            'কুরআনে ${toBanglaDigits(x.frequency)} বার',
                          ].join(' · '),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ArabicWord(word, size: 26),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
