import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/content.dart' show toBanglaDigits;
import '../services/arabic.dart';
import '../services/audio.dart';
import '../services/quran.dart';
import '../theme.dart';

/// What a game reports when it ends.
class GameResult {
  int mistakes = 0;

  /// Items answered wrong at least once (they come back in the review).
  final Set<String> wrong = {};

  /// Items that were asked.
  final Set<String> seen = {};
}

typedef GameDone = void Function(GameResult result);

/// Title of each game type, shown above it.
String gameTitle(String type) => switch (type) {
  'listen' || 'listen_ayah' => 'শুনে বেছে নিন',
  'match' => 'মেলান',
  'arrange' => 'সাজান',
  'trace' => 'লিখে দেখুন',
  _ => 'বেছে নিন',
};

IconData gameIcon(String type) => switch (type) {
  'listen' || 'listen_ayah' => Icons.hearing_rounded,
  'match' => Icons.link_rounded,
  'arrange' => Icons.swap_horiz_rounded,
  'trace' => Icons.gesture_rounded,
  _ => Icons.help_outline_rounded,
};

/// Builds the game described by [config] (one entry of a lesson's "games").
Widget buildGame(Map<String, dynamic> config, GameDone onDone, {math.Random? random}) {
  List<ArItem> items(String key) => [
    for (final id in ((config[key] ?? const []) as List).cast<String>())
      if (ArabicCourse.item(id) != null) ArabicCourse.item(id)!,
  ];
  final type = config['type'] as String;
  return switch (type) {
    'listen' => ListenGame(
      key: UniqueKey(),
      items: items('items'),
      pool: items('pool'),
      rounds: (config['rounds'] ?? 6) as int,
      onDone: onDone,
      random: random,
    ),
    'match' => MatchGame(
      key: UniqueKey(),
      items: items('items'),
      right: (config['right'] ?? 'bn') as String,
      onDone: onDone,
      random: random,
    ),
    'arrange' => ArrangeGame(
      key: UniqueKey(),
      puzzles: (config['puzzles'] as List).cast<Map<String, dynamic>>(),
      hint: (config['hint'] ?? '') as String,
      onDone: onDone,
      random: random,
    ),
    'trace' => TraceGame(key: UniqueKey(), items: items('items'), onDone: onDone),
    'listen_ayah' => AyahListenGame(
      key: UniqueKey(),
      ayahs: (config['ayahs'] as List).cast<String>(),
      rounds: (config['rounds'] ?? 5) as int,
      onDone: onDone,
      random: random,
    ),
    _ => QuizGame(
      key: UniqueKey(),
      questions: (config['questions'] as List).cast<Map<String, dynamic>>(),
      onDone: onDone,
    ),
  };
}

// ------------------------------------------------------------------ shared

/// Arabic text, right to left, in the Quran font.
class ArText extends StatelessWidget {
  const ArText(
    this.text, {
    super.key,
    this.size = 34,
    this.color,
    this.align = TextAlign.center,
    this.height = 1.7,
  });

  final String text;
  final double size;
  final Color? color;
  final TextAlign align;

  /// Line height; deep letters (ج ع) need more room above a label.
  final double height;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textDirection: TextDirection.rtl,
    textAlign: align,
    style: TextStyle(
      fontFamily: arabicFont,
      fontSize: size,
      height: height,
      color: color ?? context.palette.arabic,
    ),
  );
}

/// "1:2" in Bangla digits.
String refBn(String ref) => ref.split(':').map(toBanglaDigits).join(':');

/// Small label shown where a qari recording is not added yet. [compact]
/// shows only the icon (for small cards).
class AudioSoonLabel extends StatelessWidget {
  const AudioSoonLabel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.palette.sand;
    return Tooltip(
      message: 'অডিও শীঘ্রই',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8, vertical: 3),
        decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_off_outlined, size: 13, color: t.foreground),
            if (!compact) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'অডিও শীঘ্রই',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.foreground),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Play button for an item, or the "audio soon" label.
class ItemSound extends StatelessWidget {
  const ItemSound(this.item, {super.key, this.size = 40});

  final ArItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!ArabicAudio.has(item)) return const AudioSoonLabel();
    final p = context.palette;
    return IconButton.filledTonal(
      tooltip: 'শুনুন',
      iconSize: size * 0.55,
      style: IconButton.styleFrom(backgroundColor: p.pill, foregroundColor: p.primary),
      onPressed: () => ArabicAudio.play(item),
      icon: const Icon(Icons.volume_up_rounded),
    );
  }
}

class _GameFrame extends StatelessWidget {
  const _GameFrame({
    required this.type,
    required this.instruction,
    required this.child,
    this.step,
    this.total,
  });

  final String type;
  final String instruction;
  final Widget child;
  final int? step;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Row(
          children: [
            Icon(gameIcon(type), color: p.goldText, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(gameTitle(type), style: titleStyle(p, size: 19))),
            if (step != null && total != null)
              Text(
                '${toBanglaDigits(step! + 1)}/${toBanglaDigits(total!)}',
                style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(instruction, style: TextStyle(color: p.muted, fontSize: 14, height: 1.5)),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

enum _Mark { none, right, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.child,
    required this.onTap,
    this.mark = _Mark.none,
    this.selected = false,
    this.minHeight = 76,
  });

  final Widget child;
  final VoidCallback? onTap;
  final _Mark mark;
  final bool selected;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, border) = switch (mark) {
      _Mark.right => (p.mint.background, p.mint.foreground),
      _Mark.wrong => (p.rose.background, p.rose.foreground),
      _Mark.none => (selected ? p.pill : p.surface, selected ? p.primary : p.border),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusM),
        side: BorderSide(color: border, width: mark == _Mark.none && !selected ? 1 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Center(
            child: Padding(padding: const EdgeInsets.all(8), child: child),
          ),
        ),
      ),
    );
  }
}

Widget _grid(List<Widget> children, {int columns = 2}) => LayoutBuilder(
  builder: (context, c) {
    const gap = 10.0;
    final w = (c.maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final ch in children) SizedBox(width: w, child: ch)],
    );
  },
);

/// Four answer options: the right one and three that look and sound different.
List<ArItem> _options(ArItem target, List<ArItem> pool, math.Random r, {int count = 4}) {
  final others = [
    for (final i in pool)
      if (i.ar != target.ar && i.bn != target.bn) i,
  ]..shuffle(r);
  final seen = <String>{target.bn};
  final picked = <ArItem>[];
  for (final o in others) {
    if (picked.length >= count - 1) break;
    if (seen.add(o.bn)) picked.add(o);
  }
  return [target, ...picked]..shuffle(r);
}

// ------------------------------------------------------------------ listen

/// শুনে বেছে নিন: hear a letter or word and tap it. Without a recording the
/// Bangla sound is shown instead.
class ListenGame extends StatefulWidget {
  const ListenGame({
    super.key,
    required this.items,
    required this.pool,
    required this.rounds,
    required this.onDone,
    this.random,
  });

  final List<ArItem> items;
  final List<ArItem> pool;
  final int rounds;
  final GameDone onDone;
  final math.Random? random;

  @override
  State<ListenGame> createState() => _ListenGameState();
}

class _ListenGameState extends State<ListenGame> {
  late final math.Random _r = widget.random ?? math.Random();
  final _result = GameResult();
  late final List<ArItem> _queue;
  final _retried = <String>{};
  int _i = 0;
  late List<ArItem> _opts;
  ArItem? _picked;

  @override
  void initState() {
    super.initState();
    final base = [...widget.items]..shuffle(_r);
    final n = base.isEmpty ? 0 : math.min(widget.rounds, base.length * 2);
    _queue = [for (var k = 0; k < n; k++) base[k % base.length]];
    if (_queue.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone(_result));
      return;
    }
    _load();
  }

  ArItem get _target => _queue[_i];

  void _load() {
    _picked = null;
    _opts = _options(_target, [...widget.pool, ...widget.items], _r);
    _result.seen.add(_target.id);
    if (ArabicAudio.has(_target)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ArabicAudio.play(_target);
      });
    }
  }

  void _tap(ArItem o) {
    if (_picked != null) return;
    setState(() => _picked = o);
    final right = o.ar == _target.ar;
    if (!right) {
      _result.mistakes++;
      _result.wrong.add(_target.id);
      if (_retried.add(_target.id)) _queue.add(_target);
    }
    Timer(Duration(milliseconds: right ? 650 : 1300), () {
      if (!mounted) return;
      if (_i + 1 >= _queue.length) {
        widget.onDone(_result);
      } else {
        setState(() {
          _i++;
          _load();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) return const SizedBox();
    final p = context.palette;
    final t = _target;
    final hasAudio = ArabicAudio.has(t);
    return _GameFrame(
      type: 'listen',
      instruction: hasAudio
          ? 'শুনুন, তারপর ঠিক অক্ষর বা শব্দে চাপ দিন।'
          : 'বাংলায় লেখা আওয়াজটা পড়ুন, তারপর ঠিক আরবিতে চাপ দিন।',
      step: _i,
      total: _queue.length,
      child: Column(
        children: [
          if (hasAudio)
            IconButton.filled(
              tooltip: 'আবার শুনুন',
              iconSize: 40,
              style: IconButton.styleFrom(
                backgroundColor: p.greenCard,
                foregroundColor: p.gold,
                minimumSize: const Size(88, 88),
              ),
              onPressed: () => ArabicAudio.play(t),
              icon: const Icon(Icons.volume_up_rounded),
            )
          else ...[
            Text('"${t.bn}"', key: const ValueKey('listen-prompt'), style: titleStyle(p, size: 30)),
            if (t.meaning != null && t.kind == 'word')
              Text(t.meaning!, style: TextStyle(color: p.muted)),
            const SizedBox(height: 6),
            const AudioSoonLabel(),
          ],
          const SizedBox(height: 20),
          _grid([
            for (final o in _opts)
              _OptionTile(
                mark: _picked == null
                    ? _Mark.none
                    : (o.ar == t.ar ? _Mark.right : (o == _picked ? _Mark.wrong : _Mark.none)),
                onTap: () => _tap(o),
                child: ArText(o.ar, size: o.ar.length > 6 ? 30 : 40),
              ),
          ]),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ ayah listen

/// শুনে বেছে নিন for surahs: hear an ayah, pick its text.
class AyahListenGame extends StatefulWidget {
  const AyahListenGame({
    super.key,
    required this.ayahs,
    required this.rounds,
    required this.onDone,
    this.random,
  });

  final List<String> ayahs;
  final int rounds;
  final GameDone onDone;
  final math.Random? random;

  @override
  State<AyahListenGame> createState() => _AyahListenGameState();
}

class _AyahListenGameState extends State<AyahListenGame> {
  late final math.Random _r = widget.random ?? math.Random();
  final _result = GameResult();
  late final List<String> _queue;
  int _i = 0;
  late List<String> _opts;
  String? _picked;
  late int _problems = AudioController.instance.problemCount;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _queue = ([...widget.ayahs]..shuffle(_r)).take(widget.rounds).toList();
    AudioController.instance.addListener(_audioChanged);
    _load();
  }

  @override
  void dispose() {
    AudioController.instance.removeListener(_audioChanged);
    super.dispose();
  }

  void _audioChanged() {
    final a = AudioController.instance;
    if (a.problemCount != _problems) {
      _problems = a.problemCount;
      if (a.problem == AudioProblem.offline && mounted) setState(() => _offline = true);
    }
  }

  static String _text(String ref) {
    final p = ref.split(':');
    return Quran.textLoaded ? Quran.displayArabic(int.parse(p[0]), int.parse(p[1])) : ref;
  }

  static String _label(String ref) {
    final p = ref.split(':');
    final s = int.parse(p[0]);
    final name = Quran.metaLoaded ? Quran.surah(s).nameBn : '';
    return 'সূরা $name, আয়াত ${toBanglaDigits(p[1])}';
  }

  void _load() {
    _picked = null;
    final t = _queue[_i];
    final surah = t.split(':')[0];
    final same = [
      for (final a in widget.ayahs)
        if (a != t && a.startsWith('$surah:')) a,
    ]..shuffle(_r);
    final other = [
      for (final a in widget.ayahs)
        if (a != t && !same.contains(a)) a,
    ]..shuffle(_r);
    _opts = [
      t,
      ...[...same, ...other].take(2),
    ]..shuffle(_r);
    _result.seen.add(t);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_offline) ArabicAudio.playAyah(t);
    });
  }

  void _tap(String o) {
    if (_picked != null) return;
    setState(() => _picked = o);
    final right = o == _queue[_i];
    if (!right) _result.mistakes++;
    Timer(Duration(milliseconds: right ? 800 : 1500), () {
      if (!mounted) return;
      if (_i + 1 >= _queue.length) {
        ArabicAudio.stop();
        widget.onDone(_result);
      } else {
        setState(() {
          _i++;
          _load();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = _queue[_i];
    return _GameFrame(
      type: 'listen_ayah',
      instruction: _offline
          ? 'তিলাওয়াত চালাতে ইন্টারনেট লাগবে। এখন নিচের নাম দেখে আয়াতটি বেছে নিন।'
          : 'ক্বারীর তিলাওয়াত শুনুন, তারপর সেই আয়াতে চাপ দিন।',
      step: _i,
      total: _queue.length,
      child: Column(
        children: [
          IconButton.filled(
            tooltip: 'আবার শুনুন',
            iconSize: 40,
            style: IconButton.styleFrom(
              backgroundColor: p.greenCard,
              foregroundColor: p.gold,
              minimumSize: const Size(88, 88),
            ),
            onPressed: () => ArabicAudio.playAyah(t),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          if (_offline) ...[
            const SizedBox(height: 8),
            Text(_label(t), style: titleStyle(p, size: 18)),
          ],
          const SizedBox(height: 16),
          for (final o in _opts) ...[
            _OptionTile(
              minHeight: 64,
              mark: _picked == null
                  ? _Mark.none
                  : (o == t ? _Mark.right : (o == _picked ? _Mark.wrong : _Mark.none)),
              onTap: () => _tap(o),
              child: ArText(_text(o), size: 25),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ match

/// মেলান: pair each Arabic tile with its sound, name or meaning.
class MatchGame extends StatefulWidget {
  const MatchGame({
    super.key,
    required this.items,
    required this.right,
    required this.onDone,
    this.random,
  });

  final List<ArItem> items;

  /// Which text goes in the right column: bn, name, meaning or form:med.
  final String right;
  final GameDone onDone;
  final math.Random? random;

  @override
  State<MatchGame> createState() => _MatchGameState();
}

class _MatchGameState extends State<MatchGame> {
  late final math.Random _r = widget.random ?? math.Random();
  final _result = GameResult();
  late final List<List<ArItem>> _rounds;
  int _round = 0;
  late List<ArItem> _left, _rightCol;
  final _matched = <String>{};
  ArItem? _selL, _selR;
  ArItem? _badL, _badR;

  @override
  void initState() {
    super.initState();
    final all = [...widget.items]..shuffle(_r);
    final n = math.min(all.length, 10);
    final per = n <= 5 ? n : (n / 2).ceil();
    _rounds = [for (var i = 0; i < n; i += per) all.sublist(i, math.min(i + per, n))];
    _load();
  }

  void _load() {
    _matched.clear();
    _left = [..._rounds[_round]]..shuffle(_r);
    _rightCol = [..._rounds[_round]]..shuffle(_r);
    for (final i in _left) {
      _result.seen.add(i.id);
    }
  }

  bool get _arRight => widget.right.startsWith('form');

  void _pick({ArItem? l, ArItem? r}) {
    if (l != null) {
      if (_matched.contains(l.id)) return;
      _selL = l;
      if (ArabicAudio.has(l)) ArabicAudio.play(l);
    }
    if (r != null) {
      if (_matched.contains(r.id)) return;
      _selR = r;
    }
    if (_selL != null && _selR != null) {
      if (_selL!.id == _selR!.id) {
        _matched.add(_selL!.id);
        _selL = _selR = null;
        if (_matched.length == _left.length) {
          Timer(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            if (_round + 1 >= _rounds.length) {
              widget.onDone(_result);
            } else {
              setState(() {
                _round++;
                _load();
              });
            }
          });
        }
      } else {
        _result.mistakes++;
        _result.wrong.add(_selL!.id);
        _badL = _selL;
        _badR = _selR;
        _selL = _selR = null;
        Timer(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _badL = _badR = null);
        });
      }
    }
    setState(() {});
  }

  _Mark _mark(ArItem i, ArItem? bad) =>
      _matched.contains(i.id) ? _Mark.right : (i == bad ? _Mark.wrong : _Mark.none);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final what = switch (widget.right) {
      'meaning' => 'অর্থ',
      'name' => 'নাম',
      'form:med' => 'মাঝের রূপ',
      _ => 'আওয়াজ',
    };
    return _GameFrame(
      type: 'match',
      instruction: 'বাঁ দিকের আরবির সাথে ডান দিকের $what মেলান। একটায় চাপ দিন, তারপর তার জোড়ায়।',
      step: _rounds.length > 1 ? _round : null,
      total: _rounds.length > 1 ? _rounds.length : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (final i in _left) ...[
                  _OptionTile(
                    minHeight: 64,
                    mark: _mark(i, _badL),
                    selected: _selL == i,
                    onTap: () => _pick(l: i),
                    child: ArText(i.ar, size: i.ar.length > 6 ? 24 : 32),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (final i in _rightCol) ...[
                  _OptionTile(
                    minHeight: 64,
                    mark: _mark(i, _badR),
                    selected: _selR == i,
                    onTap: () => _pick(r: i),
                    child: _arRight
                        ? ArText(i.field(widget.right), size: 32)
                        : Text(
                            i.field(widget.right),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                              height: 1.35,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ arrange

/// সাজান: put letters (or words of an ayah) in order, right to left.
class ArrangeGame extends StatefulWidget {
  const ArrangeGame({
    super.key,
    required this.puzzles,
    required this.hint,
    required this.onDone,
    this.random,
  });

  final List<Map<String, dynamic>> puzzles;
  final String hint;
  final GameDone onDone;
  final math.Random? random;

  @override
  State<ArrangeGame> createState() => _ArrangeGameState();
}

class _ArrangeGameState extends State<ArrangeGame> {
  late final math.Random _r = widget.random ?? math.Random();
  final _result = GameResult();
  int _i = 0;
  late List<String> _parts;
  late List<int> _pool;
  late List<int?> _slots;
  bool _solved = false;
  final _bad = <int>{};

  Map<String, dynamic> get _puzzle => widget.puzzles[_i];
  ArItem? get _item =>
      _puzzle['item'] == null ? null : ArabicCourse.item(_puzzle['item'] as String);
  bool get _isAyah => _puzzle['ref'] != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _parts = (_puzzle['parts'] as List).cast<String>();
    _pool = List.generate(_parts.length, (i) => i);
    // Shuffle so that the tiles are not already in order.
    for (var k = 0; k < 10; k++) {
      _pool.shuffle(_r);
      if (!_inOrder(_pool)) break;
    }
    _slots = List.filled(_parts.length, null);
    _solved = false;
    _bad.clear();
    final id = _item?.id;
    if (id != null) _result.seen.add(id);
  }

  bool _inOrder(List<int> l) {
    for (var k = 0; k < l.length; k++) {
      if (_parts[l[k]] != _parts[k]) return false;
    }
    return true;
  }

  void _place(int tile, [int? slot]) {
    if (_solved) return;
    final target = slot ?? _slots.indexOf(null);
    if (target < 0) return;
    setState(() {
      // A tile dropped on a full slot swaps with the tile there.
      final old = _slots[target];
      final from = _slots.indexOf(tile);
      if (from >= 0) _slots[from] = old;
      if (from < 0) {
        _pool.remove(tile);
        if (old != null) _pool.add(old);
      }
      _slots[target] = tile;
    });
    if (!_slots.contains(null)) _check();
  }

  void _takeBack(int slot) {
    if (_solved || _slots[slot] == null) return;
    setState(() {
      _pool.add(_slots[slot]!);
      _slots[slot] = null;
    });
  }

  void _check() {
    final wrong = <int>{
      for (var k = 0; k < _slots.length; k++)
        if (_parts[_slots[k]!] != _parts[k]) k,
    };
    if (wrong.isEmpty) {
      setState(() => _solved = true);
      return;
    }
    _result.mistakes++;
    final id = _item?.id;
    if (id != null) _result.wrong.add(id);
    setState(() => _bad.addAll(wrong));
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        for (final k in wrong) {
          _pool.add(_slots[k]!);
          _slots[k] = null;
        }
        _bad.clear();
      });
    });
  }

  void _next() {
    if (_i + 1 >= widget.puzzles.length) {
      widget.onDone(_result);
    } else {
      setState(() {
        _i++;
        _load();
      });
    }
  }

  double get _size => _isAyah ? 24 : 32;

  Widget _tile(int i, {bool ghost = false}) {
    final p = context.palette;
    return Container(
      constraints: BoxConstraints(minWidth: _isAyah ? 56 : 58, minHeight: _isAyah ? 56 : 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: ghost ? p.surfaceSoft : p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1.5),
      ),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: ArText(_parts[i], size: _size, color: ghost ? p.muted : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = _item;
    return _GameFrame(
      type: 'arrange',
      instruction: widget.hint.isEmpty ? 'টুকরোগুলো ঠিক ক্রমে সাজান।' : widget.hint,
      step: _i,
      total: widget.puzzles.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item != null && item.kind == 'word' && !_solved)
            Center(
              child: Text(
                '${item.bn}${item.meaning != null ? ' · ${item.meaning}' : ''}',
                style: TextStyle(color: p.muted, fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ),
          if (_isAyah && !_solved)
            Center(
              child: Text(
                'আয়াত ${refBn(_puzzle['ref'] as String)}',
                style: TextStyle(color: p.muted),
              ),
            ),
          const SizedBox(height: 10),
          // Answer row, filled from the right.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _solved ? p.mint.background : p.surfaceSoft,
              borderRadius: BorderRadius.circular(radiusM),
              border: Border.all(color: _solved ? p.mint.foreground : p.border),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var k = 0; k < _slots.length; k++)
                    DragTarget<int>(
                      onAcceptWithDetails: (d) => _place(d.data, k),
                      builder: (context, candidate, _) {
                        final t = _slots[k];
                        final bad = _bad.contains(k);
                        return GestureDetector(
                          onTap: () => _takeBack(k),
                          child: t == null
                              ? Container(
                                  key: ValueKey('slot-$k'),
                                  width: _isAyah ? 64 : 58,
                                  height: _isAyah ? 56 : 64,
                                  decoration: BoxDecoration(
                                    color: candidate.isNotEmpty ? p.pill : p.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: p.primary.withValues(alpha: 0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                )
                              : Container(
                                  key: ValueKey('slot-$k'),
                                  foregroundDecoration: bad
                                      ? BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: p.rose.foreground, width: 2.5),
                                        )
                                      : null,
                                  child: _tile(t),
                                ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_solved) ...[
            if (item != null && item.kind == 'word') ...[
              ArText(item.ar, size: 48),
              Text(
                '${item.bn}${item.meaning != null ? ' — ${item.meaning}' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ] else
              Text(
                'ঠিক হয়েছে!',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.primary, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _next,
              child: Text(_i + 1 >= widget.puzzles.length ? 'শেষ' : 'পরেরটি'),
            ),
          ] else
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in _pool)
                    Draggable<int>(
                      key: ValueKey('tile-$t'),
                      data: t,
                      feedback: Material(color: Colors.transparent, child: _tile(t)),
                      childWhenDragging: _tile(t, ghost: true),
                      child: GestureDetector(onTap: () => _place(t), child: _tile(t)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ quiz

/// Multiple choice questions with a short explanation.
class QuizGame extends StatefulWidget {
  const QuizGame({super.key, required this.questions, required this.onDone});

  final List<Map<String, dynamic>> questions;
  final GameDone onDone;

  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  final _result = GameResult();
  int _i = 0;
  int? _picked;
  late List<int> _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> get _q => widget.questions[_i];

  void _load() {
    _picked = null;
    _order = List.generate((_q['options'] as List).length, (i) => i)..shuffle();
  }

  void _tap(int o) {
    if (_picked != null) return;
    setState(() => _picked = o);
    if (o != _q['answer']) _result.mistakes++;
  }

  void _next() {
    if (_i + 1 >= widget.questions.length) {
      widget.onDone(_result);
    } else {
      setState(() {
        _i++;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _q;
    final options = (q['options'] as List).cast<String>();
    final optionsAr = (q['optionsAr'] ?? true) as bool;
    final answer = q['answer'] as int;
    final explain = (q['explain'] ?? '') as String;
    return _GameFrame(
      type: 'quiz',
      instruction: 'ঠিক উত্তরে চাপ দিন।',
      step: _i,
      total: widget.questions.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q['q'] as String, textAlign: TextAlign.center, style: titleStyle(p, size: 19)),
          if ((q['ar'] ?? '') != '') ArText(q['ar'] as String, size: 46),
          const SizedBox(height: 14),
          if (optionsAr)
            _grid([
              for (final o in _order)
                _OptionTile(
                  mark: _picked == null
                      ? _Mark.none
                      : (o == answer ? _Mark.right : (o == _picked ? _Mark.wrong : _Mark.none)),
                  onTap: () => _tap(o),
                  child: ArText(options[o], size: options[o].length > 6 ? 26 : 36),
                ),
            ])
          else
            for (final o in _order) ...[
              _OptionTile(
                minHeight: 56,
                mark: _picked == null
                    ? _Mark.none
                    : (o == answer ? _Mark.right : (o == _picked ? _Mark.wrong : _Mark.none)),
                onTap: () => _tap(o),
                child: Text(
                  options[o],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
              const SizedBox(height: 10),
            ],
          if (_picked != null) ...[
            const SizedBox(height: 14),
            Text(
              _picked == answer ? 'ঠিক!' : 'ঠিক উত্তর সবুজ করে দেখানো হলো।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _picked == answer ? p.primary : p.rose.foreground,
              ),
            ),
            if (explain.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  explain,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted),
                ),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _next,
              child: Text(_i + 1 >= widget.questions.length ? 'শেষ' : 'পরের প্রশ্ন'),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ trace

/// Where a letter is drawn on the trace board. The same layout is used for
/// the faint letter and for checking the strokes.
TextPainter _glyph(String ch, double box, Color color) => TextPainter(
  text: TextSpan(
    text: ch,
    style: TextStyle(fontFamily: arabicFont, fontSize: box * 0.6, color: color, height: 1.2),
  ),
  textDirection: TextDirection.rtl,
)..layout();

Offset _glyphOffset(TextPainter tp, double box) =>
    Offset((box - tp.width) / 2, (box - tp.height) / 2);

/// Cells of a [grid]x[grid] map of the board that the letter covers.
Future<List<bool>> letterMask(String ch, double box, {int grid = 48}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(grid / box);
  final tp = _glyph(ch, box, Colors.black);
  tp.paint(c, _glyphOffset(tp, box));
  final img = await rec.endRecording().toImage(grid, grid);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  if (data == null) return List.filled(grid * grid, false);
  return [for (var i = 0; i < grid * grid; i++) data.getUint8(i * 4 + 3) > 60];
}

/// Scores strokes against a letter: the share of stroke points on the
/// letter, and the share of the letter touched by the strokes.
({double accuracy, double coverage}) scoreTrace(
  List<bool> mask,
  List<List<Offset>> strokes,
  double box, {
  int grid = 48,
}) {
  final cell = box / grid;
  // Points every few pixels along each stroke.
  final pts = <Offset>[];
  for (final s in strokes) {
    for (var k = 0; k < s.length; k++) {
      if (k == 0) {
        pts.add(s[k]);
        continue;
      }
      final a = s[k - 1], b = s[k];
      final steps = math.max(1, ((b - a).distance / (cell / 2)).ceil());
      for (var j = 1; j <= steps; j++) {
        pts.add(Offset.lerp(a, b, j / steps)!);
      }
    }
  }
  final glyph = <int>{
    for (var i = 0; i < mask.length; i++)
      if (mask[i]) i,
  };
  if (glyph.isEmpty) return (accuracy: 1, coverage: 1);
  if (pts.isEmpty) return (accuracy: 0, coverage: 0);
  bool near(int cx, int cy, int r, bool Function(int) hit) {
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        final x = cx + dx, y = cy + dy;
        if (x < 0 || y < 0 || x >= grid || y >= grid) continue;
        if (hit(y * grid + x)) return true;
      }
    }
    return false;
  }

  var onLetter = 0;
  final painted = <int>{};
  for (final pt in pts) {
    final cx = (pt.dx / cell).floor(), cy = (pt.dy / cell).floor();
    if (near(cx, cy, 2, glyph.contains)) onLetter++;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final x = cx + dx, y = cy + dy;
        if (x >= 0 && y >= 0 && x < grid && y < grid) painted.add(y * grid + x);
      }
    }
  }
  final covered = glyph.where(painted.contains).length;
  return (accuracy: onLetter / pts.length, coverage: covered / glyph.length);
}

/// লিখে দেখুন: trace a letter with a finger over its faint shape.
class TraceGame extends StatefulWidget {
  const TraceGame({super.key, required this.items, required this.onDone});

  final List<ArItem> items;
  final GameDone onDone;

  @override
  State<TraceGame> createState() => _TraceGameState();
}

class _TraceGameState extends State<TraceGame> {
  final _result = GameResult();
  int _i = 0;
  final _strokes = <List<Offset>>[];
  int _fails = 0;
  String? _message;
  bool _passed = false;
  double _box = 280;

  ArItem get _item => widget.items[_i];

  Future<void> _check() async {
    if (_strokes.isEmpty) {
      setState(() => _message = 'আগে আঙুল দিয়ে অক্ষরটির ওপর দিয়ে টানুন।');
      return;
    }
    final mask = await letterMask(_item.ar, _box);
    final s = scoreTrace(mask, _strokes, _box);
    if (!mounted) return;
    _result.seen.add(_item.id);
    if (s.accuracy >= 0.7 && s.coverage >= 0.5) {
      setState(() {
        _passed = true;
        _message = 'চমৎকার!';
      });
    } else {
      _result.mistakes++;
      _result.wrong.add(_item.id);
      setState(() {
        _fails++;
        _strokes.clear();
        _message = s.coverage < 0.5
            ? 'পুরো অক্ষরটা ঢেকে দিন, ফোঁটাসহ। আবার চেষ্টা করুন।'
            : 'দাগের বাইরে চলে গেছে। হালকা অক্ষরের ওপর দিয়েই টানুন।';
      });
    }
  }

  void _next() {
    if (_i + 1 >= widget.items.length) {
      widget.onDone(_result);
    } else {
      setState(() {
        _i++;
        _strokes.clear();
        _fails = 0;
        _passed = false;
        _message = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = _item;
    return _GameFrame(
      type: 'trace',
      instruction: 'হালকা অক্ষরের ওপর দিয়ে আঙুল টেনে লিখুন। লেখা ডান থেকে শুরু হয়।',
      step: _i,
      total: widget.items.length,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.name ?? item.bn, style: titleStyle(p, size: 20)),
              const SizedBox(width: 10),
              ItemSound(item, size: 38),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              _box = math.min(c.maxWidth, 320);
              return Container(
                width: _box,
                height: _box,
                decoration: BoxDecoration(
                  color: _passed ? p.mint.background : p.surface,
                  borderRadius: BorderRadius.circular(radiusL),
                  border: Border.all(color: _passed ? p.mint.foreground : p.border, width: 1.5),
                ),
                child: GestureDetector(
                  key: const ValueKey('trace-board'),
                  onPanStart: _passed
                      ? null
                      : (d) => setState(() => _strokes.add([d.localPosition])),
                  onPanUpdate: _passed
                      ? null
                      : (d) => setState(() => _strokes.last.add(d.localPosition)),
                  child: CustomPaint(
                    size: Size(_box, _box),
                    painter: _TracePainter(
                      letter: item.ar,
                      strokes: _strokes,
                      guide: p.isDark
                          ? p.gold.withValues(alpha: 0.33)
                          : p.primary.withValues(alpha: 0.2),
                      ink: p.primary,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (_message != null)
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _passed ? p.primary : p.rose.foreground,
              ),
            ),
          const SizedBox(height: 12),
          if (_passed)
            FilledButton(
              onPressed: _next,
              child: Text(_i + 1 >= widget.items.length ? 'শেষ' : 'পরের অক্ষর'),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _strokes.clear();
                    _message = null;
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('মুছে ফেলুন'),
                ),
                FilledButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('হয়ে গেছে'),
                ),
                if (_fails >= 2) TextButton(onPressed: _next, child: const Text('পরের অক্ষরে যাই')),
              ],
            ),
        ],
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.letter,
    required this.strokes,
    required this.guide,
    required this.ink,
  });

  final String letter;
  final List<List<Offset>> strokes;
  final Color guide;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = _glyph(letter, size.width, guide);
    tp.paint(canvas, _glyphOffset(tp, size.width));
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final pt in s.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}
