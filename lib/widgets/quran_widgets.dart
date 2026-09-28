import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/audio.dart';
import '../services/quran.dart';
import '../services/quran_player.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'pattern.dart';
import 'share_card.dart';

/// Ayah number inside a small gold eight-pointed star.
class AyahBadge extends StatelessWidget {
  const AyahBadge(this.n, {super.key, this.size = 36});

  final int n;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StarOutline(p.goldText),
        child: Center(
          child: Text(
            toBanglaDigits(n),
            style: TextStyle(
              fontSize: n > 99 ? size * 0.3 : size * 0.36,
              fontWeight: FontWeight.w700,
              color: p.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarOutline extends CustomPainter {
  _StarOutline(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      eightPointStar(size.center(Offset.zero), size.width / 2 - 1),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_StarOutline old) => old.color != color;
}

/// "সূরা আল-বাকারা · ২:২৫৫".
String ayahTitle(int s, int a) => 'সূরা ${Quran.surah(s).nameBn} · ${AyahRef(s, a).bn}';

/// The translations to show (only the ones on the phone).
List<TranslationText> shownTranslations() => [
  for (final id in AppState.instance.settings.quran.translations)
    if (Quran.loaded[id] != null) Quran.loaded[id]!,
];

// ------------------------------------------------------------ footnotes

Future<void> showAyahNotes(BuildContext context, int s, int a) {
  final p = context.palette;
  final i = Quran.indexOf(s, a);
  final notes = [
    for (final t in Quran.loaded.values)
      if (t.notes[i].trim().isNotEmpty) t,
  ];
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text('টীকা', style: titleStyle(p, size: 19)),
          Text(ayahTitle(s, a), style: TextStyle(color: p.muted, fontSize: 13)),
          for (final t in notes) ...[
            const SizedBox(height: 16),
            Text(
              t.info.name,
              style: TextStyle(color: p.goldText, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            SelectableText(
              t.notes[i].trim(),
              style: TextStyle(
                fontFamily: banglaFont,
                fontFamilyFallback: fontFallback,
                fontSize: AppState.instance.settings.quran.banglaSize,
                height: 1.7,
                color: p.text,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

bool hasNotes(int s, int a) {
  final i = Quran.indexOf(s, a);
  for (final t in Quran.loaded.values) {
    if (t.notes[i].trim().isNotEmpty) return true;
  }
  return false;
}

// ---------------------------------------------------------------- share

Future<void> showAyahShare(BuildContext context, int s, int a) {
  final t = shownTranslations().firstOrNull ?? Quran.loaded['bn_zakaria'];
  final i = Quran.indexOf(s, a);
  final bangla = t == null ? '' : withoutFootnoteMarks(t.text[i]);
  final title = ayahTitle(s, a);
  final translator = t == null ? '' : 'অনুবাদ: ${t.info.name}';
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('ছবি হিসেবে শেয়ার'),
            subtitle: const Text('আরবি, বাংলা, সূত্র ও অ্যাপের নাম'),
            onTap: () {
              Navigator.pop(sheet);
              showShareSheet(
                context,
                ContentItem(
                  id: 'quran-$s-$a',
                  type: ItemType.ayah,
                  categoryId: 'quran',
                  category: translator,
                  reference: '$s:$a',
                  title: title,
                  arabic: Quran.displayArabic(s, a),
                  bangla: bangla,
                  note: '',
                  placeholder: false,
                  surah: s,
                  ayahStart: a,
                  ayahEnd: a,
                ),
                heading: 'আল-কুরআন',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notes_rounded),
            title: const Text('লেখা হিসেবে শেয়ার'),
            onTap: () {
              Navigator.pop(sheet);
              SharePlus.instance.share(
                ShareParams(
                  text:
                      '${Quran.displayArabic(s, a)}\n\n$bangla\n\n— $title'
                      '${translator.isEmpty ? '' : '\n$translator'}\n\nআয়াত রিমাইন্ডার',
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------- reader settings

/// Arabic / Bangla size, which translations, Arabic only / Bangla only / both.
Future<void> showQuranSettingsSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const _QuranSettingsSheet(),
);

class _QuranSettingsSheet extends StatefulWidget {
  const _QuranSettingsSheet();

  @override
  State<_QuranSettingsSheet> createState() => _QuranSettingsSheetState();
}

class _QuranSettingsSheetState extends State<_QuranSettingsSheet> {
  final Map<String, bool> _onPhone = {};
  final Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    for (final t in Quran.translations) {
      _onPhone[t.id] = await Quran.isDownloaded(t.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggle(TranslationInfo t, bool on) async {
    final prefs = AppState.instance.settings.quran;
    final messenger = ScaffoldMessenger.of(context);
    final list = [...prefs.translations];
    if (!on) {
      if (list.length > 1) list.remove(t.id);
      await prefs.setTranslations(list);
      return;
    }
    if (_onPhone[t.id] != true) {
      setState(() => _progress[t.id] = 0);
      final ok = await Quran.download(
        t.id,
        onProgress: (v) {
          if (mounted) setState(() => _progress[t.id] = v);
        },
      );
      if (!mounted) return;
      setState(() {
        _progress.remove(t.id);
        _onPhone[t.id] = ok;
      });
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ডাউনলোড করা যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।'),
          ),
        );
        return;
      }
    } else if (!await Quran.loadTranslation(t.id)) {
      return;
    }
    // At most two at once: the newest choice replaces the older second one.
    list.remove(t.id);
    list.add(t.id);
    while (list.length > 2) {
      list.removeAt(0);
    }
    await prefs.setTranslations(list);
  }

  Future<void> _delete(TranslationInfo t) async {
    final prefs = AppState.instance.settings.quran;
    await Quran.deleteTranslation(t.id);
    final list = [...prefs.translations]..remove(t.id);
    await prefs.setTranslations(list.isEmpty ? ['bn_zakaria'] : list);
    setState(() => _onPhone[t.id] = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final prefs = AppState.instance.settings.quran;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('পড়ার সেটিংস', style: titleStyle(p, size: 19)),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'both', label: Text('দুটোই')),
                ButtonSegment(value: 'arabic', label: Text('শুধু আরবি')),
                ButtonSegment(value: 'bangla', label: Text('শুধু বাংলা')),
              ],
              selected: {prefs.mode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => prefs.setMode(v.first),
            ),
            const SizedBox(height: 18),
            _SizeRow(
              label: 'আরবির আকার',
              value: prefs.arabicSize,
              min: 20,
              max: 48,
              onChanged: prefs.setArabicSize,
              sample: Text(
                'بِسْمِ ٱللَّهِ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: arabicFont,
                  fontSize: prefs.arabicSize,
                  color: p.arabic,
                ),
              ),
            ),
            _SizeRow(
              label: 'বাংলার আকার',
              value: prefs.banglaSize,
              min: 13,
              max: 30,
              onChanged: prefs.setBanglaSize,
              sample: Text(
                'পরম করুণাময়',
                style: TextStyle(fontSize: prefs.banglaSize, color: p.text),
              ),
            ),
            const SizedBox(height: 10),
            Text('অনুবাদ (একসাথে সর্বোচ্চ দুটি)', style: titleStyle(p, size: 16)),
            const SizedBox(height: 6),
            for (final t in Quran.translations)
              _TranslationRow(
                info: t,
                selected: prefs.translations.contains(t.id),
                onPhone: _onPhone[t.id] ?? t.bundled,
                progress: _progress[t.id],
                onChanged: (v) => _toggle(t, v),
                onDelete: t.bundled || _onPhone[t.id] != true ? null : () => _delete(t),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs.followAudio,
              onChanged: prefs.setFollowAudio,
              title: const Text('তিলাওয়াতের সাথে পাতা এগোবে'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.sample,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final Widget sample;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: p.text),
            ),
            const Spacer(),
            Text(toBanglaDigits(value.round()), style: TextStyle(color: p.muted)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
        Center(child: sample),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _TranslationRow extends StatelessWidget {
  const _TranslationRow({
    required this.info,
    required this.selected,
    required this.onPhone,
    required this.progress,
    required this.onChanged,
    required this.onDelete,
  });

  final TranslationInfo info;
  final bool selected;
  final bool onPhone;
  final double? progress;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sub = [
      info.publisher,
      if (info.bundled)
        'অ্যাপের সাথেই আছে'
      else if (onPhone)
        'ডাউনলোড করা'
      else
        'ডাউনলোড: ${formatBytes(info.size)}',
      if (info.nonCommercial) 'অবাণিজ্যিক ব্যবহারের শর্তে',
    ].where((s) => s.isNotEmpty).join(' · ');
    return Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: selected,
          onChanged: progress != null ? null : (v) => onChanged(v ?? false),
          title: Text(info.name),
          subtitle: Text(sub, style: TextStyle(color: p.muted, fontSize: 12.5)),
          secondary: onDelete == null
              ? (onPhone ? null : Icon(Icons.download_rounded, color: p.muted))
              : IconButton(
                  tooltip: 'মুছে ফেলুন',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                ),
        ),
        if (progress != null) LinearProgressIndicator(value: progress == 0 ? null : progress),
      ],
    );
  }
}

// ---------------------------------------------------------------- player

/// Green bar at the bottom of the reader: prev / play-pause / next, the
/// current ayah and a button for the player options.
class QuranPlayerBar extends StatelessWidget {
  const QuranPlayerBar({super.key, required this.surah, required this.startAyah});

  final int surah;

  /// Where playback starts when nothing is playing (the ayah on screen).
  final int Function() startAyah;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final player = QuranPlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final mine = player.active && player.surah == surah;
        final playing = mine && player.isPlaying;
        final loading = mine && player.status == AudioStatus.loading;
        final speaking = mine && player.status == AudioStatus.speaking;
        final count = Quran.surah(surah).ayahCount;
        final dim = Colors.white.withValues(alpha: 0.75);
        final line = mine
            ? 'আয়াত ${toBanglaDigits(player.ayah)} / ${toBanglaDigits(count)}'
            : 'তিলাওয়াত শুনুন';
        final sub = speaking
            ? 'বাংলা অর্থ পড়া হচ্ছে…'
            : [
                Reciter.byId(AppState.instance.settings.reciterId).name,
                if (mine && player.repeat != QuranRepeat.off) 'পুনরাবৃত্তি',
                if (player.sleepAt != null) 'স্লিপ টাইমার',
              ].join(' · ');
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.greenCard, p.greenCardDark]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusM)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'আগের আয়াত',
                    onPressed: mine ? player.previous : null,
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: mine ? Colors.white : Colors.white30,
                    ),
                  ),
                  SizedBox.square(
                    dimension: 50,
                    child: Material(
                      color: p.gold,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => player.toggle(surah, mine ? player.ayah : startAyah()),
                        child: loading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Brand.greenDark,
                                ),
                              )
                            : Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 30,
                                color: Brand.greenDark,
                                semanticLabel: playing ? 'থামান' : 'শুনুন',
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'পরের আয়াত',
                    onPressed: mine ? player.next : null,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: mine ? Colors.white : Colors.white30,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          line,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: dim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (mine)
                    IconButton(
                      tooltip: 'বন্ধ করুন',
                      onPressed: player.stop,
                      icon: Icon(Icons.stop_rounded, color: dim),
                    ),
                  IconButton(
                    tooltip: 'তিলাওয়াতের অপশন',
                    onPressed: () => showPlayerOptions(context, surah, startAyah()),
                    icon: Icon(Icons.tune_rounded, color: p.gold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reciter, speed, Bangla after each ayah, repeat, sleep timer, download.
Future<void> showPlayerOptions(BuildContext context, int surah, int ayah) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _PlayerOptions(surah: surah, ayah: ayah),
);

class _PlayerOptions extends StatefulWidget {
  const _PlayerOptions({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  @override
  State<_PlayerOptions> createState() => _PlayerOptionsState();
}

class _PlayerOptionsState extends State<_PlayerOptions> {
  final player = QuranPlayer.instance;
  late int _from = player.repeat == QuranRepeat.range ? player.rangeFrom : widget.ayah;
  late int _to = player.repeat == QuranRepeat.range ? player.rangeTo : widget.ayah;

  int get _count => Quran.surah(widget.surah).ayahCount;

  static const _sleepOptions = [5, 10, 15, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = AppState.instance.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([player, settings, settings.quran]),
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('তিলাওয়াত', style: titleStyle(p, size: 19)),
            const SizedBox(height: 10),
            _label(p, 'ক্বারী'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in Reciter.all)
                  ChoiceChip(
                    label: Text(r.name),
                    selected: settings.reciterId == r.id,
                    onSelected: (_) async {
                      final wasPlaying = player.active;
                      await settings.setReciter(r.id);
                      if (wasPlaying) await player.play(player.surah, player.ayah);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _label(p, 'গতি'),
            Wrap(
              spacing: 8,
              children: [
                for (final v in AudioController.speeds)
                  ChoiceChip(
                    label: Text('${toBanglaDigits(v.toString().replaceAll(RegExp(r'\.0$'), ''))}x'),
                    selected: settings.playbackSpeed == v,
                    onSelected: (_) => player.setSpeed(v),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.quran.banglaAfterAyah,
              onChanged: settings.quran.setBanglaAfterAyah,
              title: const Text('প্রতিটি আয়াতের পর বাংলা অর্থ'),
              subtitle: const Text('ফোনের বাংলা কণ্ঠে পড়া হবে'),
            ),
            const Divider(),
            _label(p, 'পুনরাবৃত্তি (মুখস্থ করার জন্য)'),
            SegmentedButton<QuranRepeat>(
              segments: const [
                ButtonSegment(value: QuranRepeat.off, label: Text('বন্ধ')),
                ButtonSegment(value: QuranRepeat.ayah, label: Text('একটি আয়াত')),
                ButtonSegment(value: QuranRepeat.range, label: Text('কয়েকটি আয়াত')),
              ],
              selected: {player.repeat},
              showSelectedIcon: false,
              onSelectionChanged: (v) => player.setRepeat(v.first, from: _from, to: _to),
            ),
            if (player.repeat == QuranRepeat.range) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ayahPicker(
                      'শুরু',
                      _from,
                      (v) => setState(() {
                        _from = v;
                        if (_to < v) _to = v;
                        player.setRepeat(QuranRepeat.range, from: _from, to: _to);
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ayahPicker(
                      'শেষ',
                      _to,
                      (v) => setState(() {
                        _to = v;
                        if (_from > v) _from = v;
                        player.setRepeat(QuranRepeat.range, from: _from, to: _to);
                      }),
                    ),
                  ),
                ],
              ),
            ],
            if (player.repeat != QuranRepeat.off) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in [2, 3, 5, 10, 0])
                    ChoiceChip(
                      label: Text(n == 0 ? 'অবিরাম' : '${toBanglaDigits(n)} বার'),
                      selected: player.repeatCount == n,
                      onSelected: (_) => player.setRepeat(player.repeat, count: n),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(context);
                    player.play(
                      widget.surah,
                      player.repeat == QuranRepeat.range ? _from : widget.ayah,
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    player.repeat == QuranRepeat.range
                        ? 'আয়াত ${toBanglaDigits(_from)}–${toBanglaDigits(_to)} শুরু করুন'
                        : 'আয়াত ${toBanglaDigits(widget.ayah)} শুরু করুন',
                  ),
                ),
              ),
            ],
            const Divider(),
            _label(p, 'স্লিপ টাইমার'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('বন্ধ'),
                  selected: player.sleepAt == null,
                  onSelected: (_) => player.setSleep(null),
                ),
                for (final m in _sleepOptions)
                  ChoiceChip(
                    label: Text('${toBanglaDigits(m)} মিনিট'),
                    selected: false,
                    onSelected: (_) => player.setSleep(Duration(minutes: m)),
                  ),
              ],
            ),
            if (player.sleepAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'তিলাওয়াত বন্ধ হবে ${_clock(player.sleepAt!)}-এ',
                  style: TextStyle(color: p.muted),
                ),
              ),
            const Divider(),
            SurahDownloadTile(surah: widget.surah),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return toBanglaDigits('$h:${t.minute.toString().padLeft(2, '0')}');
  }

  Widget _label(Palette p, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
    ),
  );

  Widget _ayahPicker(String label, int value, ValueChanged<int> onChanged) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          for (var a = 1; a <= _count; a++)
            DropdownMenuItem(value: a, child: Text('আয়াত ${toBanglaDigits(a)}')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}

/// Download a surah's recitation for offline listening; shows the size and
/// lets the user delete it.
class SurahDownloadTile extends StatefulWidget {
  const SurahDownloadTile({super.key, required this.surah});

  final int surah;

  @override
  State<SurahDownloadTile> createState() => _SurahDownloadTileState();
}

class _SurahDownloadTileState extends State<SurahDownloadTile> {
  final downloads = SurahDownloads.instance;
  ({int files, int bytes})? _stats;

  String get _reciter => QuranPlayer.instance.reciterId;

  @override
  void initState() {
    super.initState();
    downloads.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    downloads.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final st = await QuranAudioFiles.stats(_reciter, widget.surah);
    if (mounted) setState(() => _stats = st);
  }

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await downloads.start(_reciter, widget.surah);
    if (!ok && mounted && !downloads.isRunning(_reciter, widget.surah)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('পুরো সূরা ডাউনলোড হয়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।')),
      );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = Quran.surah(widget.surah).ayahCount;
    final st = _stats;
    final running = downloads.progressOf(_reciter, widget.surah);
    final all = st != null && st.files >= count;
    final subtitle = st == null
        ? ''
        : all
        ? 'পুরো সূরা ফোনে আছে · ${formatBytes(st.bytes)}'
        : st.files == 0
        ? 'ইন্টারনেট ছাড়া শুনতে ডাউনলোড করুন'
        : '${toBanglaDigits(st.files)}/${toBanglaDigits(count)} আয়াত ফোনে · ${formatBytes(st.bytes)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            all ? Icons.download_done_rounded : Icons.download_for_offline_outlined,
            color: all ? p.primary : p.muted,
          ),
          title: Text('সূরা ${Quran.surah(widget.surah).nameBn} ডাউনলোড'),
          subtitle: Text(subtitle),
          trailing: running != null
              ? TextButton(
                  onPressed: () => downloads.cancel(_reciter, widget.surah),
                  child: const Text('থামান'),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!all)
                      IconButton(
                        tooltip: 'ডাউনলোড',
                        onPressed: _download,
                        icon: const Icon(Icons.download_rounded),
                      ),
                    if (st != null && st.files > 0)
                      IconButton(
                        tooltip: 'মুছে ফেলুন',
                        onPressed: () async {
                          await QuranAudioFiles.deleteSurah(_reciter, widget.surah);
                          _refresh();
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
        ),
        if (running != null) LinearProgressIndicator(value: running == 0 ? null : running),
      ],
    );
  }
}
