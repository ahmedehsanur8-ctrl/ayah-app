import 'package:flutter/material.dart';

import '../../../../models/content.dart';
import '../../../../services/quran.dart';
import '../../../../theme.dart';
import '../../../../widgets/ui.dart';
import '../../domain/models.dart';
import '../../srs/srs_service.dart';
import '../../state/learn_controller.dart';
import '../widgets/learn_widgets.dart';
import '../widgets/word_sheet.dart';

/// /learn/lesson/:id — the six steps of a lesson as pages with a progress bar:
/// আয়াত, শব্দ, বুঝি, অনুশীলন, মনে করি, আবার আয়াত.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final learn = Learn.instance;
  final _pages = PageController();
  final _started = DateTime.now();
  int _page = 0;
  final _done = <int>{};
  int? _score;
  final _ratings = <int, Rating>{};
  bool _saving = false;
  _LessonData? _data;

  Lesson get lesson => widget.lesson;

  @override
  void initState() {
    super.initState();
    _LessonData.load(lesson).then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _complete(int i) {
    final s = lesson.steps[i];
    return switch (s) {
      QuizStep() || RecallStep() => _done.contains(i),
      _ => true,
    };
  }

  Future<void> _next() async {
    if (_page < lesson.steps.length - 1) {
      await _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return;
    }
    setState(() => _saving = true);
    await learn.completeLesson(
      lesson,
      _score ?? 100,
      _ratings,
      seconds: DateTime.now().difference(_started).inSeconds,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('মাশাআল্লাহ! “${lesson.title}” পাঠ শেষ হলো।')));
  }

  Future<bool> _confirmExit() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('পাঠ ছেড়ে যাবেন?'),
        content: const Text('এখন বের হলে এই পাঠের অগ্রগতি জমা থাকবে না।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('থাকি')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('বের হই')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final steps = lesson.steps;
    final d = _data;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(child: Text(lesson.title, overflow: TextOverflow.ellipsis)),
              if (lesson.isDraft) const DraftBadge(),
            ],
          ),
          // Emerald step progress with "ধাপ ২/৭".
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_page + 1) / steps.length,
                        minHeight: 8,
                        backgroundColor: p.pill,
                        color: p.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ধাপ ${toBanglaDigits(_page + 1)}/${toBanglaDigits(steps.length)}',
                    style: TextStyle(color: p.muted, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: d == null
            ? const Center(child: CircularProgressIndicator())
            : PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (var i = 0; i < steps.length; i++)
                    switch (steps[i]) {
                      AyahStep(:final range) => _AyahPage(data: d, range: range),
                      WordsStep(:final lemmaIds) => _WordsPage(data: d, lemmaIds: lemmaIds),
                      ExplainStep(:final text, :final examples) => _ExplainPage(
                        data: d,
                        text: text,
                        examples: examples,
                      ),
                      QuizStep(:final items) => _QuizPage(
                        data: d,
                        items: items,
                        onDone: (score) => setState(() {
                          _score = score;
                          _done.add(i);
                        }),
                      ),
                      RecallStep(:final lemmaIds) => _RecallPage(
                        data: d,
                        lemmaIds: lemmaIds,
                        onDone: (ratings) => setState(() {
                          _ratings.addAll(ratings);
                          _done.add(i);
                        }),
                      ),
                      AyahRecapStep(:final range) => _RecapPage(data: d, range: range),
                    },
                ],
              ),
        bottomNavigationBar: d == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: _complete(_page) && !_saving ? _next : null,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    child: Text(
                      _page == steps.length - 1 ? 'পাঠ শেষ' : 'পরের ধাপ',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Everything a lesson shows, loaded once: lemmas and the Tanzil word for each.
class _LessonData {
  _LessonData(this.lesson, this.lemmas, this.wordOf, this.lessonLemmas);

  final Lesson lesson;
  final Map<int, Lemma> lemmas;

  /// The Tanzil word that shows each lemma (from a lesson, else its first occurrence).
  final Map<int, QuranWord> wordOf;

  /// Lemmas taught in this lesson (count as known in the recap).
  final Set<int> lessonLemmas;

  static Future<_LessonData> load(Lesson lesson) async {
    final learn = Learn.instance;
    final c = learn.content!;
    final ids = <int>{};
    for (final s in lesson.steps) {
      switch (s) {
        case WordsStep(:final lemmaIds):
          ids.addAll(lemmaIds);
        case QuizStep(:final items):
          for (final it in items) {
            if (it.lemmaId != null) ids.add(it.lemmaId!);
            ids.addAll(it.distractors);
          }
        case RecallStep(:final lemmaIds):
          ids.addAll(lemmaIds);
        default:
      }
    }
    // Where each lemma was taught (any lesson), so a word looks the same everywhere.
    final refs = <int, WordRef>{};
    for (final l in learn.lessons) {
      for (final s in l.steps.whereType<WordsStep>()) {
        for (var i = 0; i < s.lemmaIds.length && i < s.refs.length; i++) {
          refs.putIfAbsent(s.lemmaIds[i], () => s.refs[i]);
        }
      }
    }
    final lemmas = await c.lemmas(ids);
    final wordOf = <int, QuranWord>{};
    final fallback = <int>{};
    for (final id in ids) {
      final r = refs[id];
      final w = r == null ? null : await c.word(r.surah, r.ayah, r.index);
      if (w != null) {
        wordOf[id] = w;
      } else if (lemmas[id] != null) {
        fallback.add(id);
      }
    }
    final byId = await c.wordsById(fallback.map((i) => lemmas[i]!.displayWordId));
    for (final id in fallback) {
      final w = byId[lemmas[id]!.displayWordId];
      if (w != null) wordOf[id] = w;
    }
    return _LessonData(lesson, lemmas, wordOf, lesson.newLemmas.toSet());
  }

  String meaning(int id) => lemmas[id]?.meaning ?? '—';

  bool known(QuranWord w) =>
      w.lemmaId != null &&
      (Learn.instance.known.contains(w.lemmaId) || lessonLemmas.contains(w.lemmaId));
}

/// A heading for a step.
class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.hint);

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle(context.palette, size: 22)),
        LessonText(hint, size: 16, color: context.palette.muted),
      ],
    ),
  );
}

// ------------------------------------------------------------------ ayah

class _AyahView extends StatefulWidget {
  const _AyahView({required this.data, required this.range, this.recap = false});

  final _LessonData data;
  final AyahRange range;
  final bool recap;

  @override
  State<_AyahView> createState() => _AyahViewState();
}

class _AyahViewState extends State<_AyahView> {
  List<QuranWord>? _words;
  bool _showMeaning = false;
  List<String> _meaning = const [];

  @override
  void initState() {
    super.initState();
    final r = widget.range;
    Learn.instance.content!.ayahWords(r.surah, r.from, r.to, r.wordTo).then((w) {
      if (mounted) setState(() => _words = w);
    });
  }

  Future<void> _loadMeaning() async {
    await Quran.load();
    final t = Quran.loaded['bn_zakaria'];
    final r = widget.range;
    if (!mounted || t == null) return;
    setState(() {
      _meaning = [
        for (var a = r.from; a <= r.to; a++)
          '(${toBanglaDigits(a)}) '
              '${t.text[Quran.indexOf(r.surah, a)].replaceAll(RegExp(r'\s*\[[০-৯0-9]+\]'), '')}',
      ];
      _showMeaning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final words = _words;
    if (words == null) return const Center(child: CircularProgressIndicator());
    final r = widget.range;
    final counted = words.where((w) => w.lemmaId != null).toList();
    final known = counted.where(widget.data.known).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LessonText(
          'সূরা ${Quran.surah(r.surah).nameBn} · আয়াত ${toBanglaDigits(r.from)}'
          '${r.to != r.from ? '–${toBanglaDigits(r.to)}' : ''}'
          '${r.wordTo != null ? ' (শুরুর অংশ)' : ''}',
          size: 16,
          color: p.muted,
        ),
        const SizedBox(height: 8),
        AppCard(
          child: TappableAyah(
            words: words,
            isKnown: widget.recap ? widget.data.known : (_) => false,
            onTap: (w) => showWordSheet(context, w),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.recap)
          LessonText(
            knownLine(known, counted.length).replaceFirst('চেনেন', 'চিনেছেন'),
            size: 20,
            weight: FontWeight.w700,
            color: p.primary,
            align: TextAlign.center,
          )
        else if (_showMeaning)
          for (final m in _meaning) LessonText(m, size: 17)
        else
          OutlinedButton.icon(
            onPressed: _loadMeaning,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('বাংলা অর্থ দেখুন'),
          ),
        if (!widget.recap && _showMeaning)
          LessonText('— ড. আবু বকর মুহাম্মাদ যাকারিয়া', size: 14, color: p.muted),
      ],
    );
  }
}

class _AyahPage extends StatelessWidget {
  const _AyahPage({required this.data, required this.range});

  final _LessonData data;
  final AyahRange range;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const _StepTitle('আয়াত', 'আগে আয়াতটি পড়ুন। কোনো শব্দে চাপ দিলে তার অর্থ দেখবেন।'),
      _AyahView(data: data, range: range),
    ],
  );
}

class _RecapPage extends StatelessWidget {
  const _RecapPage({required this.data, required this.range});

  final _LessonData data;
  final AyahRange range;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const _StepTitle('আবার আয়াত', 'রঙিন ও দাগ দেওয়া শব্দগুলো এখন আপনি চেনেন।'),
      _AyahView(data: data, range: range, recap: true),
    ],
  );
}

// ------------------------------------------------------------------ words

class _WordsPage extends StatelessWidget {
  const _WordsPage({required this.data, required this.lemmaIds});

  final _LessonData data;
  final List<int> lemmaIds;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const _StepTitle('শব্দ', 'নতুন শব্দগুলো দেখুন। কার্ডে চাপ দিলে আরও জানবেন।'),
      for (final id in lemmaIds)
        if (data.wordOf[id] != null && data.lemmas[id] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WordCard(
              word: data.wordOf[id]!,
              lemma: data.lemmas[id]!,
              level: data.lesson.level,
            ),
          ),
    ],
  );
}

class _WordCard extends StatefulWidget {
  const _WordCard({required this.word, required this.lemma, required this.level});

  final QuranWord word;
  final Lemma lemma;
  final int level;

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _translit = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = widget.lemma;
    final canTranslit = widget.level == 1 && Learn.instance.showTranslit && l.translit != null;
    return AppCard(
      onTap: () => showWordSheet(context, widget.word, lemmaId: l.id),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusWordCard(word: widget.word, size: 40, highlight: widget.word.spanOf(l.id)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: LessonText(l.meaning ?? '—', size: 20, weight: FontWeight.w700)),
              if (l.isDraft) const DraftBadge(),
            ],
          ),
          if (l.note != null) LessonText(l.note!, size: 16, color: p.muted),
          if (canTranslit)
            Align(
              alignment: Alignment.centerLeft,
              child: _translit
                  ? LessonText('উচ্চারণ: ${l.translit}', size: 16, color: p.goldText)
                  : TextButton(
                      onPressed: () => setState(() => _translit = true),
                      child: const Text('উচ্চারণ দেখুন'),
                    ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ explain

class _ExplainPage extends StatelessWidget {
  const _ExplainPage({required this.data, required this.text, required this.examples});

  final _LessonData data;
  final String text;
  final List<WordRef> examples;

  @override
  Widget build(BuildContext context) {
    final c = Learn.instance.content!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: _StepTitle('বুঝি', 'একটি ছোট নিয়ম, সহজ বাংলায়।')),
            if (data.lesson.isDraft) const DraftBadge(),
          ],
        ),
        AppCard(child: LessonText(text, size: 18)),
        const SizedBox(height: 14),
        LessonText('উদাহরণ', size: 16, color: context.palette.muted),
        const SizedBox(height: 6),
        FutureBuilder(
          future: Future.wait([for (final e in examples) c.word(e.surah, e.ayah, e.index)]),
          builder: (context, snap) => Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final w in snap.data ?? const <QuranWord?>[])
                  if (w != null)
                    ActionChip(
                      onPressed: () => showWordSheet(context, w),
                      label: ArabicWord(w, size: 28),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ quiz

class _QuizPage extends StatefulWidget {
  const _QuizPage({required this.data, required this.items, required this.onDone});

  final _LessonData data;
  final List<QuizItem> items;
  final void Function(int score) onDone;

  @override
  State<_QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<_QuizPage> {
  int _i = 0;
  int _correct = 0;
  bool? _answered;

  void _answer(bool correct) {
    setState(() {
      _answered = correct;
      if (correct) _correct++;
    });
  }

  void _nextItem() {
    if (_i + 1 >= widget.items.length) {
      widget.onDone((_correct * 100 / widget.items.length).round());
      setState(() => _i++);
      return;
    }
    setState(() {
      _i++;
      _answered = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = widget.items;
    if (_i >= items.length) {
      final pct = (_correct * 100 / items.length).round();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StepTitle('অনুশীলন', 'শেষ হলো।'),
          AppCard(
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined, size: 48, color: p.goldText),
                LessonText(
                  '${toBanglaDigits(items.length)}টির মধ্যে ${toBanglaDigits(_correct)}টি ঠিক '
                  '(${toBanglaDigits(pct)}%)',
                  size: 20,
                  weight: FontWeight.w700,
                  align: TextAlign.center,
                ),
                LessonText('এবার ‘পরের ধাপ’ চাপুন।', size: 16, color: p.muted),
              ],
            ),
          ),
        ],
      );
    }
    final it = items[_i];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StepTitle('অনুশীলন', 'প্রশ্ন ${toBanglaDigits(_i + 1)} / ${toBanglaDigits(items.length)}'),
        KeyedSubtree(
          key: ValueKey(_i),
          child: switch (it.kind) {
            'split' => _SplitItem(data: widget.data, item: it, onAnswer: _answer),
            'order' => _OrderItem(item: it, onAnswer: _answer),
            _ => _ChoiceItem(data: widget.data, item: it, onAnswer: _answer),
          },
        ),
        if (_answered != null) ...[
          const SizedBox(height: 12),
          LessonText(
            _answered! ? 'ঠিক হয়েছে!' : 'ঠিক উত্তরটি সবুজ করে দেখানো হলো।',
            size: 17,
            weight: FontWeight.w700,
            color: _answered! ? p.mint.foreground : p.rose.foreground,
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _nextItem,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(_i + 1 >= items.length ? 'ফল দেখুন' : 'পরের প্রশ্ন'),
          ),
        ],
      ],
    );
  }
}

/// A stable shuffle (same order every time the item is shown).
List<T> _shuffled<T>(List<T> list, int seed) {
  final out = [...list];
  var s = seed * 2654435761 % 4294967296;
  for (var i = out.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) % 2147483648;
    final j = s % (i + 1);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

/// Arabic → Bangla, Bangla → Arabic, and listen → choose (as Arabic → Bangla
/// until word audio is added).
class _ChoiceItem extends StatefulWidget {
  const _ChoiceItem({required this.data, required this.item, required this.onAnswer});

  final _LessonData data;
  final QuizItem item;
  final void Function(bool) onAnswer;

  @override
  State<_ChoiceItem> createState() => _ChoiceItemState();
}

class _ChoiceItemState extends State<_ChoiceItem> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final it = widget.item;
    final target = it.lemmaId!;
    final options = _shuffled([target, ...it.distractors], target);
    final toArabic = it.kind == 'mcq_bn_ar';
    final word = d.wordOf[target];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (toArabic) ...[
          LessonText('কোন শব্দের অর্থ:', size: 16, color: context.palette.muted),
          LessonText('“${d.meaning(target)}”', size: 22, weight: FontWeight.w700),
        ] else ...[
          LessonText('এর অর্থ কী?', size: 16, color: context.palette.muted),
          if (word != null) FocusWordCard(word: word, size: 40, highlight: word.spanOf(target)),
        ],
        const SizedBox(height: 10),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              state: _picked == null
                  ? _Opt.idle
                  : o == target
                  ? _Opt.right
                  : o == _picked
                  ? _Opt.wrong
                  : _Opt.idle,
              onTap: _picked != null
                  ? null
                  : () {
                      setState(() => _picked = o);
                      widget.onAnswer(o == target);
                    },
              child: toArabic && d.wordOf[o] != null
                  ? Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        d.wordOf[o]!.partFor(o),
                        style: const TextStyle(fontFamily: arabicFont, fontSize: 28),
                      ),
                    )
                  : Text(d.meaning(o), style: const TextStyle(fontSize: 17)),
            ),
          ),
      ],
    );
  }
}

enum _Opt { idle, right, wrong }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.state, required this.onTap, required this.child});

  final _Opt state;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = switch (state) {
      _Opt.right => p.mint,
      _Opt.wrong => p.rose,
      _Opt.idle => null,
    };
    return Material(
      color: tint?.background ?? p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusM),
        side: BorderSide(color: tint?.foreground ?? p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusM),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: p.text),
                    child: child,
                  ),
                ),
                if (state == _Opt.right) Icon(Icons.check_circle_rounded, color: p.mint.foreground),
                if (state == _Opt.wrong) Icon(Icons.cancel_rounded, color: p.rose.foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Split a word into its parts: for each coloured part, pick its meaning.
class _SplitItem extends StatefulWidget {
  const _SplitItem({required this.data, required this.item, required this.onAnswer});

  final _LessonData data;
  final QuizItem item;
  final void Function(bool) onAnswer;

  @override
  State<_SplitItem> createState() => _SplitItemState();
}

class _SplitItemState extends State<_SplitItem> {
  QuranWord? _word;
  Map<int, Lemma> _lemmas = const {};
  int _part = 0;
  bool _allRight = true;
  int? _picked;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    final c = Learn.instance.content!;
    c.word(it.surah!, it.ayah!, it.wordIndex!).then((w) async {
      final l = await c.lemmas(w!.allLemmas);
      if (mounted) {
        setState(() {
          _word = w;
          _lemmas = l;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = _word;
    if (w == null) return const Center(child: CircularProgressIndicator());
    final parts = [
      for (final s in w.segments)
        if (s.lemmaId != null) s.lemmaId!,
    ];
    final done = _part >= parts.length;
    final target = done ? null : parts[_part];
    final options = _shuffled(parts.toSet().toList(), w.id + _part);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LessonText(
          'শব্দটি কয়েকটি অংশে গড়া। রঙিন অংশের অর্থ কী?',
          size: 16,
          color: context.palette.muted,
        ),
        FocusWordCard(word: w, highlight: target == null ? null : w.spanOf(target)),
        const SizedBox(height: 10),
        if (!done)
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionButton(
                state: _picked == null
                    ? _Opt.idle
                    : o == target
                    ? _Opt.right
                    : o == _picked
                    ? _Opt.wrong
                    : _Opt.idle,
                onTap: _picked != null
                    ? null
                    : () {
                        setState(() {
                          _picked = o;
                          if (o != target) _allRight = false;
                        });
                        Future.delayed(const Duration(milliseconds: 700), () {
                          if (!mounted) return;
                          setState(() {
                            _part++;
                            _picked = null;
                          });
                          if (_part >= parts.length) widget.onAnswer(_allRight);
                        });
                      },
                child: Text(_lemmas[o]?.meaning ?? '—', style: const TextStyle(fontSize: 17)),
              ),
            ),
      ],
    );
  }
}

/// Put the words of an ayah in order (right to left).
class _OrderItem extends StatefulWidget {
  const _OrderItem({required this.item, required this.onAnswer});

  final QuizItem item;
  final void Function(bool) onAnswer;

  @override
  State<_OrderItem> createState() => _OrderItemState();
}

class _OrderItemState extends State<_OrderItem> {
  List<QuranWord>? _words;
  List<QuranWord> _pool = [];
  final _answer = <QuranWord>[];
  bool? _checked;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    Learn.instance.content!.ayahWords(it.surah!, it.ayah!).then((w) {
      if (!mounted) return;
      var pool = _shuffled(w, it.surah! * 1000 + it.ayah!);
      if (w.length > 1 && List.generate(w.length, (i) => pool[i].id == w[i].id).every((x) => x)) {
        pool = [...pool.skip(1), pool.first];
      }
      setState(() {
        _words = w;
        _pool = pool;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final words = _words;
    if (words == null) return const Center(child: CircularProgressIndicator());
    Widget chip(QuranWord w, VoidCallback? onTap) =>
        ActionChip(onPressed: onTap, label: ArabicWord(w, size: 26));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LessonText('শব্দগুলো ঠিক ক্রমে সাজান (ডান থেকে বাঁয়ে)।', size: 16, color: p.muted),
        const SizedBox(height: 8),
        AppCard(
          color: p.surfaceSoft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in _answer)
                    chip(
                      w,
                      _checked != null
                          ? null
                          : () => setState(() {
                              _answer.remove(w);
                              _pool.add(w);
                            }),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in _pool)
                chip(
                  w,
                  () => setState(() {
                    _pool.remove(w);
                    _answer.add(w);
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_checked == null && _pool.isEmpty)
          FilledButton(
            onPressed: () {
              final ok = List.generate(
                words.length,
                (i) => _answer[i].id == words[i].id,
              ).every((x) => x);
              setState(() => _checked = ok);
              widget.onAnswer(ok);
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('মিলিয়ে দেখুন'),
          ),
        if (_checked == false) ...[
          LessonText('ঠিক ক্রম:', size: 16, color: p.muted),
          AppCard(
            child: TappableAyah(words: words, isKnown: (_) => false, size: 26),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ recall

class _RecallPage extends StatefulWidget {
  const _RecallPage({required this.data, required this.lemmaIds, required this.onDone});

  final _LessonData data;
  final List<int> lemmaIds;
  final void Function(Map<int, Rating>) onDone;

  @override
  State<_RecallPage> createState() => _RecallPageState();
}

class _RecallPageState extends State<_RecallPage> {
  int _i = 0;
  bool _shown = false;
  bool _reported = false;
  final _ratings = <int, Rating>{};

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ids = widget.lemmaIds.where((i) => widget.data.wordOf[i] != null).toList();
    if (ids.isEmpty && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone(const {}));
    }
    if (_i >= ids.length) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StepTitle('মনে করি', 'শেষ হলো।'),
          AppCard(
            child: LessonText(
              '${toBanglaDigits(ids.length)}টি শব্দ এখন রিভিউতে যাবে। ঠিক সময়ে আবার মনে করিয়ে দেওয়া হবে।',
              size: 17,
            ),
          ),
        ],
      );
    }
    final id = ids[_i];
    final w = widget.data.wordOf[id]!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StepTitle(
          'মনে করি',
          'অর্থটা মনে মনে বলুন, তারপর দেখুন। ${toBanglaDigits(_i + 1)} / ${toBanglaDigits(ids.length)}',
        ),
        FocusWordCard(word: w, highlight: w.spanOf(id)),
        const SizedBox(height: 12),
        if (!_shown)
          OutlinedButton(
            onPressed: () => setState(() => _shown = true),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            child: const Text('অর্থ দেখুন', style: TextStyle(fontSize: 17)),
          )
        else ...[
          LessonText(
            widget.data.meaning(id),
            size: 22,
            weight: FontWeight.w700,
            align: TextAlign.center,
          ),
          const SizedBox(height: 4),
          LessonText('কতটা মনে ছিল?', size: 16, color: p.muted, align: TextAlign.center),
          const SizedBox(height: 8),
          RatingBar(
            onRate: (r) {
              _ratings[id] = r;
              setState(() {
                _i++;
                _shown = false;
              });
              if (_i >= ids.length) widget.onDone(_ratings);
            },
          ),
        ],
      ],
    );
  }
}
