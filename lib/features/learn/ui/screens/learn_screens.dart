import 'package:flutter/material.dart';

import '../../../../models/content.dart';
import '../../../../screens/settings_screen.dart';
import '../../../../services/quran.dart';
import '../../../../theme.dart';
import '../../../../widgets/night.dart';
import '../../../../widgets/ui.dart';
import '../../domain/models.dart';
import '../../srs/srs_service.dart';
import '../../state/learn_controller.dart';
import '../widgets/learn_widgets.dart';
import '../widgets/word_sheet.dart';
import 'lesson_screen.dart';

/// The spec's routes, kept for reference and future deep links. The app opens
/// pages with push(), so each route is one screen class.
class LearnRoutes {
  static const dashboard = '/learn'; // LearnDashboardScreen
  static const path = '/learn/path'; // LearnPathScreen
  static const lesson = '/learn/lesson/:id'; // LessonScreen
  static const review = '/learn/review'; // LearnReviewScreen
  static const words = '/learn/words'; // LearnWordsScreen
  static const progress = '/learn/progress'; // LearnProgressScreen
  static const ayah = '/learn/ayah/:surah/:ayah'; // LearnAyahScreen
  static const credits = '/learn/credits'; // LearnCreditsScreen
}

const levelTitles = {1: 'যা প্রতিদিন পড়ি', 2: 'সর্বনাম ও ছোট বাক্য', 3: 'ক্রিয়ার শুরু'};

/// A slice of the lessons for one সহজ আরবি level card (levels 3 and 4 open
/// কুরআন বুঝি at these lessons).
class LearnTrack {
  const LearnTrack({required this.title, required this.about, required this.lessonIds});

  final String title;
  final String about;
  final List<String> lessonIds;

  /// সহজ আরবি level 3: lessons whose main idea is a grammar rule.
  static const grammar = LearnTrack(
    title: 'সহজ ব্যাকরণ',
    about: 'শব্দ কীভাবে বদলায়, বাক্য কীভাবে গড়ে — কুরআন বুঝি-র যে পাঠগুলোতে একটি করে নিয়ম শেখানো হয়।',
    lessonIds: [
      'L1-02', 'L1-03', 'L1-04', 'L1-05', // আল, -এর, ক্রিয়ায় ‘আমরা’, বিশেষণ
      'L2-11', 'L2-12', 'L2-13', 'L2-14', 'L2-15', // অব্যয়, সর্বনাম, ইঙ্গিত, ছোট বাক্য
      'L2-16', 'L2-17', 'L2-18', 'L2-19', // প্রশ্ন, না-বোধক, জোর, গুণের ছাঁচ
      'L3-21', 'L3-22', 'L3-23', 'L3-24', // অতীত, শেষ অংশ, বর্তমান, আদেশ
      'L3-26', 'L3-27', 'L3-28', // মূল অক্ষর, বহুবচন
    ],
  );

  /// সহজ আরবি level 4: lessons that read whole ayahs or short surahs.
  static const reading = LearnTrack(
    title: 'বুঝে পড়ি',
    about: 'পুরো আয়াত ও ছোট সূরা অর্থসহ বুঝে পড়া — কুরআন বুঝি-র পড়ার পাঠগুলো।',
    lessonIds: ['L1-07', 'L1-09', 'L1-10', 'L2-20', 'L3-30'],
  );
}

/// Opens the databases on first use, then rebuilds whenever learning state changes.
class LearnGate extends StatelessWidget {
  const LearnGate({super.key, required this.builder});

  final Widget Function(BuildContext context, Learn learn) builder;

  @override
  Widget build(BuildContext context) {
    final learn = Learn.instance;
    return FutureBuilder(
      future: learn.ensureReady(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('কুরআন বুঝি খোলা যায়নি। অ্যাপটি আবার চালু করে দেখুন।\n${snap.error}'),
            ),
          );
        }
        if (!learn.ready) return const Center(child: CircularProgressIndicator());
        return ListenableBuilder(
          listenable: learn,
          builder: (context, _) => builder(context, learn),
        );
      },
    );
  }
}

int _reviewMinutes(int n) => n == 0 ? 0 : ((n * 10) / 60).ceil();

// ------------------------------------------------------------------ dashboard

/// /learn
class LearnDashboardScreen extends StatelessWidget {
  const LearnDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('কুরআন বুঝি')),
      body: LearnGate(
        builder: (context, learn) {
          final p = context.palette;
          final next = learn.nextLesson;
          final due = learn.stats.todayLeft;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              LessonText(
                'কুরআনের সবচেয়ে বেশি আসা শব্দগুলো চিনি, পরিচিত আয়াতের ভেতরেই।',
                size: 16,
                color: p.muted,
              ),
              const SizedBox(height: 12),
              _ContinueCard(next: next),
              const SizedBox(height: 12),
              AppCard(
                onTap: due == 0 ? null : () => push(context, const LearnReviewScreen()),
                child: Row(
                  children: [
                    IconBubble(Icons.replay_rounded, tint: p.sky),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LessonText('আজকের রিভিউ', size: 16, weight: FontWeight.w700),
                          LessonText(
                            due == 0
                                ? (learn.stats.cards == 0
                                      ? 'প্রথম পাঠ শেষ করলে রিভিউ শুরু হবে'
                                      : 'আজ আর রিভিউ বাকি নেই')
                                : 'রিভিউ: ${toBanglaDigits(due)}টি · ${toBanglaDigits(_reviewMinutes(due))} মিনিট',
                            size: 16,
                            color: p.muted,
                          ),
                        ],
                      ),
                    ),
                    if (due > 0) Icon(Icons.chevron_right_rounded, color: p.muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(toBanglaDigits(learn.known.length), 'চেনা শব্দ', p.mint)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat('${toBanglaDigits(learn.streak)} দিন', 'টানা শেখা', p.sand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(
                      '${toBanglaDigits(learn.lessonsDone)}/${toBanglaDigits(learn.lessons.length)}',
                      'পাঠ শেষ',
                      p.lilac,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RowGroup(
                children: [
                  NavRow(
                    icon: Icons.route_outlined,
                    title: 'সব পাঠ',
                    subtitle: 'তিন স্তর, ৩০টি পাঠ',
                    onTap: () => push(context, const LearnPathScreen()),
                  ),
                  NavRow(
                    icon: Icons.translate_rounded,
                    tint: p.sky,
                    title: 'আমার শব্দ',
                    subtitle: 'যে শব্দগুলো শিখছেন',
                    onTap: () => push(context, const LearnWordsScreen()),
                  ),
                  NavRow(
                    icon: Icons.insights_outlined,
                    tint: p.sand,
                    title: 'অগ্রগতি',
                    subtitle: 'সূরা ফাতিহা ও ৩০তম পারার কতটা চেনেন',
                    onTap: () => push(context, const LearnProgressScreen()),
                  ),
                  NavRow(
                    icon: Icons.tune_rounded,
                    tint: p.lilac,
                    title: 'শেখার সেটিং',
                    subtitle: 'শেখার মোড, প্রতিদিনের লক্ষ্য',
                    onTap: () =>
                        push(context, const SettingsScreen(section: SettingsSection.learn)),
                  ),
                  NavRow(
                    icon: Icons.volunteer_activism_outlined,
                    tint: p.rose,
                    title: 'উৎস ও কৃতজ্ঞতা',
                    onTap: () => push(context, const LearnCreditsScreen()),
                  ),
                ],
              ),
              if (learn.lessons.any((l) => l.isDraft)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const DraftBadge(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LessonText(
                        '‘খসড়া’ চিহ্নের অর্থ ও ব্যাখ্যা একজন শিক্ষক এখনো যাচাই করছেন।',
                        size: 14,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.tint);

  final String value;
  final String label;
  final Tint tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
    decoration: BoxDecoration(color: tint.background, borderRadius: BorderRadius.circular(radiusM)),
    child: Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tint.foreground),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 14, color: tint.foreground)),
      ],
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.next});

  final Lesson? next;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = next;
    return Material(
      color: p.night,
      borderRadius: BorderRadius.circular(radiusL),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const GirihLayer(cell: 44, opacity: 0.16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l == null ? 'সব পাঠ শেষ' : 'পরের পাঠ · স্তর ${toBanglaDigits(l.level)}',
                  style: TextStyle(color: p.gold, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  l == null
                      ? 'মাশাআল্লাহ! এখন রিভিউ চালিয়ে যান।'
                      : '${toBanglaDigits(l.ord)}. ${l.title}',
                  style: nightTitleStyle(p, size: 20),
                ),
                if (l != null) ...[
                  Text(
                    '${l.objective}, ${toBanglaDigits(l.minutes)} মিনিট',
                    style: TextStyle(color: p.onNightMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    onPressed: () => push(context, LessonScreen(lesson: l)),
                    icon: Icons.play_arrow_rounded,
                    label: l.ord == 1 && Learn.instance.lessonsDone == 0
                        ? 'শুরু করুন'
                        : 'চালিয়ে যান',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ path

/// /learn/path
class LearnPathScreen extends StatelessWidget {
  const LearnPathScreen({super.key, this.track});

  /// Only these lessons (opened from a সহজ আরবি level card).
  final LearnTrack? track;

  @override
  Widget build(BuildContext context) {
    final t = track;
    return Scaffold(
      appBar: AppBar(title: Text(t == null ? 'সব পাঠ' : t.title)),
      body: LearnGate(
        builder: (context, learn) {
          final p = context.palette;
          bool show(Lesson l) => t == null || t.lessonIds.contains(l.id);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: [
              if (t != null) ...[
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LessonText(t.about, size: 16),
                      const SizedBox(height: 6),
                      LessonText(
                        'তৈরি: ${toBanglaDigits(t.lessonIds.length)}টি পাঠ · '
                        'শেষ: ${toBanglaDigits(learn.lessons.where((l) => show(l) && learn.statusOf(l) == LessonStatus.done).length)}টি',
                        size: 16,
                        weight: FontWeight.w700,
                        color: p.primary,
                      ),
                      LessonText(
                        'যেকোনো পাঠ খুলতে পারেন; ক্রমে পড়লে সবচেয়ে সহজ।',
                        size: 14,
                        color: p.muted,
                      ),
                    ],
                  ),
                ),
              ],
              for (final level in levelTitles.keys)
                if (learn.lessons.any((l) => l.level == level && show(l))) ...[
                  SectionLabel(
                    'স্তর ${toBanglaDigits(level)} · ${levelTitles[level]}',
                    trailing: learn.levelDone(level)
                        ? Icon(Icons.workspace_premium_outlined, color: p.goldText)
                        : null,
                  ),
                  RowGroup(
                    children: [
                      for (final l in learn.lessons.where((x) => x.level == level && show(x)))
                        _LessonTile(lesson: l, status: learn.statusOf(l), learn: learn),
                    ],
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.status, required this.learn});

  final Lesson lesson;
  final LessonStatus status;
  final Learn learn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final score = learn.lessonProgress[lesson.id]?.bestScore;
    return NavRow(
      icon: switch (status) {
        LessonStatus.done => Icons.check_rounded,
        LessonStatus.available => Icons.play_arrow_rounded,
        LessonStatus.locked => Icons.lock_outline_rounded,
      },
      tint: switch (status) {
        LessonStatus.done => p.mint,
        LessonStatus.available => p.sand,
        LessonStatus.locked => Tint(p.surfaceSoft, p.muted),
      },
      title: '${toBanglaDigits(lesson.ord)}. ${lesson.title}',
      subtitle: [
        '${toBanglaDigits(lesson.minutes)} মিনিট',
        if (status == LessonStatus.done && score != null) 'ফল ${toBanglaDigits(score)}%',
        if (status == LessonStatus.locked) 'আগের পাঠ শেষ করে এলে সহজ হবে',
        if (lesson.isCheckpoint) 'স্তরের পরীক্ষা',
      ].join(' · '),
      onTap: () async {
        // Every lesson can be opened; out of order, a short reminder first.
        if (status == LessonStatus.locked) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(lesson.title),
              content: const Text(
                'এই পাঠের আগের পাঠগুলো এখনো শেষ হয়নি। ক্রমে পড়লে সহজ হয়, তবে চাইলে এখনই খুলতে পারেন।',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('পরে'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('খুলুন'),
                ),
              ],
            ),
          );
          if (ok != true) return;
        }
        if (context.mounted) await push(context, LessonScreen(lesson: lesson));
      },
    );
  }
}

// ------------------------------------------------------------------ review

/// /learn/review — today's due cards (at most 30, most overdue first).
class LearnReviewScreen extends StatefulWidget {
  const LearnReviewScreen({super.key});

  @override
  State<LearnReviewScreen> createState() => _LearnReviewScreenState();
}

class _LearnReviewScreenState extends State<LearnReviewScreen> {
  final learn = Learn.instance;
  List<int>? _due;
  Map<int, Lemma> _lemmas = const {};
  Map<int, QuranWord> _words = const {};
  int _i = 0;
  bool _shown = false;
  int _reviewed = 0;
  DateTime _shownAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await learn.ensureReady();
    final due = await learn.srs!.dueCards();
    final lemmas = await learn.content!.lemmas(due);
    final words = await _wordsFor(lemmas.values);
    if (!mounted) return;
    setState(() {
      _due = due.where(words.containsKey).toList();
      _lemmas = lemmas;
      _words = words;
      _shownAt = DateTime.now();
    });
  }

  Future<void> _rate(Rating r) async {
    final id = _due![_i];
    await learn.reviewWord(id, r, elapsedMs: DateTime.now().difference(_shownAt).inMilliseconds);
    setState(() {
      _i++;
      _reviewed++;
      _shown = false;
      _shownAt = DateTime.now();
    });
    if (_i >= _due!.length) await learn.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final due = _due;
    return Scaffold(
      appBar: AppBar(title: const Text('রিভিউ')),
      body: due == null
          ? const Center(child: CircularProgressIndicator())
          : _i >= due.length
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 52, color: p.mint.foreground),
                      LessonText(
                        _reviewed == 0
                            ? 'এখন রিভিউ করার মতো কোনো শব্দ নেই।'
                            : 'আজ ${toBanglaDigits(_reviewed)}টি শব্দ রিভিউ করেছেন। আলহামদুলিল্লাহ!',
                        size: 18,
                        align: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                LinearProgressIndicator(value: _i / due.length, minHeight: 6),
                const SizedBox(height: 12),
                LessonText(
                  '${toBanglaDigits(_i + 1)} / ${toBanglaDigits(due.length)} · অর্থটা মনে মনে বলুন',
                  size: 16,
                  color: p.muted,
                ),
                AppCard(
                  child: ArabicWord(
                    _words[due[_i]]!,
                    size: 44,
                    highlight: _words[due[_i]]!.spanOf(due[_i]),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_shown)
                  OutlinedButton(
                    onPressed: () => setState(() => _shown = true),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    child: const Text('অর্থ দেখুন', style: TextStyle(fontSize: 17)),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: LessonText(
                          _lemmas[due[_i]]?.meaning ?? '—',
                          size: 22,
                          weight: FontWeight.w700,
                          align: TextAlign.center,
                        ),
                      ),
                      if (_lemmas[due[_i]]?.isDraft ?? false) ...[
                        const SizedBox(width: 8),
                        const DraftBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  RatingBar(onRate: _rate),
                ],
              ],
            ),
    );
  }
}

/// The Tanzil word to show each lemma: where a lesson taught it, else its first
/// occurrence in the Quran.
Future<Map<int, QuranWord>> _wordsFor(Iterable<Lemma> lemmas) async {
  final learn = Learn.instance;
  final c = learn.content!;
  final refs = <int, WordRef>{};
  for (final l in learn.lessons) {
    for (final s in l.steps.whereType<WordsStep>()) {
      for (var i = 0; i < s.lemmaIds.length && i < s.refs.length; i++) {
        refs.putIfAbsent(s.lemmaIds[i], () => s.refs[i]);
      }
    }
  }
  final out = <int, QuranWord>{};
  final rest = <Lemma>[];
  for (final l in lemmas) {
    final r = refs[l.id];
    final w = r == null ? null : await c.word(r.surah, r.ayah, r.index);
    if (w != null) {
      out[l.id] = w;
    } else {
      rest.add(l);
    }
  }
  final byId = await c.wordsById(rest.map((l) => l.displayWordId));
  for (final l in rest) {
    final w = byId[l.displayWordId];
    if (w != null) out[l.id] = w;
  }
  return out;
}

// ------------------------------------------------------------------ words

/// /learn/words — every word in review; search in Arabic or Bangla, filter by level.
class LearnWordsScreen extends StatefulWidget {
  const LearnWordsScreen({super.key});

  @override
  State<LearnWordsScreen> createState() => _LearnWordsScreenState();
}

class _LearnWordsScreenState extends State<LearnWordsScreen> {
  String _q = '';
  int? _level; // null = all, 0 = from ayahs (no lesson)

  static final _marks = RegExp('[ً-ٰٟۖ-ۭـ]');

  static String _plain(String s) =>
      s.replaceAll(_marks, '').replaceAll(RegExp('[أإآٱ]'), 'ا').replaceAll('ى', 'ي');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আমার শব্দ')),
      body: LearnGate(
        builder: (context, learn) => FutureBuilder(
          future: () async {
            final lemmas = await learn.content!.lemmas(learn.known);
            return (lemmas, await _wordsFor(lemmas.values));
          }(),
          builder: (context, snap) {
            final p = context.palette;
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (lemmas, words) = snap.data!;
            final levelOf = <int, int>{
              for (final l in learn.lessons)
                for (final id in l.newLemmas) id: l.level,
            };
            final q = _q.trim();
            final list = lemmas.values.where((l) {
              final lv = levelOf[l.id] ?? 0;
              if (_level != null && lv != _level) return false;
              if (q.isEmpty) return true;
              final w = words[l.id];
              return (l.meaning ?? '').contains(q) ||
                  (w != null && _plain(w.partFor(l.id)).contains(_plain(q)));
            }).toList()..sort((a, b) => b.frequency.compareTo(a.frequency));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    hintText: 'বাংলা বা আরবিতে খুঁজুন',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (v, label) in [
                      (null, 'সব'),
                      (1, 'স্তর ১'),
                      (2, 'স্তর ২'),
                      (3, 'স্তর ৩'),
                      (0, 'আয়াত থেকে'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _level == v,
                        onSelected: (_) => setState(() => _level = v),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: LessonText(
                      learn.known.isEmpty
                          ? 'এখনো কোনো শব্দ নেই। প্রথম পাঠ শেষ করলে শব্দগুলো এখানে আসবে।'
                          : 'কিছু পাওয়া যায়নি।',
                      size: 16,
                      color: p.muted,
                      align: TextAlign.center,
                    ),
                  )
                else
                  RowGroup(
                    children: [
                      for (final l in list)
                        if (words[l.id] != null)
                          InkWell(
                            onTap: () => showWordSheet(context, words[l.id]!, lemmaId: l.id),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 64),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(child: LessonText(l.meaning ?? '—', size: 17)),
                                          if (l.isDraft) ...[
                                            const SizedBox(width: 6),
                                            const DraftBadge(),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Text(
                                        words[l.id]!.partFor(l.id),
                                        style: TextStyle(
                                          fontFamily: arabicFont,
                                          fontSize: 28,
                                          color: p.arabic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ progress

/// /learn/progress
class LearnProgressScreen extends StatelessWidget {
  const LearnProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অগ্রগতি')),
      body: LearnGate(
        builder: (context, learn) => FutureBuilder(
          future: Future.wait([learn.coverage(1, 1), learn.coverage(78, 114)]),
          builder: (context, snap) {
            final p = context.palette;
            final cov = snap.data ?? const [0.0, 0.0];
            final now = DateTime.now();
            final days = learn.activeDays.toSet();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      Text(
                        toBanglaDigits(learn.known.length),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: p.primary,
                        ),
                      ),
                      LessonText('চেনা শব্দ', size: 16, color: p.muted),
                      if (learn.stats.retained > 0)
                        LessonText(
                          'এর মধ্যে ${toBanglaDigits(learn.stats.retained)}টি ভালোভাবে মনে আছে',
                          size: 14,
                          color: p.muted,
                        ),
                    ],
                  ),
                ),
                const SectionLabel('যা পড়েন, তার কতটা চেনেন'),
                Row(
                  children: [
                    Expanded(child: _CoverageRing(cov[0], 'সূরা ফাতিহা')),
                    const SizedBox(width: 10),
                    Expanded(child: _CoverageRing(cov[1], '৩০তম পারা')),
                  ],
                ),
                const SectionLabel('গত ৩০ দিন'),
                AppCard(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 29; i >= 0; i--)
                        Builder(
                          builder: (context) {
                            final d = now.subtract(Duration(days: i));
                            final on = days.contains(Learn.dayKey(d));
                            return Semantics(
                              label:
                                  '${toBanglaDigits(d.day)} তারিখ ${on ? 'শিখেছেন' : 'শেখা হয়নি'}',
                              child: Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: on ? p.mint.background : p.surfaceSoft,
                                  border: Border.all(color: on ? p.mint.foreground : p.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: on
                                    ? Icon(Icons.check_rounded, size: 16, color: p.mint.foreground)
                                    : null,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                LessonText(
                  'টানা ${toBanglaDigits(learn.streak)} দিন (সপ্তাহে এক দিন বিরতি গোনা হয় না)',
                  size: 14,
                  color: p.muted,
                ),
                const SectionLabel('স্তর'),
                RowGroup(
                  children: [
                    for (final level in levelTitles.keys)
                      NavRow(
                        icon: learn.levelDone(level)
                            ? Icons.workspace_premium_outlined
                            : Icons.lock_clock_outlined,
                        tint: learn.levelDone(level) ? p.sand : Tint(p.surfaceSoft, p.muted),
                        title: 'স্তর ${toBanglaDigits(level)} · ${levelTitles[level]}',
                        subtitle: learn.levelDone(level) ? 'শেষ হয়েছে, আলহামদুলিল্লাহ' : 'চলছে',
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoverageRing extends StatelessWidget {
  const _CoverageRing(this.value, this.label);

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        children: [
          SizedBox.square(
            dimension: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    backgroundColor: p.surfaceSoft,
                  ),
                ),
                Text(
                  '${toBanglaDigits((value * 100).round())}%',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LessonText(label, size: 16, align: TextAlign.center),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ tappable ayah

/// /learn/ayah/:surah/:ayah — an ayah split into words; known words are tinted
/// and underlined; tap a word for its meaning. For a reminder that covers
/// several ayahs, আগের / পরের move within [to].
class LearnAyahScreen extends StatefulWidget {
  const LearnAyahScreen({super.key, required this.surah, required this.ayah, int? to})
    : to = to ?? ayah;

  final int surah;
  final int ayah;
  final int to;

  @override
  State<LearnAyahScreen> createState() => _LearnAyahScreenState();
}

class _LearnAyahScreenState extends State<LearnAyahScreen> {
  late int _a = widget.ayah;
  bool _counted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('এই আয়াত বুঝুন')),
      body: LearnGate(
        builder: (context, learn) {
          if (!_counted) {
            _counted = true;
            learn.countAyahTap();
          }
          return FutureBuilder(
            key: ValueKey(_a),
            future: learn.content!.ayahWords(widget.surah, _a),
            builder: (context, snap) {
              final p = context.palette;
              final words = snap.data;
              if (words == null) return const Center(child: CircularProgressIndicator());
              final counted = words.where((w) => w.lemmaId != null).toList();
              final known = counted.where(learn.isKnown).length;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LessonText(
                    'সূরা ${Quran.surah(widget.surah).nameBn} · আয়াত ${toBanglaDigits(_a)}',
                    size: 16,
                    color: p.muted,
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    child: TappableAyah(
                      words: words,
                      isKnown: learn.isKnown,
                      onTap: (w) => showWordSheet(context, w),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LessonText(
                    knownLine(known, counted.length),
                    size: 18,
                    weight: FontWeight.w700,
                    color: p.primary,
                    align: TextAlign.center,
                  ),
                  LessonText(
                    'যেকোনো শব্দে চাপ দিন: অর্থ, মূল অক্ষর, আর ‘শিখব’ বোতাম পাবেন।',
                    size: 16,
                    color: p.muted,
                    align: TextAlign.center,
                  ),
                  if (widget.to > widget.ayah) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _a > widget.ayah ? () => setState(() => _a--) : null,
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                            child: const Text('আগের আয়াত'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _a < widget.to ? () => setState(() => _a++) : null,
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                            child: const Text('পরের আয়াত'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => push(context, const LearnDashboardScreen()),
                    child: const Text('কুরআন বুঝি: পাঠ শুরু করুন'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ credits

/// /learn/credits
class LearnCreditsScreen extends StatelessWidget {
  const LearnCreditsScreen({super.key});

  static const fsrsLicense = '''MIT License

Copyright (c) 2022 Open Spaced Repetition

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('উৎস ও কৃতজ্ঞতা')),
      body: LearnGate(
        builder: (context, learn) => FutureBuilder(
          future: learn.content!.meta(),
          builder: (context, snap) {
            final m = snap.data ?? const <String, String>{};
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const LessonText(
                  'কুরআন বুঝি-র সব আরবি লেখা Tanzil-এর কুরআন থেকে হুবহু নেওয়া। শব্দের ব্যাকরণ '
                  'Quranic Arabic Corpus থেকে। বাংলা অর্থ ও ব্যাখ্যা আমাদের লেখা; শিক্ষক যাচাই না '
                  'করা পর্যন্ত সেগুলো ‘খসড়া’।',
                  size: 16,
                ),
                _CreditCard(
                  title: 'Tanzil.net',
                  what: 'কুরআনের আরবি লেখা (উসমানি লিপি)',
                  link: 'https://tanzil.net',
                  notice: m['tanzil_notice'] ?? '',
                ),
                _CreditCard(
                  title: 'Quranic Arabic Corpus (morphology v0.4)',
                  what: 'প্রতিটি শব্দের মূল, ধরন ও গঠন। © 2011 Kais Dukes, GNU General Public License',
                  link: 'https://corpus.quran.com',
                  notice: m['qac_notice'] ?? '',
                ),
                const _CreditCard(
                  title: 'EveryAyah.com',
                  what: 'আয়াতের তিলাওয়াত (অ্যাপের বাকি অংশের মতোই)',
                  link: 'https://everyayah.com',
                  notice: '',
                ),
                const _CreditCard(
                  title: 'FSRS (package:fsrs)',
                  what: 'কোন শব্দ কবে আবার রিভিউ করবেন, তার হিসাব',
                  link: 'https://github.com/open-spaced-repetition/dart-fsrs',
                  notice: fsrsLicense,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.title,
    required this.what,
    required this.link,
    required this.notice,
  });

  final String title;
  final String what;
  final String link;
  final String notice;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
            ),
            LessonText(what, size: 16),
            SelectableText(link, style: TextStyle(color: p.primary, fontSize: 15)),
            if (notice.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('লাইসেন্সের পূর্ণ লেখা', style: TextStyle(fontSize: 15)),
                children: [
                  SelectableText(
                    notice,
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: p.muted),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
