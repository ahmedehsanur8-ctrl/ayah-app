import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/audio.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/audio_button.dart';
import '../widgets/item_view.dart';
import '../widgets/share_card.dart';

/// One reader for ayahs, hadiths, moods and topics: swipe between items,
/// with a green player at the bottom.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.items,
    this.index = 0,
    this.title = '',
    this.playAll = false,
  });

  final List<ContentItem> items;
  final int index;

  /// Shown in the top bar (mood or topic name). Defaults to the item's category.
  final String title;

  /// Start playing at once and continue with the next item ("সব শুনুন").
  final bool playAll;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _audio = AudioController.instance;
  late final PageController _pages = PageController(initialPage: widget.index);
  late int _index = widget.index;
  late bool _autoNext = widget.playAll;
  bool _repeat = false;
  int _seenProblems = AudioController.instance.problemCount;

  ContentItem get _item => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _audio.addListener(_onAudio);
    if (widget.playAll) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudio);
    if (widget.items.any((i) => i.id == _audio.currentId)) _audio.stop();
    _pages.dispose();
    super.dispose();
  }

  void _onAudio() {
    if (!mounted) return;
    if (_audio.problemCount != _seenProblems) {
      _seenProblems = _audio.problemCount;
      if (_audio.problem == AudioProblem.offline) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('আরবি তিলাওয়াত প্রথমবার শুনতে ইন্টারনেট সংযোগ দরকার।')),
          );
      } else if (_audio.problem == AudioProblem.noBanglaVoice) {
        showNoBanglaVoiceDialog(context);
      }
    }
    setState(() {});
  }

  /// Plays the current item; then repeats it or moves on, as chosen.
  Future<void> _play() async {
    final item = _item;
    final finished = await _audio.playItem(item);
    if (!finished || !mounted || _item.id != item.id) return;
    if (_repeat) return _play();
    if (_autoNext && _index < widget.items.length - 1) {
      await _go(_index + 1, play: true);
    }
  }

  /// Set when the page is changed by a button, so the new page starts playing.
  bool _playOnArrive = false;

  Future<void> _go(int i, {bool play = false}) async {
    if (i < 0 || i >= widget.items.length) return;
    _playOnArrive = play || _audio.isActive(_item.id);
    await _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) {
    final play = _playOnArrive || _audio.isActive(_item.id);
    _playOnArrive = false;
    setState(() => _index = i);
    if (play) unawaited(_play());
  }

  Future<void> _togglePlay() async {
    final id = _item.id;
    if (_audio.currentId == id && _audio.status == AudioStatus.paused) return _audio.resume();
    if (_audio.isActive(id)) return _audio.pause();
    await _play();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final n = widget.items.length;
    final title = widget.title.isNotEmpty ? widget.title : _item.category;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'ফিরে যান',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          title.isEmpty ? (_item.isAyah ? 'আয়াত' : 'হাদিস') : title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        Text(
                          '${toBanglaDigits(_index + 1)} / ${toBanglaDigits(n)}',
                          style: TextStyle(fontSize: 14, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'লেখার আকার',
                    icon: const Icon(Icons.format_size_rounded),
                    onPressed: () => showTextSizeSheet(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_index + 1) / n,
                  minHeight: 3,
                  backgroundColor: p.border,
                  color: p.primary,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: n,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, i) => _ReaderPage(item: widget.items[i]),
              ),
            ),
            _Player(
              item: _item,
              repeat: _repeat,
              hasPrev: _index > 0,
              hasNext: _index < n - 1,
              onPlay: _togglePlay,
              onPrev: () => _go(_index - 1),
              onNext: () => _go(_index + 1),
              onRepeat: () => setState(() => _repeat = !_repeat),
              onAutoNext: n > 1 ? () => setState(() => _autoNext = !_autoNext) : null,
              autoNext: _autoNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderPage extends StatelessWidget {
  const _ReaderPage({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = AppState.instance.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Center(child: CategoryChip(item)),
        const SizedBox(height: 18),
        ArabicText(item.arabic, size: item.isAyah ? 30 : 23),
        OrnamentDivider(color: p.goldText),
        BanglaText(item.bangla, size: 18),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(color: p.goldText, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BanglaText(item.title, size: 14.5, color: p.primary, weight: FontWeight.w700),
                  if (!item.isAyah && item.subtitle.isNotEmpty)
                    BanglaText(item.subtitle, size: 12.5, color: p.muted),
                ],
              ),
            ),
          ],
        ),
        if (item.gradeCheck) ...[const SizedBox(height: 10), const GradeCheckBadge()],
        if (item.placeholder)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: BanglaText(
              'কিছু লেখা ডাউনলোড করা যায়নি।',
              size: 14,
              color: context.palette.heart,
            ),
          ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (item.note.trim().isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => showNoteSheet(context, item),
                icon: const Icon(Icons.notes_rounded, size: 20),
                label: Text(item.isAyah ? 'টীকা দেখুন' : 'ব্যাখ্যা দেখুন'),
              ),
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                final fav = settings.isFavorite(item.id);
                return OutlinedButton.icon(
                  onPressed: () => settings.toggleFavorite(item.id),
                  icon: Icon(
                    fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                    color: fav ? p.heart : null,
                  ),
                  label: const Text('প্রিয়'),
                );
              },
            ),
            OutlinedButton.icon(
              onPressed: () => showShareSheet(context, item),
              icon: const Icon(Icons.image_outlined, size: 20),
              label: const Text('ছবি করে শেয়ার'),
            ),
          ],
        ),
      ],
    );
  }
}

/// "গ্রেড: আলেমের যাচাই প্রয়োজন" for hadiths marked (H) in the mood list.
class GradeCheckBadge extends StatelessWidget {
  const GradeCheckBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.palette.sand;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: t.foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'গ্রেড: আলেমের যাচাই প্রয়োজন (grade needs scholar check)',
                style: TextStyle(fontSize: 14, color: t.foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footnotes (ayah) or explanation (hadith) in a bottom sheet.
Future<void> showNoteSheet(BuildContext context, ContentItem item) {
  final p = context.palette;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(
            item.isAyah ? 'টীকা · আবু বকর যাকারিয়া' : 'সংক্ষিপ্ত ব্যাখ্যা · হাদিসএনসি',
            style: titleStyle(p, size: 18),
          ),
          const SizedBox(height: 4),
          Text(item.title, style: TextStyle(color: p.muted, fontSize: 14)),
          const SizedBox(height: 14),
          BanglaText(item.note.trim(), size: 16),
        ],
      ),
    ),
  );
}

/// Slider for the reading text size.
Future<void> showTextSizeSheet(BuildContext context) {
  final settings = AppState.instance.settings;
  return showModalBottomSheet(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final p = context.palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('লেখার আকার', style: titleStyle(p, size: 18)),
              Row(
                children: [
                  Text('অ', style: TextStyle(fontSize: 14, color: p.muted)),
                  Expanded(
                    child: Slider(
                      value: settings.textScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      label: '${toBanglaDigits((settings.textScale * 100).round())}%',
                      onChanged: settings.setTextScale,
                    ),
                  ),
                  Text('অ', style: TextStyle(fontSize: 24, color: p.muted)),
                ],
              ),
              const BanglaText('নমুনা: আল্লাহর রহমত থেকে নিরাশ হয়ো না।'),
            ],
          ),
        );
      },
    ),
  );
}

String _mmss(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return toBanglaDigits('$m:$s');
}

String speedLabel(double v) => '${toBanglaDigits(v.toString().replaceAll(RegExp(r'\.0$'), ''))}x';

/// The green player: reciter, progress, speed, prev / play-pause / next, repeat.
class _Player extends StatelessWidget {
  const _Player({
    required this.item,
    required this.repeat,
    required this.hasPrev,
    required this.hasNext,
    required this.onPlay,
    required this.onPrev,
    required this.onNext,
    required this.onRepeat,
    required this.onAutoNext,
    required this.autoNext,
  });

  final ContentItem item;
  final bool repeat;
  final bool hasPrev;
  final bool hasNext;
  final bool autoNext;
  final VoidCallback onPlay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onRepeat;
  final VoidCallback? onAutoNext;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final audio = AudioController.instance;
    final settings = AppState.instance.settings;
    final mine = audio.currentId == item.id;
    final status = mine ? audio.status : AudioStatus.idle;
    final playing =
        status == AudioStatus.playing ||
        status == AudioStatus.speaking ||
        status == AudioStatus.loading;
    final speaking = status == AudioStatus.speaking;
    final who = item.isAyah ? Reciter.byId(settings.reciterId).name : 'ফোনের বাংলা কণ্ঠ';
    final then = item.isAyah && settings.readBanglaAfterArabic ? 'তারপর বাংলা অর্থ' : null;
    const onGreen = Brand.onNight;
    final dim = Brand.onNight.withValues(alpha: 0.72);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.greenCard, p.greenCardDark],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusL)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    item.isAyah ? Icons.mic_none_rounded : Icons.record_voice_over_outlined,
                    color: p.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: onGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        if (then != null) Text(then, style: TextStyle(color: dim, fontSize: 14)),
                      ],
                    ),
                  ),
                  if (onAutoNext != null)
                    TextButton.icon(
                      onPressed: onAutoNext,
                      style: TextButton.styleFrom(foregroundColor: autoNext ? p.gold : dim),
                      icon: Icon(
                        autoNext ? Icons.playlist_play_rounded : Icons.playlist_remove_rounded,
                        size: 20,
                      ),
                      label: Text(autoNext ? 'পরপর' : 'একটি', style: const TextStyle(fontSize: 14)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (speaking)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        minHeight: 3,
                        color: p.gold,
                        backgroundColor: Brand.onNight.withValues(alpha: 0.24),
                      ),
                      const SizedBox(height: 6),
                      Text('বাংলা অর্থ পড়া হচ্ছে…', style: TextStyle(color: dim, fontSize: 14)),
                    ],
                  ),
                )
              else
                StreamBuilder<Duration>(
                  stream: audio.positionStream,
                  builder: (context, snap) {
                    final dur = mine ? (audio.duration ?? Duration.zero) : Duration.zero;
                    final pos = mine ? (snap.data ?? Duration.zero) : Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    final verse = mine && audio.verseCount > 1
                        ? ' · আয়াত ${toBanglaDigits(audio.verseIndex + 1)}/${toBanglaDigits(audio.verseCount)}'
                        : '';
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: p.gold,
                            inactiveTrackColor: Brand.onNight.withValues(alpha: 0.24),
                            thumbColor: p.gold,
                            overlayShape: SliderComponentShape.noOverlay,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, max).toDouble(),
                            max: max <= 0 ? 1 : max,
                            onChanged: max <= 0
                                ? null
                                : (v) => audio.seek(Duration(milliseconds: v.round())),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${_mmss(pos)}$verse', style: TextStyle(color: dim, fontSize: 14)),
                            const Spacer(),
                            Text(_mmss(dur), style: TextStyle(color: dim, fontSize: 14)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: repeat ? 'বারবার শোনা বন্ধ' : 'বারবার শুনুন',
                    onPressed: onRepeat,
                    icon: Icon(
                      repeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      color: repeat ? p.gold : dim,
                    ),
                  ),
                  IconButton(
                    tooltip: 'আগের',
                    onPressed: hasPrev ? onPrev : null,
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      size: 30,
                      color: hasPrev ? onGreen : Brand.onNight.withValues(alpha: 0.3),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 60,
                    child: Material(
                      color: p.gold,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onPlay,
                        child: status == AudioStatus.loading
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Brand.greenDark,
                                ),
                              )
                            : Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 34,
                                color: Brand.greenDark,
                                semanticLabel: playing ? 'থামান' : 'শুনুন',
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'পরের',
                    onPressed: hasNext ? onNext : null,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      size: 30,
                      color: hasNext ? onGreen : Brand.onNight.withValues(alpha: 0.3),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) => TextButton(
                      onPressed: () {
                        const s = AudioController.speeds;
                        final i = s.indexOf(settings.playbackSpeed);
                        audio.setSpeed(s[(i + 1) % s.length]);
                      },
                      style: TextButton.styleFrom(foregroundColor: onGreen),
                      child: Text(
                        speedLabel(settings.playbackSpeed),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
