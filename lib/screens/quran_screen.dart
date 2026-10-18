import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/quran.dart';
import '../theme.dart';
import '../widgets/quran_widgets.dart';
import '../widgets/night.dart';
import '../widgets/ui.dart';
import 'favorites_screen.dart';
import 'quran_downloads_screen.dart';
import 'quran_reader_screen.dart';

/// Opens the reader at an ayah.
Future<void> openQuran(BuildContext context, int surah, [int ayah = 1]) =>
    push(context, QuranReaderScreen(surah: surah, ayah: ayah));

/// কুরআন tab: search, "যেখানে শেষ করেছিলেন", and the surah / para lists.
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _q = '';
  List<AyahRef> _ayahs = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Get the text ready for searching in the background.
    unawaited(Quran.load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    setState(() => _q = v.trim());
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final q = _q;
    if (q.length < 2 || Quran.parseRef(q) != null) {
      setState(() => _ayahs = const []);
      return;
    }
    setState(() => _searching = true);
    await Quran.load();
    for (final id in AppState.instance.settings.quran.translations) {
      await Quran.loadTranslation(id);
    }
    final r = Quran.searchAyahs(q);
    if (!mounted || q != _q) return;
    setState(() {
      _ayahs = r;
      _searching = false;
    });
  }

  /// সূরা or পারা list.
  bool _juz = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final searching = _q.isNotEmpty;
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: NightHeader(
                title: 'আল-কুরআন',
                subtitle: '১১৪টি সূরা · আরবি ও বাংলা অনুবাদ',
                lip: true,
                child: _LastReadCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _query,
                  onChanged: _onQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'সূরার নাম, নম্বর, "২:২৫৫" বা যেকোনো শব্দ',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'মুছুন',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _query.clear();
                              _onQuery('');
                            },
                          ),
                  ),
                ),
              ),
            ),
            if (searching)
              SliverToBoxAdapter(child: _results(p))
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: ActionRow(
                    children: [
                      LabeledAction(
                        icon: Icons.bookmarks_outlined,
                        label: 'বুকমার্ক',
                        tint: p.iconTint,
                        onTap: () => push(context, const FavoritesScreen(initialTab: 2)),
                      ),
                      LabeledAction(
                        icon: Icons.text_fields_rounded,
                        label: 'পড়ার সেটিং',
                        tint: p.iconTint,
                        onTap: () => showQuranSettingsSheet(context),
                      ),
                      LabeledAction(
                        icon: Icons.download_for_offline_outlined,
                        label: 'ডাউনলোড',
                        tint: p.iconTint,
                        onTap: () => push(context, const QuranDownloadsScreen()),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('সূরা')),
                      ButtonSegment(value: true, label: Text('পারা')),
                    ],
                    selected: {_juz},
                    onSelectionChanged: (v) => setState(() => _juz = v.first),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: DecoratedSliver(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(radiusM),
                    border: Border.all(color: p.border),
                  ),
                  sliver: _juz ? const _JuzList() : const _SurahList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _results(Palette p) {
    final ref = Quran.parseRef(_q);
    final surahs = Quran.searchSurahs(_q);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ref != null)
            AppCard(
              onTap: () => openQuran(context, ref.surah, ref.ayah),
              child: Row(
                children: [
                  Icon(Icons.north_east_rounded, color: p.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${ayahTitle(ref.surah, ref.ayah)} খুলুন',
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                    ),
                  ),
                ],
              ),
            ),
          if (surahs.isNotEmpty) ...[
            const SectionLabel('সূরা'),
            RowGroup(children: [for (final s in surahs.take(20)) SurahRow(surah: s)]),
          ],
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_ayahs.isNotEmpty) ...[
            SectionLabel(
              _ayahs.length >= 300
                  ? 'আয়াত (প্রথম ৩০০টি)'
                  : 'আয়াত (${toBanglaDigits(_ayahs.length)}টি)',
            ),
            for (final r in _ayahs) AyahSearchHit(ref: r, query: _q),
          ] else if (ref == null && surahs.isEmpty && _q.length >= 2)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('কিছু পাওয়া যায়নি', style: TextStyle(color: p.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

class AyahSearchHit extends StatelessWidget {
  const AyahSearchHit({super.key, required this.ref, required this.query});

  final AyahRef ref;
  final String query;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final i = Quran.indexOf(ref.surah, ref.ayah);
    final arabicQuery = RegExp('[؀-ۿ]').hasMatch(query);
    final t = shownTranslations().firstOrNull ?? Quran.loaded['bn_zakaria'];
    final text = arabicQuery || t == null ? Quran.displayArabic(ref.surah, ref.ayah) : t.text[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => openQuran(context, ref.surah, ref.ayah),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ayahTitle(ref.surah, ref.ayah),
              style: TextStyle(color: p.primary, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textDirection: arabicQuery ? TextDirection.rtl : null,
              style: TextStyle(
                fontFamily: arabicQuery ? arabicFont : banglaFont,
                fontSize: arabicQuery ? 20 : 15,
                height: arabicQuery ? 1.9 : 1.6,
                color: p.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "যেখানে শেষ করেছিলেন" with a continue button (Quran tab and Today).
class QuranContinueCard extends StatelessWidget {
  const QuranContinueCard({super.key, this.showWhenEmpty = false});

  /// On the Today screen: "কুরআন পড়া শুরু করুন" when nothing was read yet.
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final prefs = AppState.instance.settings.quran;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final has = prefs.hasLastRead && Quran.isValid(prefs.lastSurah, prefs.lastAyah);
        if (!has && !showWhenEmpty) return const SizedBox.shrink();
        final p = context.palette;
        final s = has ? Quran.surah(prefs.lastSurah) : null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radiusL),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              color: p.night,
              child: InkWell(
                onTap: () => has
                    ? openQuran(context, prefs.lastSurah, prefs.lastAyah)
                    : openQuran(context, 1),
                child: Stack(
                  children: [
                    const GirihLayer(cell: 44, opacity: 0.16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book_outlined, color: p.gold, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      has ? 'যেখানে শেষ করেছিলেন' : 'কুরআন পড়ুন',
                                      style: TextStyle(color: p.onNightMuted, fontSize: 14),
                                    ),
                                    Text(
                                      has
                                          ? 'সূরা ${s!.nameBn} · আয়াত ${toBanglaDigits(prefs.lastAyah)}'
                                          : 'আরবি ও বাংলা অর্থসহ পুরো কুরআন',
                                      style: TextStyle(
                                        color: p.onNight,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GoldButton(
                            onPressed: () => has
                                ? openQuran(context, prefs.lastSurah, prefs.lastAyah)
                                : openQuran(context, 1),
                            icon: Icons.play_arrow_rounded,
                            label: has ? 'চালিয়ে যান' : 'শুরু করুন',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "শেষ পড়েছেন" inside the Quran header, with the gold "চালিয়ে যান" button.
class _LastReadCard extends StatelessWidget {
  const _LastReadCard();

  @override
  Widget build(BuildContext context) {
    final prefs = AppState.instance.settings.quran;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final p = context.palette;
        final has = prefs.hasLastRead && Quran.isValid(prefs.lastSurah, prefs.lastAyah);
        final s = has ? Quran.surah(prefs.lastSurah) : null;
        void open() =>
            has ? openQuran(context, prefs.lastSurah, prefs.lastAyah) : openQuran(context, 1);
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: p.nightLine,
            borderRadius: BorderRadius.circular(radiusM),
          ),
          child: Row(
            children: [
              Icon(Icons.bookmark_outline_rounded, color: p.gold, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      has ? 'শেষ পড়েছেন' : 'কুরআন পড়ুন',
                      style: TextStyle(color: p.onNightMuted, fontSize: 14),
                    ),
                    Text(
                      has
                          ? 'সূরা ${s!.nameBn} · আয়াত ${toBanglaDigits(prefs.lastAyah)}'
                          : 'সূরা আল-ফাতিহা থেকে শুরু',
                      style: TextStyle(color: p.onNight, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GoldButton(onPressed: open, label: has ? 'চালিয়ে যান' : 'শুরু করুন'),
            ],
          ),
        );
      },
    );
  }
}

/// Number, Bangla + Arabic name, meaning, মাক্কী/মাদানী and ayah count.
class SurahRow extends StatelessWidget {
  const SurahRow({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: () => openQuran(context, surah.n),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            StarBadge(toBanglaDigits(surah.n), size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.nameBn,
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.text),
                  ),
                  Text(
                    '${surah.meaningBn}, ${toBanglaDigits(surah.ayahCount)} আয়াত, ${surah.typeBn}',
                    style: TextStyle(fontSize: 14, color: p.muted),
                  ),
                ],
              ),
            ),
            Text(
              surah.nameAr,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: arabicFont, fontSize: 22, color: p.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SliverList.separated(
      itemCount: Quran.surahs.length,
      separatorBuilder: (_, _) => Divider(height: 1, indent: 70, color: p.border),
      itemBuilder: (context, i) => SurahRow(surah: Quran.surahs[i]),
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SliverList.separated(
      itemCount: Quran.juz.length,
      separatorBuilder: (_, _) => Divider(height: 1, indent: 70, color: p.border),
      itemBuilder: (context, i) {
        final j = Quran.juz[i];
        return InkWell(
          onTap: () => openQuran(context, j.surah, j.ayah),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                StarBadge(toBanglaDigits(j.n), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'পারা ${toBanglaDigits(j.n)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
                      ),
                      Text(
                        'শুরু: সূরা ${Quran.surah(j.surah).nameBn}, আয়াত ${toBanglaDigits(j.ayah)}',
                        style: TextStyle(fontSize: 14, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  j.nameAr,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: arabicFont, fontSize: 20, color: p.primary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
