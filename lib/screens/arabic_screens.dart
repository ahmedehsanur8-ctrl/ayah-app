import 'package:flutter/material.dart';

import '../models/content.dart' show toBanglaDigits;
import '../services/arabic.dart';
import '../services/quran.dart';
import '../theme.dart';
import '../widgets/arabic_games.dart';
import '../widgets/pattern.dart';
import '../widgets/ui.dart';

// ------------------------------------------------------------------ home

/// সহজ আরবি: the four levels, the daily streak and the review.
class ArabicHomeScreen extends StatefulWidget {
  const ArabicHomeScreen({super.key});

  @override
  State<ArabicHomeScreen> createState() => _ArabicHomeScreenState();
}

class _ArabicHomeScreenState extends State<ArabicHomeScreen> {
  final _progress = ArabicProgress.instance;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_changed);
    ArabicCourse.load().then((_) => _changed());
  }

  @override
  void dispose() {
    _progress.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('সহজ আরবি')),
      body: !ArabicCourse.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                const _Hero(),
                if (_progress.dueItems().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    color: p.sand.background,
                    onTap: () => push(context, const ArabicReviewScreen()),
                    child: Row(
                      children: [
                        IconBubble(Icons.replay_rounded, tint: p.sand, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'আজকের রিভিশন',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: p.sand.foreground,
                                ),
                              ),
                              Text(
                                'আগে ভুল হওয়া ${toBanglaDigits(_progress.dueItems().length)}টি অক্ষর/শব্দ আবার দেখি',
                                style: TextStyle(color: p.sand.foreground, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.sand.foreground),
                      ],
                    ),
                  ),
                ],
                const SectionLabel('স্তর'),
                for (final level in ArabicCourse.levels) ...[
                  _LevelCard(level: level),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                Text(
                  'সব পাঠ, উদাহরণ ও অনুশীলন এই অ্যাপের জন্য নতুন করে লেখা। কুরআনের শব্দ ও আয়াত অ্যাপের '
                  'Tanzil কুরআন টেক্সট থেকে নেওয়া। অগ্রগতি শুধু এই ফোনে থাকে।',
                  style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pr = ArabicProgress.instance;
    final total = ArabicCourse.lessons.length;
    final done = pr.doneCount;
    final streak = pr.streak();
    final next = ArabicCourse.lessons[pr.nextIndex];
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusL),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.greenCard, p.greenCardDark],
          ),
        ),
        child: Stack(
          children: [
            const PatternLayer(color: Brand.gold, opacity: 0.07),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'বাংলা থেকে আরবি',
                              style: TextStyle(
                                color: p.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'কুরআন পড়তে শিখি',
                              style: titleStyle(p, size: 22).copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'أ ب ت',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: arabicFont, fontSize: 30, color: Brand.gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _stat(
                        Icons.local_fire_department_rounded,
                        '${toBanglaDigits(streak)} দিন',
                        'টানা',
                      ),
                      const SizedBox(width: 10),
                      _stat(Icons.star_rounded, toBanglaDigits(pr.totalStars), 'তারা'),
                      const SizedBox(width: 10),
                      _stat(
                        Icons.check_circle_outline_rounded,
                        '${toBanglaDigits(done)}/${toBanglaDigits(total)}',
                        'পাঠ',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.gold,
                      foregroundColor: Brand.greenDark,
                    ),
                    onPressed: () => push(context, LessonScreen(index: pr.nextIndex)),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      done == 0 ? 'প্রথম পাঠ শুরু করি' : 'চালিয়ে যাই: ${next.title}',
                      overflow: TextOverflow.ellipsis,
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

  Widget _stat(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Brand.gold, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(label, style: const TextStyle(color: Brand.gold, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level});

  final ArLevel level;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = [p.mint, p.sky, p.sand, p.lilac][(level.n - 1) % 4];
    final pr = ArabicProgress.instance;
    final total = ArabicCourse.lessons.length;
    return AppCard(
      onTap: level.ready ? () => push(context, const ArabicLevelScreen()) : null,
      child: Opacity(
        opacity: level.ready ? 1 : 0.7,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                toBanglaDigits(level.n),
                style: TextStyle(color: tint.foreground, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${toBanglaDigits(level.n)}. ${level.title}',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.text),
                  ),
                  Text(level.subtitle, style: TextStyle(fontSize: 13, color: p.muted, height: 1.4)),
                  if (level.ready) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : pr.doneCount / total,
                        minHeight: 6,
                        backgroundColor: p.surfaceSoft,
                        color: p.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (level.ready)
              Icon(Icons.chevron_right_rounded, color: p.muted)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: p.surfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'শীঘ্রই আসছে',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ lesson list

/// Level 1: the lessons, opening one by one.
class ArabicLevelScreen extends StatefulWidget {
  const ArabicLevelScreen({super.key});

  @override
  State<ArabicLevelScreen> createState() => _ArabicLevelScreenState();
}

class _ArabicLevelScreenState extends State<ArabicLevelScreen> {
  final _progress = ArabicProgress.instance;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_changed);
  }

  @override
  void dispose() {
    _progress.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lessons = ArabicCourse.lessons;
    return Scaffold(
      appBar: AppBar(title: const Text('১. পড়তে শিখি')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final l = lessons[i];
          final open = _progress.isUnlocked(i);
          final stars = _progress.starsOf(l.id);
          return AppCard(
            key: ValueKey('lesson-${l.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: open
                ? () => push(context, LessonScreen(index: i))
                : () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('আগের পাঠ শেষ করলে এই পাঠ খুলবে।')),
                    ),
            child: Opacity(
              opacity: open ? 1 : 0.55,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: stars > 0 ? p.greenCard : p.pill,
                      shape: BoxShape.circle,
                    ),
                    child: open
                        ? Text(
                            toBanglaDigits(l.n),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: stars > 0 ? Brand.gold : p.primary,
                            ),
                          )
                        : Icon(Icons.lock_outline_rounded, size: 18, color: p.muted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                        Text(
                          '${l.subtitle} · ${toBanglaDigits(l.minutes)} মিনিট',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  if (open) _Stars(stars, size: 17),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars(this.count, {this.size = 18});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < 3; k++)
          Icon(
            k < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: k < count ? const Color(0xFFD9A93A) : p.border,
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ lesson

/// One lesson: explanation, the letters or words to hear, then the games.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.index});

  final int index;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late ArLesson _lesson = ArabicCourse.lessons[widget.index];
  late int _index = widget.index;

  /// 0 = explanation, 1 = cards, then one step per game, then the result.
  int _step = 0;
  int _mistakes = 0;
  final _wrong = <String>{};
  int _stars = 0;

  int get _gameCount => _lesson.games.length;
  bool get _atResult => _step == 2 + _gameCount;

  @override
  void initState() {
    super.initState();
    if (_lesson.ayahs.isNotEmpty) {
      Future.wait([Quran.loadMeta(), Quran.load()]).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    ArabicAudio.stop();
    super.dispose();
  }

  void _gameDone(GameResult r) {
    _mistakes += r.mistakes;
    _wrong.addAll(r.wrong);
    setState(() => _step++);
    if (_atResult) _finish();
  }

  Future<void> _finish() async {
    _stars = ArabicProgress.starsFor(_mistakes);
    await ArabicProgress.instance.finishLesson(_lesson.id, _stars);
    await ArabicProgress.instance.markWrong(_wrong);
    if (mounted) setState(() {});
  }

  void _restart({int? index}) {
    ArabicAudio.stop();
    setState(() {
      if (index != null) {
        _index = index;
        _lesson = ArabicCourse.lessons[index];
      }
      _step = 0;
      _mistakes = 0;
      _wrong.clear();
      _stars = 0;
    });
    if (_lesson.ayahs.isNotEmpty) {
      Future.wait([Quran.loadMeta(), Quran.load()]).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = 3 + _gameCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'পাঠ ${toBanglaDigits(_lesson.n)}: ${_lesson.title}',
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_step + 1) / total,
                minHeight: 6,
                backgroundColor: p.surfaceSoft,
                color: p.primary,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: switch (_step) {
          0 => _intro(),
          1 => _cards(),
          _ when _atResult => _result(),
          _ => buildGame(_lesson.games[_step - 2], _gameDone),
        },
      ),
    );
  }

  Widget _intro() {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(_lesson.title, style: titleStyle(p, size: 24)),
        const SizedBox(height: 2),
        Text(
          _lesson.subtitle,
          textDirection: RegExp('[؀-ۿ]').hasMatch(_lesson.subtitle) ? TextDirection.rtl : null,
          style: TextStyle(
            color: p.goldText,
            fontSize: RegExp('[؀-ۿ]').hasMatch(_lesson.subtitle) ? 24 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final para in _lesson.intro)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(para, style: TextStyle(fontSize: 16, height: 1.65, color: p.text)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'সময় লাগবে প্রায় ${toBanglaDigits(_lesson.minutes)} মিনিট · ${toBanglaDigits(_gameCount)}টি অনুশীলন',
          style: TextStyle(color: p.muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('শুরু করি'),
        ),
      ],
    );
  }

  Widget _cards() {
    final p = context.palette;
    final items = [
      for (final id in _lesson.cards)
        if (ArabicCourse.item(id) != null) ArabicCourse.item(id)!,
    ];
    final forms = (_lesson.extra['forms'] as List?)?.cast<Map<String, dynamic>>();
    final signs = (_lesson.extra['signs'] as List?)?.cast<Map<String, dynamic>>();
    final big =
        items.isNotEmpty && items.first.kind == 'letter' && items.length <= 9 && forms == null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          _lesson.ayahs.isNotEmpty
              ? 'আয়াতে চাপ দিলে তিলাওয়াত শুনবে। প্রথমবার ইন্টারনেট লাগে।'
              : 'প্রতিটিতে চাপ দিয়ে দেখো ও শোনো, তারপর নিজে জোরে বলো।',
          style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 12),
        if (forms != null) ...[_FormsTable(forms: forms), const SizedBox(height: 14)],
        if (signs != null)
          for (final s in signs) ...[_SignCard(sign: s), const SizedBox(height: 10)],
        if (_lesson.ayahs.isNotEmpty)
          for (final ref in _lesson.ayahs) ...[_AyahCard(ref: ref), const SizedBox(height: 10)],
        if (signs == null && items.isNotEmpty)
          LayoutBuilder(
            builder: (context, c) {
              final cols = big ? 2 : (items.length > 12 ? 4 : 3);
              final w = (c.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final i in items)
                    SizedBox(
                      width: w,
                      child: _ItemCard(item: i, big: big),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => setState(() => _step = 2),
          icon: const Icon(Icons.sports_esports_outlined),
          label: const Text('অনুশীলন শুরু করি'),
        ),
      ],
    );
  }

  Widget _result() {
    final p = context.palette;
    final hasNext = _index + 1 < ArabicCourse.lessons.length;
    final msg = switch (_stars) {
      3 => 'মাশাআল্লাহ! দারুণ হয়েছে।',
      2 => 'খুব ভালো! আরেকবার করলে তিন তারা পাবে।',
      _ => 'শেষ করেছ! আরেকবার অনুশীলন করলে আরও সহজ লাগবে।',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 28),
      children: [
        Center(child: _Stars(_stars, size: 54)),
        const SizedBox(height: 14),
        Text(msg, textAlign: TextAlign.center, style: titleStyle(p, size: 21)),
        const SizedBox(height: 6),
        Text(
          _mistakes == 0 ? 'একটিও ভুল হয়নি।' : 'ভুল: ${toBanglaDigits(_mistakes)}টি',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted),
        ),
        if (_wrong.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppCard(
            color: p.sand.background,
            child: Column(
              children: [
                Text(
                  'এগুলো কাল রিভিশনে আবার আসবে:',
                  style: TextStyle(color: p.sand.foreground, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final id in _wrong.take(12))
                      if (ArabicCourse.item(id) != null)
                        ArText(ArabicCourse.item(id)!.ar, size: 26),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (hasNext)
          FilledButton.icon(
            onPressed: () => _restart(index: _index + 1),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('পরের পাঠ'),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _restart(),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('আবার করি'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('পাঠের তালিকা')),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, this.big = false});

  final ArItem item;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final long = item.ar.length > 5;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      onTap: () {
        if (ArabicAudio.has(item)) ArabicAudio.play(item);
        showItemSheet(context, item);
      },
      child: Column(
        children: [
          // Deep letters (ج ع) reach below the line; keep them off the label.
          Padding(
            padding: EdgeInsets.only(bottom: long ? 2 : 12),
            child: ArText(item.ar, size: big ? 64 : (long ? 24 : 34), height: long ? 1.8 : 2.0),
          ),
          Text(
            item.name ?? item.bn,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: big ? 15 : 12.5, fontWeight: FontWeight.w600, color: p.text),
          ),
          if (big || item.kind == 'word') ...[
            const SizedBox(height: 4),
            if (!ArabicAudio.has(item))
              AudioSoonLabel(compact: !big)
            else
              Icon(Icons.volume_up_rounded, size: 18, color: p.primary),
          ] else if (!ArabicAudio.has(item))
            Icon(Icons.volume_off_outlined, size: 14, color: p.muted),
        ],
      ),
    );
  }
}

/// Details of a letter or word: big, with its sound, tip and meaning.
void showItemSheet(BuildContext context, ArItem item) {
  final p = context.palette;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArText(item.ar, size: item.ar.length > 5 ? 54 : 90),
            Text(item.name ?? item.bn, style: titleStyle(p, size: 22)),
            if (item.name != null && item.kind == 'letter') ...[
              const SizedBox(height: 2),
              Text('নাম: ${item.name}', style: TextStyle(color: p.muted)),
            ] else if (item.kind != 'letter')
              Text('উচ্চারণ: ${item.bn}', style: TextStyle(color: p.muted)),
            if (item.meaning != null && item.meaning!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.kind == 'sign' ? item.meaning! : 'অর্থ: ${item.meaning}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: p.text, fontWeight: FontWeight.w600),
              ),
            ],
            if (item.tip != null) ...[
              const SizedBox(height: 10),
              Text(
                item.tip!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.6, color: p.text),
              ),
            ],
            if (item.ref != null) ...[
              const SizedBox(height: 8),
              Text(
                'কুরআনে: আয়াত ${refBn(item.ref!)}',
                style: TextStyle(color: p.goldText, fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            ItemSound(item, size: 52),
          ],
        ),
      ),
    ),
  );
}

class _FormsTable extends StatelessWidget {
  const _FormsTable({required this.forms});

  final List<Map<String, dynamic>> forms;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget head(String t) => Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: p.muted, fontWeight: FontWeight.w600),
      ),
    );
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        children: [
          Row(children: [head('একা'), head('শুরুতে'), head('মাঝে'), head('শেষে')]),
          for (final f in forms)
            Row(
              children: [
                for (final k in ['iso', 'ini', 'med', 'fin'])
                  Expanded(child: ArText(f[k] as String, size: 30)),
              ],
            ),
        ],
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  const _SignCard({required this.sign});

  final Map<String, dynamic> sign;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.pill, borderRadius: BorderRadius.circular(16)),
                child: ArText('ـ${sign['sign']}', size: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sign['name'] as String,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.text),
                    ),
                    Text(sign['rule'] as String, style: TextStyle(color: p.text, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ArText(sign['example'] as String, size: 22),
          Text(
            'উদাহরণ: আয়াত ${refBn(sign['ref'] as String)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.goldText, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard({required this.ref});

  final String ref;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final parts = ref.split(':');
    final s = int.parse(parts[0]), a = int.parse(parts[1]);
    final text = Quran.textLoaded ? Quran.displayArabic(s, a) : '';
    return AppCard(
      onTap: () => ArabicAudio.playAyah(ref),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.pill, shape: BoxShape.circle),
                child: Text(
                  toBanglaDigits(a),
                  style: TextStyle(color: p.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Icon(Icons.volume_up_rounded, size: 18, color: p.primary),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: text.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ArText(text, size: 26, align: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ review

/// Letters and words answered wrong earlier, asked again when they are due.
class ArabicReviewScreen extends StatefulWidget {
  const ArabicReviewScreen({super.key});

  @override
  State<ArabicReviewScreen> createState() => _ArabicReviewScreenState();
}

class _ArabicReviewScreenState extends State<ArabicReviewScreen> {
  late final List<String> _due = ArabicProgress.instance.dueItems().take(10).toList();
  late final List<Map<String, dynamic>> _games = _buildGames();
  int _step = 0;
  final _seen = <String>{};
  final _wrong = <String>{};
  bool _saved = false;

  List<Map<String, dynamic>> _buildGames() {
    final items = [
      for (final id in _due)
        if (ArabicCourse.item(id) != null) ArabicCourse.item(id)!,
    ];
    // Distractors of the same kind (letters with letters, words with words).
    final kinds = {for (final i in items) i.kind};
    final pool = [
      for (final i in ArabicCourse.items.values)
        if (kinds.contains(i.kind) && i.kind != 'sign' && i.kind != 'form') i.id,
    ];
    final withMeaning = [
      for (final i in items)
        if ((i.meaning ?? '').isNotEmpty && i.kind == 'word') i.id,
    ];
    return [
      if (items.isNotEmpty)
        {
          'type': 'listen',
          'items': [for (final i in items) i.id],
          'pool': pool,
          'rounds': items.length,
        },
      if (withMeaning.length >= 2) {'type': 'match', 'items': withMeaning, 'right': 'meaning'},
    ];
  }

  Future<void> _done(GameResult r) async {
    _seen.addAll(r.seen);
    _wrong.addAll(r.wrong);
    setState(() => _step++);
    if (_step >= _games.length && !_saved) {
      _saved = true;
      final pr = ArabicProgress.instance;
      await pr.markRight(_seen.difference(_wrong));
      await pr.markWrong(_wrong);
      await pr.practiced();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    ArabicAudio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final finished = _games.isEmpty || _step >= _games.length;
    return Scaffold(
      appBar: AppBar(title: const Text('রিভিশন')),
      body: finished
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 28),
              children: [
                Icon(Icons.task_alt_rounded, size: 64, color: p.primary),
                const SizedBox(height: 12),
                Text(
                  _games.isEmpty ? 'আজ রিভিশনের কিছু নেই।' : 'রিভিশন শেষ!',
                  textAlign: TextAlign.center,
                  style: titleStyle(p, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'ঠিক হলে শব্দটা কিছুদিন পরে আবার আসবে; কয়েকবার ঠিক হলে তালিকা থেকে বাদ যাবে।',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ফিরে যাই'),
                ),
              ],
            )
          : buildGame(_games[_step], _done),
    );
  }
}
