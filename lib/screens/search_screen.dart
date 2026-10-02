import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../models/topics.dart';
import '../services/duas.dart';
import '../services/quran.dart';
import '../theme.dart';
import '../widgets/category_style.dart';
import '../widgets/ui.dart';
import '../features/learn/ui/screens/learn_screens.dart';
import 'arabic_screens.dart';
import 'collection_screen.dart';
import 'dua_screens.dart';
import 'favorites_screen.dart';
import 'home_shell.dart';
import 'mood_screen.dart';
import 'prayer_screen.dart';
import 'qibla_screen.dart';
import 'quran_screen.dart';
import 'settings_screen.dart';
import 'tasbih_screen.dart';

/// A feature of the app that search can open.
class _Feature {
  const _Feature(this.name, this.icon, this.words, this.open);

  final String name;
  final IconData icon;

  /// Other words people may type for it.
  final String words;
  final void Function(BuildContext) open;
}

void _tab(BuildContext context, int tab) {
  HomeShell.tab.value = tab;
  Navigator.of(context).popUntil((r) => r.isFirst);
}

final _features = <_Feature>[
  _Feature('নামাজের সময়', Icons.schedule_outlined, 'নামাজ আজান ওয়াক্ত ফজর যোহর আসর মাগরিব এশা', (
    c,
  ) {
    push(c, const PrayerScreen());
  }),
  _Feature('কিবলা', Icons.explore_outlined, 'কম্পাস দিক কাবা', (c) => push(c, const QiblaScreen())),
  _Feature('তাসবিহ', Icons.touch_app_outlined, 'তসবিহ গণনা জিকির সুবহানাল্লাহ', (c) {
    push(c, const TasbihScreen());
  }),
  _Feature('দোয়া ও জিকির', Icons.front_hand_outlined, 'দোআ দুআ জিকির আজকার', (c) {
    _tab(c, HomeShell.duas);
  }),
  _Feature('আল-কুরআন', Icons.menu_book_outlined, 'কোরআন কুরান সূরা পারা তিলাওয়াত', (c) {
    _tab(c, HomeShell.quran);
  }),
  _Feature('মন কেমন?', Icons.sentiment_satisfied_outlined, 'মন অনুভূতি বিষয়', (c) {
    _tab(c, HomeShell.mood);
  }),
  _Feature('সাহাবিদের জীবনী', Icons.auto_stories_outlined, 'জীবনী গল্প সাহাবি', (c) {
    _tab(c, HomeShell.stories);
  }),
  _Feature('প্রিয়', Icons.favorite_border_rounded, 'ফেভারিট সংরক্ষিত বুকমার্ক', (c) {
    push(c, const FavoritesScreen());
  }),
  _Feature('কুরআন বুঝি', Icons.translate_rounded, 'শব্দ অর্থ শিখি বুঝি রিভিউ আরবি', (c) {
    push(c, const LearnDashboardScreen());
  }),
  _Feature('সহজ আরবি', Icons.school_outlined, 'আরবি শিখি অক্ষর তাজবীদ', (c) {
    push(c, const ArabicHomeScreen());
  }),
  _Feature('সেটিংস', Icons.settings_outlined, 'রিমাইন্ডার সময় ডার্ক মোড লেখার আকার অনুমতি', (c) {
    push(c, const SettingsScreen());
  }),
];

/// খুঁজুন: one search for features, surahs, ayahs, duas, moods and topics.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _q = '';
  List<AyahRef> _ayahs = const [];

  @override
  void initState() {
    super.initState();
    unawaited(Quran.load());
    unawaited(Duas.load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    setState(() {
      _q = v.trim();
      _ayahs = const [];
    });
    _debounce = Timer(const Duration(milliseconds: 300), _searchAyahs);
  }

  Future<void> _searchAyahs() async {
    final q = _q;
    if (q.length < 2) return;
    await Quran.load();
    for (final id in AppState.instance.settings.quran.translations) {
      await Quran.loadTranslation(id);
    }
    final r = Quran.searchAyahs(q);
    if (!mounted || q != _q) return;
    setState(() => _ayahs = r.take(30).toList());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _q;
    final data = AppState.instance.data;
    final features = q.isEmpty
        ? _features
        : _features.where((f) => f.name.contains(q) || f.words.contains(q)).toList();
    final ok = q.length >= 2;
    final surahs = ok ? Quran.searchSurahs(q).take(10).toList() : const <Surah>[];
    final moods = ok ? data.moods.where((m) => m.name.contains(q)).toList() : const <Mood>[];
    final topics = ok
        ? [
            for (final g in topicGroups)
              for (final t in g.topics)
                if (t.name.contains(q)) t,
          ]
        : const <Topic>[];
    final duas = ok ? Duas.search(q).take(15).toList() : const <Dua>[];
    final nothing =
        ok &&
        features.isEmpty &&
        surahs.isEmpty &&
        moods.isEmpty &&
        topics.isEmpty &&
        duas.isEmpty &&
        _ayahs.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('খুঁজুন')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'যেমন: কিবলা, ফাতিহা, ধৈর্য, সফরের দোয়া',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isEmpty
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
          if (features.isNotEmpty) ...[
            SectionLabel(q.isEmpty ? 'সব ফিচার' : 'ফিচার'),
            RowGroup(
              children: [
                for (final f in features)
                  NavRow(icon: f.icon, title: f.name, onTap: () => f.open(context)),
              ],
            ),
          ],
          if (surahs.isNotEmpty) ...[
            const SectionLabel('সূরা'),
            RowGroup(children: [for (final s in surahs) SurahRow(surah: s)]),
          ],
          if (moods.isNotEmpty || topics.isNotEmpty) ...[
            const SectionLabel('মন ও বিষয়'),
            RowGroup(
              children: [
                for (final m in moods)
                  NavRow(
                    icon: CategoryStyle.of(m.id).icon,
                    tint: CategoryStyle.of(m.id).tintOf(p),
                    title: m.name,
                    subtitle: 'মন',
                    onTap: () => MoodScreen.open(context, m),
                  ),
                for (final t in topics)
                  NavRow(
                    icon: CategoryStyle.of(t.id).icon,
                    tint: CategoryStyle.of(t.id).tintOf(p),
                    title: t.name,
                    subtitle: 'বিষয়',
                    onTap: () {
                      final items = t.items(data);
                      push(
                        context,
                        CollectionScreen(
                          styleId: t.id,
                          title: t.name,
                          ayahs: items.where((i) => i.isAyah).toList(),
                          hadiths: items.where((i) => !i.isAyah).toList(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          if (duas.isNotEmpty) ...[
            const SectionLabel('দোয়া'),
            for (var i = 0; i < duas.length; i++)
              DuaRow(
                dua: duas[i],
                onTap: () => push(context, DuaPagerScreen(duas: duas, index: i)),
              ),
          ],
          if (_ayahs.isNotEmpty) ...[
            const SectionLabel('কুরআনের আয়াত'),
            for (final r in _ayahs) AyahSearchHit(ref: r, query: q),
          ],
          if (nothing)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'কিছু পাওয়া যায়নি। অন্য শব্দ লিখে দেখুন।',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }
}
