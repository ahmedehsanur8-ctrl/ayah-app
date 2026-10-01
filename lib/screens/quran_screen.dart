import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/quran.dart';
import '../theme.dart';
import '../widgets/pattern.dart';
import '../widgets/quran_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: const PageTitle('আল-কুরআন', subtitle: '১১৪টি সূরা · আরবি ও বাংলা অনুবাদ'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
              ),
              if (_q.isNotEmpty)
                Expanded(child: _results(p))
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ActionRow(
                    children: [
                      LabeledAction(
                        icon: Icons.bookmarks_outlined,
                        label: 'বুকমার্ক',
                        tint: p.sand,
                        onTap: () => push(context, const FavoritesScreen(initialTab: 2)),
                      ),
                      LabeledAction(
                        icon: Icons.text_fields_rounded,
                        label: 'পড়ার সেটিং',
                        tint: p.sky,
                        onTap: () => showQuranSettingsSheet(context),
                      ),
                      LabeledAction(
                        icon: Icons.download_for_offline_outlined,
                        label: 'ডাউনলোড',
                        tint: p.mint,
                        onTap: () => push(context, const QuranDownloadsScreen()),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: QuranContinueCard(),
                ),
                TabBar(
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  tabs: const [
                    Tab(text: 'সূরা'),
                    Tab(text: 'পারা'),
                  ],
                ),
                const Expanded(child: TabBarView(children: [_SurahList(), _JuzList()])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _results(Palette p) {
    final ref = Quran.parseRef(_q);
    final surahs = Quran.searchSurahs(_q);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.greenCard, p.greenCardDark],
                ),
              ),
              child: InkWell(
                onTap: () => has
                    ? openQuran(context, prefs.lastSurah, prefs.lastAyah)
                    : openQuran(context, 1),
                child: Stack(
                  children: [
                    const PatternLayer(color: Brand.gold, opacity: 0.07, cell: 44),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, color: Brand.gold, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  has ? 'যেখানে শেষ করেছিলেন' : 'কুরআন পড়ুন',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  has
                                      ? 'সূরা ${s!.nameBn} · আয়াত ${toBanglaDigits(prefs.lastAyah)}'
                                      : 'আরবি ও বাংলা অর্থসহ পুরো কুরআন',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => has
                                ? openQuran(context, prefs.lastSurah, prefs.lastAyah)
                                : openQuran(context, 1),
                            style: FilledButton.styleFrom(
                              backgroundColor: Brand.gold,
                              foregroundColor: Brand.greenDark,
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(has ? 'চালিয়ে যান' : 'শুরু করুন'),
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
            AyahBadge(surah.n, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.nameBn,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
                  ),
                  Text(
                    '${surah.meaningBn} · ${surah.typeBn} · ${toBanglaDigits(surah.ayahCount)} আয়াত',
                    style: TextStyle(fontSize: 14, color: p.muted),
                  ),
                ],
              ),
            ),
            Text(
              surah.nameAr,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: arabicFont, fontSize: 21, color: p.goldText),
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
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: Quran.surahs.length,
      separatorBuilder: (_, _) => Divider(height: 1, indent: 66, color: p.border),
      itemBuilder: (context, i) => SurahRow(surah: Quran.surahs[i]),
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: Quran.juz.length,
      separatorBuilder: (_, _) => Divider(height: 1, indent: 66, color: p.border),
      itemBuilder: (context, i) {
        final j = Quran.juz[i];
        return InkWell(
          onTap: () => openQuran(context, j.surah, j.ayah),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                AyahBadge(j.n, size: 40),
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
                  style: TextStyle(fontFamily: arabicFont, fontSize: 19, color: p.goldText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
