import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/reminders.dart';
import '../services/rotation.dart';
import '../theme.dart';
import '../utils/bangla.dart';
import '../widgets/category_style.dart';
import '../widgets/item_view.dart';
import '../widgets/pattern.dart';
import 'credits_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _ayahOffset = 0;
  int _hadithOffset = 0;

  void _open(ContentItem item) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReadingScreen(item: item)));

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final p = context.palette;
    final now = Reminders.nowDhaka();
    final today = Rotation.dayNumber(now);
    final ayah = state.rotation.morning(today + _ayahOffset);
    final hadith = state.rotation.hadithFor(today + _hadithOffset);

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: state.settings,
          builder: (context, _) {
            final marks = state.settings.readMarks;
            final todayKey = dateKey(now);
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                _Header(now: now),
                const SizedBox(height: 18),
                _ReminderStrip(),
                const SizedBox(height: 18),
                if (ayah != null)
                  _AyahHeroCard(
                    item: ayah,
                    isToday: _ayahOffset == 0,
                    read: _ayahOffset == 0 && marks.contains('$todayKey-morning'),
                    onOpen: () => _open(ayah),
                    onPrev: () => setState(() => _ayahOffset--),
                    onNext: () => setState(() => _ayahOffset++),
                    onToday: () => setState(() => _ayahOffset = 0),
                  ),
                const SizedBox(height: 22),
                if (hadith != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.nightlight_round, size: 20, color: p.accent),
                        const SizedBox(width: 8),
                        Text(
                          _hadithOffset == 0 ? 'আজকের হাদিস' : 'হাদিস',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        if (_hadithOffset == 0 && marks.contains('$todayKey-night'))
                          const _ReadBadge(),
                      ],
                    ),
                  ),
                  _HadithCard(
                    item: hadith,
                    isToday: _hadithOffset == 0,
                    onOpen: () => _open(hadith),
                    onPrev: () => setState(() => _hadithOffset--),
                    onNext: () => setState(() => _hadithOffset++),
                    onToday: () => setState(() => _hadithOffset = 0),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আসসালামু আলাইকুম',
                style: TextStyle(fontFamily: headingFont, fontSize: 14, color: p.muted),
              ),
              const SizedBox(height: 2),
              Text(greeting(now.hour), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                banglaDate(now),
                style: TextStyle(
                  fontFamily: headingFont,
                  fontSize: 13.5,
                  color: p.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'কৃতজ্ঞতা ও উৎস',
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreditsScreen())),
          icon: const AppLogo(size: 44),
        ),
      ],
    );
  }
}

/// Shows the two reminder times; tap to change them.
class _ReminderStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    Widget pill(IconData icon, String label, String time) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: p.muted)),
                  Text(
                    s.remindersOn ? time : 'বন্ধ',
                    style: TextStyle(
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      child: Row(
        children: [
          pill(Icons.wb_sunny_rounded, 'সকালের আয়াত', SettingsScreen.formatTime(s.morningTime)),
          const SizedBox(width: 10),
          pill(
            Icons.nightlight_round,
            s.hadithAtNight ? 'রাতের হাদিস' : 'রাতের আয়াত',
            SettingsScreen.formatTime(s.nightTime),
          ),
        ],
      ),
    );
  }
}

class _ReadBadge extends StatelessWidget {
  const _ReadBadge({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = onDark ? Colors.white : p.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.14) : p.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 15, color: fg),
          const SizedBox(width: 4),
          Text(
            'পড়া হয়েছে',
            style: TextStyle(
              fontFamily: headingFont,
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's ayah: large card with a soft gradient and geometric pattern.
class _AyahHeroCard extends StatelessWidget {
  const _AyahHeroCard({
    required this.item,
    required this.isToday,
    required this.read,
    required this.onOpen,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final ContentItem item;
  final bool isToday;
  final bool read;
  final VoidCallback onOpen;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.heroEnd, p.heroStart, Brand.night],
          stops: const [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Brand.emerald.withValues(alpha: p.isDark ? 0.0 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            child: Stack(
              children: [
                const PatternLayer(color: Brand.lightGold, opacity: 0.08, cell: 52),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wb_sunny_rounded, color: Brand.lightGold, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isToday ? 'আজকের আয়াত' : 'আয়াত',
                            style: const TextStyle(
                              fontFamily: headingFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 19,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (read) const _ReadBadge(onDark: true),
                          const Spacer(),
                          FavoriteButton(item, color: Colors.white70),
                          ShareButton(item, color: Colors.white70),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CategoryChip(item, onDark: true),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ArabicText(item.arabic, size: 27, maxLines: 5, color: Brand.cream),
                      ),
                      const OrnamentDivider(color: Brand.lightGold),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BanglaText(
                          item.bangla,
                          size: 16,
                          maxLines: 6,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 10),
                      BanglaText(
                        item.title,
                        size: 13.5,
                        color: Brand.lightGold,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 6),
                      _Pager(
                        onDark: true,
                        isToday: isToday,
                        onPrev: onPrev,
                        onNext: onNext,
                        onToday: onToday,
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
  }
}

class _HadithCard extends StatelessWidget {
  const _HadithCard({
    required this.item,
    required this.isToday,
    required this.onOpen,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final ContentItem item;
  final bool isToday;
  final VoidCallback onOpen;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = CategoryStyle.of(item.categoryId);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusL),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              width: 150,
              height: 150,
              child: Stack(
                children: [PatternLayer(color: style.foreground(p), opacity: 0.12, cell: 40)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(child: CategoryChip(item)),
                      const Spacer(),
                      FavoriteButton(item),
                      ShareButton(item),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ArabicText(item.arabic, size: 21, maxLines: 4),
                  ),
                  const OrnamentDivider(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BanglaText(item.bangla, size: 15.5, maxLines: 6),
                  ),
                  const SizedBox(height: 8),
                  BanglaText(item.title, size: 13.5, color: p.primary, weight: FontWeight.w700),
                  const SizedBox(height: 4),
                  _Pager(isToday: isToday, onPrev: onPrev, onNext: onNext, onToday: onToday),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// আগের / পরের buttons.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    this.onDark = false,
  });

  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = onDark ? Colors.white : p.primary;
    final bg = onDark ? Colors.white.withValues(alpha: 0.12) : p.primary.withValues(alpha: 0.08);
    Widget btn(String label, IconData icon, VoidCallback onTap, {bool iconFirst = true}) {
      final children = [
        Icon(icon, size: 20, color: fg),
        Text(
          label,
          style: TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w600, color: fg),
        ),
      ];
      return Material(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(children: iconFirst ? children : children.reversed.toList()),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4),
      child: Row(
        children: [
          btn('আগের', Icons.chevron_left_rounded, onPrev),
          Expanded(
            child: Center(
              child: isToday
                  ? Text(
                      'পুরোটা পড়তে ছুঁয়ে দিন',
                      style: TextStyle(fontSize: 11.5, color: onDark ? Colors.white60 : p.muted),
                    )
                  : TextButton(
                      onPressed: onToday,
                      child: Text(
                        'আজ',
                        style: TextStyle(color: onDark ? Brand.lightGold : p.accent),
                      ),
                    ),
            ),
          ),
          btn('পরের', Icons.chevron_right_rounded, onNext, iconFirst: false),
        ],
      ),
    );
  }
}
