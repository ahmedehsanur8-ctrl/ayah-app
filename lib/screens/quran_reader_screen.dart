import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/audio.dart';
import '../services/quran.dart';
import '../services/quran_player.dart';
import '../theme.dart';
import '../widgets/audio_button.dart';
import '../widgets/pattern.dart';
import '../widgets/quran_widgets.dart';

/// One surah: header with the basmala, every ayah with its translations, and
/// the recitation bar at the bottom. Remembers where the reader is.
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.surah, this.ayah = 1});

  final int surah;

  /// Opens at this ayah (1 = the top of the surah).
  final int ayah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _player = QuranPlayer.instance;
  final _prefs = AppState.instance.settings.quran;
  bool _ready = Quran.textLoaded;
  Timer? _saveTimer;
  late int _visibleAyah = widget.ayah;
  int _followed = 0;
  int _seenProblems = AudioController.instance.problemCount;

  /// The ayah opened from search / a bookmark is marked briefly.
  late int? _marked = widget.ayah > 1 ? widget.ayah : null;

  Surah get _surah => Quran.surah(widget.surah);

  @override
  void initState() {
    super.initState();
    _load();
    _positions.itemPositions.addListener(_onScroll);
    _player.addListener(_onPlayer);
    unawaited(_prefs.setLastRead(widget.surah, widget.ayah, notify: true));
    if (_marked != null) {
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _marked = null);
      });
    }
  }

  Future<void> _load() async {
    await Quran.load();
    for (final id in _prefs.translations) {
      await Quran.loadTranslation(id);
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _positions.itemPositions.removeListener(_onScroll);
    _player.removeListener(_onPlayer);
    // Update the "যেখানে শেষ করেছিলেন" cards once this page is gone.
    final prefs = _prefs;
    WidgetsBinding.instance.addPostFrameCallback((_) => prefs.refresh());
    super.dispose();
  }

  /// Saves the first ayah on screen as the last-read place (after scrolling stops).
  void _onScroll() {
    final visible = _positions.itemPositions.value.where((p) => p.itemTrailingEdge > 0.08);
    if (visible.isEmpty) return;
    final first = visible.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final ayah = first.clamp(1, _surah.ayahCount);
    if (ayah == _visibleAyah) return;
    _visibleAyah = ayah;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      _prefs.setLastRead(widget.surah, ayah);
    });
  }

  void _onPlayer() {
    if (!mounted) return;
    final audio = AudioController.instance;
    if (audio.problemCount != _seenProblems) {
      _seenProblems = audio.problemCount;
      if (audio.problem == AudioProblem.offline) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('তিলাওয়াত শুনতে ইন্টারনেট দরকার (ডাউনলোড করা সূরা ছাড়া)।'),
            ),
          );
      } else if (audio.problem == AudioProblem.noBanglaVoice) {
        showNoBanglaVoiceDialog(context);
      }
    }
    if (_player.active && _player.surah == widget.surah && _player.ayah != _followed) {
      _followed = _player.ayah;
      if (_prefs.followAudio && _scroll.isAttached) {
        _scroll.scrollTo(
          index: _player.ayah,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.08,
        );
      }
    }
    setState(() {});
  }

  void _openSurah(int n) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => QuranReaderScreen(surah: n)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = _surah;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('সূরা ${s.nameBn}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              '${s.meaningBn} · ${s.typeBn} · ${toBanglaDigits(s.ayahCount)} আয়াত',
              style: TextStyle(fontSize: 14, color: p.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'পড়ার সেটিংস',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () async {
              await showQuranSettingsSheet(context);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _prefs,
              builder: (context, _) => ScrollablePositionedList.builder(
                itemScrollController: _scroll,
                itemPositionsListener: _positions,
                initialScrollIndex: widget.ayah > 1 ? widget.ayah.clamp(1, s.ayahCount) : 0,
                initialAlignment: 0.02,
                itemCount: s.ayahCount + 2,
                padding: const EdgeInsets.only(bottom: 24),
                itemBuilder: (context, i) {
                  if (i == 0) return _SurahHeader(surah: s);
                  if (i == s.ayahCount + 1) {
                    return _SurahFooter(surah: s, onOpen: _openSurah);
                  }
                  return AyahTile(
                    surah: s.n,
                    ayah: i,
                    playing: _player.isPlayingAyah(s.n, i),
                    marked: _marked == i,
                  );
                },
              ),
            ),
      bottomNavigationBar: !_ready
          ? null
          : QuranPlayerBar(surah: s.n, startAyah: () => _visibleAyah),
    );
  }
}

/// Green card: Arabic name, Bangla name and meaning, and the basmala.
class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
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
              const PatternLayer(color: Brand.gold, opacity: 0.08, cell: 44),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  children: [
                    Text(
                      surah.nameAr,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: arabicFont,
                        fontSize: 30,
                        color: Brand.gold,
                      ),
                    ),
                    Text(
                      'সূরা ${surah.nameBn}',
                      style: const TextStyle(
                        fontFamily: headingFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${surah.meaningBn} · ${surah.typeBn} · ${toBanglaDigits(surah.ayahCount)} আয়াত',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                    ),
                    if (surah.hasSeparateBasmala) ...[
                      const SizedBox(height: 12),
                      Divider(color: Brand.gold.withValues(alpha: 0.35), height: 1),
                      const SizedBox(height: 10),
                      Text(
                        Quran.basmala,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: arabicFont,
                          fontSize: 26,
                          height: 1.9,
                          color: Brand.cream,
                        ),
                      ),
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

class _SurahFooter extends StatelessWidget {
  const _SurahFooter({required this.surah, required this.onOpen});

  final Surah surah;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          Text(
            'সূরা ${surah.nameBn} শেষ',
            style: TextStyle(color: p.goldText, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (surah.n > 1)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onOpen(surah.n - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(Quran.surah(surah.n - 1).nameBn, overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (surah.n > 1 && surah.n < 114) const SizedBox(width: 10),
              if (surah.n < 114)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onOpen(surah.n + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: Text(
                      'পরের: ${Quran.surah(surah.n + 1).nameBn}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One ayah: number, actions, Arabic and the chosen translations.
class AyahTile extends StatelessWidget {
  const AyahTile({
    super.key,
    required this.surah,
    required this.ayah,
    this.playing = false,
    this.marked = false,
  });

  final int surah;
  final int ayah;
  final bool playing;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final prefs = AppState.instance.settings.quran;
    final i = Quran.indexOf(surah, ayah);
    final translations = shownTranslations();
    final highlight = playing || marked;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: highlight ? p.primary.withValues(alpha: p.isDark ? 0.18 : 0.08) : null,
        borderRadius: BorderRadius.circular(radiusM),
        border: highlight ? Border.all(color: p.primary.withValues(alpha: 0.35)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AyahBadge(ayah),
              const Spacer(),
              _Icon(
                icon: playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                tooltip: 'এই আয়াত থেকে শুনুন',
                color: playing ? p.primary : null,
                onTap: () => QuranPlayer.instance.play(surah, ayah),
              ),
              ListenableBuilder(
                listenable: prefs,
                builder: (context, _) {
                  final on = prefs.isBookmarked(surah, ayah);
                  return _Icon(
                    icon: on ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    tooltip: on ? 'বুকমার্ক সরান' : 'বুকমার্ক করুন',
                    color: on ? p.goldText : null,
                    onTap: () => prefs.toggleBookmark(surah, ayah),
                  );
                },
              ),
              _Icon(
                icon: Icons.share_outlined,
                tooltip: 'শেয়ার করুন',
                onTap: () => showAyahShare(context, surah, ayah),
              ),
              if (hasNotes(surah, ayah))
                _Icon(
                  icon: Icons.sticky_note_2_outlined,
                  tooltip: 'টীকা দেখুন',
                  onTap: () => showAyahNotes(context, surah, ayah),
                ),
            ],
          ),
          if (prefs.showArabic) ...[
            const SizedBox(height: 6),
            Text(
              Quran.displayArabic(surah, ayah),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: arabicFont,
                fontSize: prefs.arabicSize,
                height: 2.0,
                color: p.arabic,
              ),
            ),
          ],
          if (prefs.showBangla)
            for (final t in translations) ...[
              const SizedBox(height: 8),
              Text(
                t.text[i],
                style: TextStyle(
                  fontFamily: banglaFont,
                  fontFamilyFallback: fontFallback,
                  fontSize: prefs.banglaSize,
                  height: 1.7,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 2),
              Text('— ${t.info.name}', style: TextStyle(fontSize: 14, color: p.muted)),
            ],
        ],
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.icon, required this.tooltip, required this.onTap, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 21, color: color ?? context.palette.muted),
  );
}
