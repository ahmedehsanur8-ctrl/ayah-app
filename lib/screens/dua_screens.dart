import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/duas.dart';
import '../services/quran.dart';
import '../services/quran_player.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/pattern.dart';
import '../widgets/share_card.dart';
import '../widgets/ui.dart';
import 'favorites_screen.dart';
import 'home_shell.dart';
import 'quran_reader_screen.dart';
import 'settings_screen.dart';
import 'tasbih_screen.dart';

/// Line icons for the 15 sections of dua-list.md.
IconData duaSectionIcon(int n) => switch (n) {
  1 => Icons.wb_twilight_rounded,
  2 => Icons.bedtime_outlined,
  3 => Icons.self_improvement_rounded,
  4 => Icons.home_outlined,
  5 => Icons.directions_car_outlined,
  6 => Icons.healing_outlined,
  7 => Icons.shield_outlined,
  8 => Icons.restart_alt_rounded,
  9 => Icons.auto_awesome_outlined,
  10 => Icons.family_restroom_outlined,
  11 => Icons.front_hand_outlined,
  12 => Icons.thunderstorm_outlined,
  13 => Icons.dark_mode_outlined,
  14 => Icons.mosque_outlined,
  _ => Icons.menu_book_outlined,
};

Tint _tint(Palette p, int n) => [p.mint, p.sky, p.sand, p.rose, p.lilac][n % 5];

// ------------------------------------------------------------------ home

/// দোয়া ও জিকির: search, today's adhkar and the 15 sections.
class DuaHomeScreen extends StatefulWidget {
  const DuaHomeScreen({super.key, this.inTab = false});

  /// Shown as the দোয়া tab (no back arrow).
  final bool inTab;

  @override
  State<DuaHomeScreen> createState() => _DuaHomeScreenState();
}

class _DuaHomeScreenState extends State<DuaHomeScreen> {
  final _query = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    Duas.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = Duas.search(_q);
    return Scaffold(
      appBar: AppBar(title: const Text('দোয়া ও জিকির'), automaticallyImplyLeading: !widget.inTab),
      body: !Duas.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                TextField(
                  controller: _query,
                  onChanged: (v) => setState(() => _q = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'দোয়া খুঁজুন: ভয়, ঋণ, সফর, অসুস্থ…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'মুছুন',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() {
                              _query.clear();
                              _q = '';
                            }),
                          ),
                    filled: true,
                    fillColor: p.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radiusM),
                      borderSide: BorderSide(color: p.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radiusM),
                      borderSide: BorderSide(color: p.border),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_q.trim().length >= 2) ...[
                  SectionLabel(
                    results.isEmpty
                        ? 'কিছু পাওয়া যায়নি'
                        : '${toBanglaDigits(results.length)}টি দোয়া',
                  ),
                  for (var i = 0; i < results.length; i++)
                    DuaRow(
                      dua: results[i],
                      onTap: () => push(context, DuaPagerScreen(duas: results, index: i)),
                    ),
                ] else ...[
                  const AdhkarCard(),
                  const SizedBox(height: 12),
                  const TasbihCard(),
                  const SizedBox(height: 12),
                  ActionRow(
                    children: [
                      LabeledAction(
                        icon: Icons.favorite_border_rounded,
                        label: 'প্রিয় দোয়া',
                        tint: p.rose,
                        onTap: () => push(context, const FavoritesScreen(initialTab: 1)),
                      ),
                      LabeledAction(
                        icon: Icons.tune_rounded,
                        label: 'দোয়ার সেটিং',
                        tint: p.sky,
                        onTap: () =>
                            push(context, const SettingsScreen(section: SettingsSection.duas)),
                      ),
                    ],
                  ),
                  const SectionLabel('বিষয় অনুযায়ী'),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: Duas.sections.length,
                    itemBuilder: (context, i) {
                      final s = Duas.sections[i];
                      final t = _tint(p, s.n);
                      return Material(
                        color: t.background,
                        borderRadius: BorderRadius.circular(radiusM),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(radiusM),
                          onTap: () => push(context, DuaSectionScreen(section: s)),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(duaSectionIcon(s.n), color: t.foreground, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  s.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: t.foreground,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                                Text(
                                  '${toBanglaDigits(s.count)}টি',
                                  style: TextStyle(color: t.foreground, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

/// "আজকের জিকির": the morning or evening set (by the time of day), with a
/// start button. Also on the Today screen.
class AdhkarCard extends StatelessWidget {
  const AdhkarCard({super.key, this.showAllButton = false});

  /// On the Today screen: a second button that opens the whole Dua section.
  final bool showAllButton;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final evening = Duas.isEveningNow(AppState.instance.settings);
    final set = Duas.loaded ? Duas.adhkar(evening: evening) : const <Dua>[];
    final title = evening ? 'সন্ধ্যার জিকির' : 'সকালের জিকির';
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
            const PatternLayer(color: Brand.gold, opacity: 0.07, cell: 44),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        evening ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined,
                        color: Brand.gold,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        showAllButton ? 'দোয়া ও জিকির' : 'আজকের জিকির',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$title · ${toBanglaDigits(set.length)}টি জিকির',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    evening
                        ? 'আসর থেকে রাত পর্যন্ত পড়ার জিকির, গুনে গুনে'
                        : 'ফজর থেকে সকাল পর্যন্ত পড়ার জিকির, গুনে গুনে',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: set.isEmpty
                            ? null
                            : () => push(context, DuaCounterScreen.adhkar(evening: evening)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.gold,
                          foregroundColor: Brand.greenDark,
                        ),
                        icon: const Icon(Icons.touch_app_outlined),
                        label: const Text('জিকির শুরু করুন'),
                      ),
                      TextButton(
                        onPressed: showAllButton
                            ? () => HomeShell.tab.value = HomeShell.duas
                            : () => push(context, DuaCounterScreen.adhkar(evening: !evening)),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: Text(
                          showAllButton
                              ? 'সব দোয়া'
                              : (evening ? 'সকালের জিকির' : 'সন্ধ্যার জিকির'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- section

class DuaSectionScreen extends StatelessWidget {
  const DuaSectionScreen({super.key, required this.section});

  final DuaSection section;

  @override
  Widget build(BuildContext context) {
    final duas = Duas.inSection(section.n);
    return Scaffold(
      appBar: AppBar(
        title: Text(section.title),
        actions: [
          if (section.n == 1)
            IconButton(
              tooltip: 'গুনে গুনে পড়ুন',
              icon: const Icon(Icons.touch_app_outlined),
              onPressed: () => push(
                context,
                DuaCounterScreen.adhkar(evening: Duas.isEveningNow(AppState.instance.settings)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (var i = 0; i < duas.length; i++)
            DuaRow(
              dua: duas[i],
              number: i + 1,
              onTap: () => push(context, DuaPagerScreen(duas: duas, index: i)),
            ),
        ],
      ),
    );
  }
}

class DuaRow extends StatelessWidget {
  const DuaRow({super.key, required this.dua, required this.onTap, this.number});

  final Dua dua;
  final VoidCallback onTap;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            if (number != null) ...[
              IconBubble(duaSectionIcon(dua.section), tint: _tint(p, dua.section), size: 38),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dua.title,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text),
                  ),
                  if (dua.when.isNotEmpty)
                    Text(
                      'কখন: ${dua.when}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: p.muted, height: 1.4),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GradeChip(dua),
                if (dua.hasCounter)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${toBanglaDigits(dua.total)} বার',
                      style: TextStyle(
                        fontSize: 14,
                        color: p.goldText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small coloured grade label: সহিহ / হাসান / কুরআন / সাহাবি-তাবেয়ির বাণী / মতভেদপূর্ণ.
class GradeChip extends StatelessWidget {
  const GradeChip(this.dua, {super.key});

  final Dua dua;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = switch (dua.grade) {
      'Q' => p.mint,
      'S' => p.sky,
      'H' => p.lilac,
      'A' => p.sand,
      _ => p.rose,
    };
    final label = switch (dua.grade) {
      'R' => 'মতভেদপূর্ণ',
      _ => dua.gradeBn,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.foreground),
      ),
    );
  }
}

// ------------------------------------------------------------ dua page

/// Swipe through the duas of a list; one [DuaView] per page.
class DuaPagerScreen extends StatefulWidget {
  const DuaPagerScreen({super.key, required this.duas, this.index = 0});

  final List<Dua> duas;
  final int index;

  @override
  State<DuaPagerScreen> createState() => _DuaPagerScreenState();
}

class _DuaPagerScreenState extends State<DuaPagerScreen> {
  late final _pages = PageController(initialPage: widget.index);
  late int _index = widget.index;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    final dua = widget.duas[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.duas.length > 1
              ? '${toBanglaDigits(_index + 1)} / ${toBanglaDigits(widget.duas.length)}'
              : 'দোয়া',
        ),
        actions: [
          ListenableBuilder(
            listenable: s,
            builder: (context, _) => IconButton(
              tooltip: s.showUccharon ? 'উচ্চারণ লুকান' : 'উচ্চারণ দেখান',
              icon: Icon(
                s.showUccharon ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
              ),
              onPressed: () => s.setShowUccharon(!s.showUccharon),
            ),
          ),
          IconButton(
            tooltip: 'লেখার আকার',
            icon: const Icon(Icons.format_size_rounded),
            onPressed: () => _textSize(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.duas.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => DuaView(dua: widget.duas[i]),
      ),
      bottomNavigationBar: dua.hasCounter
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: FilledButton.icon(
                  onPressed: () => push(context, DuaCounterScreen(duas: [dua], title: dua.title)),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.touch_app_outlined),
                  label: Text('গুনে পড়ুন · ${toBanglaDigits(dua.total)} বার'),
                ),
              ),
            )
          : Container(height: 0, color: p.background),
    );
  }

  void _textSize(BuildContext context) {
    final s = AppState.instance.settings;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: s.textScale,
                min: 0.8,
                max: 1.6,
                divisions: 8,
                label: '${toBanglaDigits((s.textScale * 100).round())}%',
                onChanged: s.setTextScale,
              ),
              Text(
                'رَبِّ اغْفِرْ لِي',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: arabicFont, fontSize: 28 * s.textScale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One dua: Arabic, উচ্চারণ, meaning, when, fadilah, source and grade, and
/// the প্রিয় / শেয়ার / কপি buttons.
class DuaView extends StatefulWidget {
  const DuaView({super.key, required this.dua});

  final Dua dua;

  @override
  State<DuaView> createState() => _DuaViewState();
}

class _DuaViewState extends State<DuaView> {
  late bool _evening = widget.dua.evening != null && Duas.isEveningNow(AppState.instance.settings);

  Dua get d => widget.dua;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final text = d.textFor(evening: _evening);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Text(d.title, style: titleStyle(p, size: 20)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GradeChip(d),
                if (d.athar) _Pill('সাহাবি/তাবেয়ির বাণী', p.sand),
                if (d.grade == 'R') _Pill('আলেমদের মধ্যে মতভেদ আছে', p.rose),
                if (d.needsReview) _Pill('আলেমের যাচাই বাকি', p.lilac),
                if (d.hasCounter)
                  _Pill(
                    '${toBanglaDigits(d.total)} বার${d.repeatNote.isEmpty ? '' : ' (${d.repeatNote})'}',
                    p.mint,
                  ),
              ],
            ),
            if (d.evening != null) ...[
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('সকালে')),
                  ButtonSegment(value: true, label: Text('সন্ধ্যায়')),
                ],
                selected: {_evening},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _evening = v.first),
              ),
            ],
            if (text.arabic.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(radiusM),
                  border: Border.all(color: p.border),
                ),
                child: Text(
                  text.arabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: arabicFont,
                    fontSize: 27 * s.textScale,
                    height: 2.0,
                    color: p.arabic,
                  ),
                ),
              ),
            ],
            if (d.quran.isNotEmpty) ...[const SizedBox(height: 10), _QuranAudio(dua: d)],
            if (d.openSurahs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in d.openSurahs)
                    FilledButton.tonalIcon(
                      onPressed: () => push(context, QuranReaderScreen(surah: n)),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(
                        'সূরা ${Quran.metaLoaded ? Quran.surah(n).nameBn : toBanglaDigits(n)}',
                      ),
                    ),
                ],
              ),
            ],
            if (s.showUccharon && text.uccharon.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label('উচ্চারণ'),
              Text(
                text.uccharon,
                style: TextStyle(
                  fontSize: 16.5 * s.textScale,
                  height: 1.7,
                  color: p.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Duas.uccharonNote,
                style: TextStyle(fontSize: 14, color: p.muted, fontStyle: FontStyle.italic),
              ),
            ],
            if (text.bangla.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label(d.info && d.arabic.isEmpty ? 'বিবরণ' : 'অর্থ'),
              Text(
                text.bangla,
                style: TextStyle(fontSize: 16 * s.textScale, height: 1.7, color: p.text),
              ),
              if (d.translator.isNotEmpty)
                Text('— ${d.translator}', style: TextStyle(fontSize: 14, color: p.muted)),
            ],
            if (d.when.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label('কখন পড়বেন'),
              Text(
                d.when,
                style: TextStyle(fontSize: 15 * s.textScale, height: 1.6, color: p.text),
              ),
            ],
            if (d.fadilah.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label('ফজিলত'),
              Text(
                d.fadilah,
                style: TextStyle(fontSize: 15 * s.textScale, height: 1.6, color: p.text),
              ),
            ],
            const SizedBox(height: 16),
            _Label('সূত্র'),
            Text(
              '${d.source} · ${d.gradeBn}',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: p.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (d.note.isNotEmpty)
              Text(d.note, style: TextStyle(fontSize: 14, color: p.muted, height: 1.5)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => s.toggleDuaFavorite(d.id),
                  icon: Icon(
                    s.isDuaFavorite(d.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: s.isDuaFavorite(d.id) ? p.heart : null,
                  ),
                  label: const Text('প্রিয়'),
                ),
                if (text.arabic.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _share(context, text),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('শেয়ার'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _copy(context, text),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('কপি'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _share(BuildContext context, DuaText text) {
    showShareSheet(
      context,
      ContentItem(
        id: 'dua-${d.id}',
        type: ItemType.ayah,
        categoryId: 'dua',
        category: d.gradeBn,
        reference: d.source,
        title: '${d.title}\n${d.source}',
        arabic: text.arabic,
        bangla: withoutFootnoteMarks(text.bangla),
        note: '',
        placeholder: false,
      ),
      heading: 'দোয়া ও জিকির',
    );
  }

  Future<void> _copy(BuildContext context, DuaText text) async {
    final messenger = ScaffoldMessenger.of(context);
    final parts = [
      d.title,
      if (text.arabic.isNotEmpty) text.arabic,
      if (text.uccharon.isNotEmpty) 'উচ্চারণ: ${text.uccharon}',
      if (text.bangla.isNotEmpty) 'অর্থ: ${text.bangla}',
      'সূত্র: ${d.source} (${d.gradeBn})',
      '— আয়াত রিমাইন্ডার',
    ];
    await Clipboard.setData(ClipboardData(text: parts.join('\n\n')));
    messenger.showSnackBar(const SnackBar(content: Text('কপি হয়েছে')));
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(color: context.palette.goldText, fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.tint);

  final String text;
  final Tint tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: tint.background, borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tint.foreground),
    ),
  );
}

/// Recitation of a Quranic dua (EveryAyah, the chosen reciter).
class _QuranAudio extends StatelessWidget {
  const _QuranAudio({required this.dua});

  final Dua dua;

  @override
  Widget build(BuildContext context) {
    final player = QuranPlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final q in dua.quran)
            Builder(
              builder: (context) {
                final mine =
                    player.active &&
                    player.surah == q.surah &&
                    player.ayah >= q.from &&
                    player.ayah <= q.to;
                return FilledButton.tonalIcon(
                  onPressed: () => mine ? player.stop() : player.play(q.surah, q.from, to: q.to),
                  icon: Icon(mine ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(
                    dua.quran.length > 1 && Quran.metaLoaded
                        ? 'সূরা ${Quran.surah(q.surah).nameBn}'
                        : 'তিলাওয়াত শুনুন',
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- counter

/// Tap-to-count: a big circle per dua (৩/৩, ৩৩/৩৩ …), vibration when done
/// and the next dua opens by itself. The সকাল/সন্ধ্যার জিকির flows play
/// through the whole set.
class DuaCounterScreen extends StatefulWidget {
  const DuaCounterScreen({
    super.key,
    required this.duas,
    required this.title,
    this.evening = false,
  });

  factory DuaCounterScreen.adhkar({Key? key, required bool evening}) => DuaCounterScreen(
    key: key,
    duas: Duas.adhkar(evening: evening),
    title: evening ? 'সন্ধ্যার জিকির' : 'সকালের জিকির',
    evening: evening,
  );

  final List<Dua> duas;
  final String title;

  /// Show the evening wording where there is one.
  final bool evening;

  @override
  State<DuaCounterScreen> createState() => _DuaCounterScreenState();
}

class _DuaCounterScreenState extends State<DuaCounterScreen> {
  int _index = 0;
  int _count = 0;
  bool _done = false;
  Timer? _next;

  Dua get _dua => widget.duas[_index];

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  /// The step (for 33/33/34) that count [c] falls in, and the count inside it.
  ({int step, int inStep, int size}) _stepOf(int c) {
    final steps = _dua.steps;
    if (steps.isEmpty) return (step: 0, inStep: c, size: _dua.total);
    var left = c;
    for (var i = 0; i < steps.length; i++) {
      if (left < steps[i].count || i == steps.length - 1) {
        return (step: i, inStep: left, size: steps[i].count);
      }
      left -= steps[i].count;
    }
    return (step: 0, inStep: c, size: _dua.total);
  }

  void _tap() {
    if (_done || _count >= _dua.total) return;
    final before = _stepOf(_count);
    setState(() => _count++);
    final after = _stepOf(_count);
    if (_count >= _dua.total) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 120), HapticFeedback.vibrate);
      _next = Timer(const Duration(milliseconds: 700), _advance);
    } else if (after.step != before.step) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _advance() {
    if (!mounted) return;
    if (_index < widget.duas.length - 1) {
      setState(() {
        _index++;
        _count = 0;
      });
    } else {
      setState(() => _done = true);
    }
  }

  void _go(int i) {
    _next?.cancel();
    setState(() {
      _index = i.clamp(0, widget.duas.length - 1);
      _count = 0;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    if (widget.duas.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: widget.duas.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _done ? 1 : _index / widget.duas.length,
                  minHeight: 4,
                  backgroundColor: p.border,
                  color: p.primary,
                ),
              )
            : null,
      ),
      body: _done ? _finished(p) : _page(p, s),
    );
  }

  Widget _finished(Palette p) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 84, color: p.primary),
          const SizedBox(height: 16),
          Text(
            '${widget.title} সম্পন্ন',
            style: titleStyle(p, size: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('আল্লাহ কবুল করুন।', style: TextStyle(color: p.muted, fontSize: 15)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('শেষ')),
          TextButton(onPressed: () => _go(0), child: const Text('আবার শুরু থেকে')),
        ],
      ),
    ),
  );

  Widget _page(Palette p, AppSettings s) {
    final d = _dua;
    final text = d.textFor(evening: widget.evening);
    final st = _stepOf(_count);
    final complete = _count >= d.total;
    final circleText = d.steps.isEmpty
        ? '${toBanglaDigits(_count)}/${toBanglaDigits(d.total)}'
        : '${toBanglaDigits(complete ? st.size : st.inStep)}/${toBanglaDigits(st.size)}';
    final arabic = d.steps.isNotEmpty && !complete ? d.steps[st.step].arabic : text.arabic;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            children: [
              if (widget.duas.length > 1)
                Text(
                  '${toBanglaDigits(_index + 1)} / ${toBanglaDigits(widget.duas.length)}',
                  style: TextStyle(color: p.muted, fontSize: 14),
                ),
              Text(d.title, style: titleStyle(p, size: 18)),
              const SizedBox(height: 10),
              if (arabic.isNotEmpty)
                Text(
                  arabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: arabicFont,
                    fontSize: 25 * s.textScale,
                    height: 2.0,
                    color: p.arabic,
                  ),
                ),
              if (s.showUccharon && text.uccharon.isNotEmpty && d.steps.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  text.uccharon,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5 * s.textScale, height: 1.6, color: p.text),
                ),
                Text(
                  Duas.uccharonNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: p.muted, fontStyle: FontStyle.italic),
                ),
              ],
              if (d.steps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    d.steps[complete ? d.steps.length - 1 : st.step].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: p.goldText, fontWeight: FontWeight.w700),
                  ),
                ),
              if (d.quran.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(child: _QuranAudio(dua: d)),
              ],
              const SizedBox(height: 8),
              Text(
                '${d.source} · ${d.gradeBn}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: p.muted),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'আগের',
                  onPressed: _index > 0 ? () => _go(_index - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 32),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _tap,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: complete
                                ? [p.primary, p.primary]
                                : [p.greenCard, p.greenCardDark],
                          ),
                          border: Border.all(color: p.gold, width: 4),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 140,
                              child: CircularProgressIndicator(
                                value: d.total == 0 ? 0.0 : _count / d.total,
                                strokeWidth: 5,
                                color: p.gold,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (complete)
                                  const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                                Text(
                                  circleText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!complete)
                                  Text(
                                    'চাপ দিন',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _index < widget.duas.length - 1 ? 'পরের' : 'শেষ',
                  onPressed: () {
                    _next?.cancel();
                    _advance();
                  },
                  icon: const Icon(Icons.chevron_right_rounded, size: 32),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _count = 0),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('আবার গুনুন'),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ------------------------------------------------------------ favourites

List<Dua> favoriteDuas() =>
    AppState.instance.settings.duaFavorites.map(Duas.byId).nonNulls.toList();

class DuaFavoriteList extends StatelessWidget {
  const DuaFavoriteList({super.key});

  @override
  Widget build(BuildContext context) {
    final duas = favoriteDuas();
    return Column(
      children: [
        for (var i = 0; i < duas.length; i++)
          DuaRow(
            dua: duas[i],
            onTap: () => push(context, DuaPagerScreen(duas: duas, index: i)),
          ),
      ],
    );
  }
}
