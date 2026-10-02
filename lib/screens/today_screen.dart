import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/audio.dart';
import '../services/prayer.dart';
import '../services/reminders.dart';
import '../services/rotation.dart';
import '../theme.dart';
import '../utils/bangla.dart';
import '../widgets/audio_button.dart';
import '../widgets/item_view.dart';
import '../widgets/night.dart';
import '../widgets/pattern.dart';
import '../widgets/ui.dart';
import '../features/learn/state/learn_controller.dart';
import 'home_shell.dart';
import '../features/learn/ui/screens/learn_screens.dart';
import 'arabic_screens.dart';
import 'dua_screens.dart';
import 'favorites_screen.dart';
import 'prayer_screen.dart';
import 'qibla_screen.dart';
import 'quran_screen.dart';
import 'reader_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';
import 'tasbih_screen.dart';

/// আজ (Home): a night header with the greeting, dates and the next prayer,
/// then a sheet with quick actions, today's ayah and hadith, কুরআন বুঝি,
/// adhkar, the Quran continue card and সহজ আরবি.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _ayahOffset = 0;
  int _hadithOffset = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final now = Reminders.nowDhaka();
    final today = Rotation.dayNumber(now);
    final ayah = state.rotation.morning(today + _ayahOffset);
    final hadith = state.rotation.hadithFor(today + _hadithOffset);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListenableBuilder(
          listenable: state.settings,
          builder: (context, _) {
            final marks = state.settings.readMarks;
            final todayKey = dateKey(now);
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _HomeHeader(now: now),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SetupBanner(),
                      const _QuickActions(),
                      const SizedBox(height: 18),
                      if (ayah != null)
                        _AyahCard(
                          item: ayah,
                          isToday: _ayahOffset == 0,
                          read: _ayahOffset == 0 && marks.contains('$todayKey-morning'),
                          onPrev: () => setState(() => _ayahOffset--),
                          onNext: () => setState(() => _ayahOffset++),
                          onToday: () => setState(() => _ayahOffset = 0),
                        ),
                      if (hadith != null) ...[
                        SectionLabel(
                          _hadithOffset == 0 ? 'আজকের হাদিস' : 'হাদিস',
                          trailing: _hadithOffset == 0 && marks.contains('$todayKey-night')
                              ? const _ReadBadge()
                              : null,
                        ),
                        _HadithCard(
                          item: hadith,
                          isToday: _hadithOffset == 0,
                          onPrev: () => setState(() => _hadithOffset--),
                          onNext: () => setState(() => _hadithOffset++),
                          onToday: () => setState(() => _hadithOffset = 0),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _LearnCard(),
                      const SizedBox(height: 16),
                      const AdhkarCard(showAllButton: true),
                      const SizedBox(height: 16),
                      const QuranContinueCard(showWhenEmpty: true),
                      const SizedBox(height: 16),
                      const _ArabicCard(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The next reminder time, e.g. "রাত ৯:০০" (null when reminders are off).
String? nextReminderText() {
  final s = AppState.instance.settings;
  if (!s.remindersOn) return null;
  final now = Reminders.nowDhaka();
  final times = [
    s.morningTime,
    s.nightTime,
  ].map((t) => DateTime(now.year, now.month, now.day, t.hour, t.minute)).toList();
  final today = times.where((t) => t.isAfter(now)).toList()..sort();
  final next = today.isNotEmpty ? today.first : (times..sort()).first.add(const Duration(days: 1));
  return formatClock(next);
}

/// Night header: greeting, Bangla and Hijri dates, search / প্রিয় / সেটিংস,
/// the next prayer with a live countdown and the five prayer chips.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final next = nextReminderText();
    return NightHeader(
      lip: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'আসসালামু আলাইকুম',
                        style: TextStyle(color: p.gold, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Semantics(
                        header: true,
                        child: Text(greeting(now.hour), style: nightTitleStyle(p, size: 26)),
                      ),
                    ],
                  ),
                ),
              ),
              NightIconButton(
                icon: Icons.search_rounded,
                tooltip: 'খুঁজুন',
                onPressed: () => push(context, const SearchScreen()),
              ),
              NightIconButton(
                icon: Icons.favorite_border_rounded,
                tooltip: 'প্রিয়',
                onPressed: () => push(context, const FavoritesScreen()),
              ),
              NightIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'সেটিংস',
                onPressed: () => push(context, const SettingsScreen()),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '${banglaDate(now)} · ${hijriDate(now)}',
              style: TextStyle(color: p.onNightMuted, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 8),
          NightPill(
            icon: next == null
                ? Icons.notifications_off_outlined
                : Icons.notifications_none_rounded,
            text: next == null ? 'রিমাইন্ডার বন্ধ' : 'পরের রিমাইন্ডার $next',
          ),
          const SizedBox(height: 16),
          const Padding(padding: EdgeInsets.only(right: 12), child: NextPrayerHero()),
        ],
      ),
    );
  }
}

/// "পরের নামাজ": the prayer name in large gold serif, time, live countdown,
/// location, and today's five prayers as chips (the next one in gold).
/// Opens the prayer times page.
class NextPrayerHero extends StatefulWidget {
  const NextPrayerHero({super.key});

  @override
  State<NextPrayerHero> createState() => _NextPrayerHeroState();
}

class _NextPrayerHeroState extends State<NextPrayerHero> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    final now = DateTime.now();
    final next = Prayers.next(s, now);
    void open() => push(context, const PrayerScreen());
    if (next == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('নামাজের সময়', style: nightTitleStyle(p, size: 22)),
          Text('দেখতে আপনার এলাকা বেছে নিন', style: TextStyle(color: p.onNightMuted, fontSize: 15)),
          const SizedBox(height: 10),
          GoldButton(label: 'এলাকা বেছে নিন', icon: Icons.location_on_outlined, onPressed: open),
        ],
      );
    }
    final today = [
      for (final x in Prayers.forDay(s, now))
        if (!x.isSunrise) x,
    ];
    return Semantics(
      button: true,
      label: 'পরের নামাজ ${next.name}, ${formatClock(next.time)}। নামাজের সময় দেখুন',
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(radiusM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'পরের নামাজ',
              style: TextStyle(color: p.onNightMuted, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              children: [
                Text(
                  next.name,
                  style: titleStyle(
                    p,
                    size: 36,
                  ).copyWith(color: p.gold, fontWeight: FontWeight.w700, height: 1.25),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    formatClock(next.time),
                    style: TextStyle(color: p.onNight, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, size: 18, color: p.gold),
                    const SizedBox(width: 4),
                    Text(
                      'আর ${formatCountdown(next.time.difference(now))}',
                      style: TextStyle(color: p.onNight, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (s.placeName.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: p.gold),
                      const SizedBox(width: 2),
                      Text(s.placeName, style: TextStyle(color: p.onNightMuted, fontSize: 14)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < today.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _PrayerChip(
                      prayer: today[i],
                      current: today[i].key == next.key && _sameDay(today[i].time, next.time),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _PrayerChip extends StatelessWidget {
  const _PrayerChip({required this.prayer, required this.current});

  final PrayerTime prayer;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = current ? p.night : p.onNight;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        color: current ? p.gold : p.nightLine,
        borderRadius: BorderRadius.circular(14),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Text(
              prayer.name,
              style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              formatClock(prayer.time, withPart: false),
              style: TextStyle(color: fg, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// কুরআন, কিবলা, তাসবিহ, দোয়া: emerald icons on soft emerald squares.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                IconSquare(icon, size: 56),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.palette.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        action(Icons.menu_book_outlined, 'কুরআন', () => HomeShell.tab.value = HomeShell.quran),
        action(Icons.explore_outlined, 'কিবলা', () => push(context, const QiblaScreen())),
        action(Icons.touch_app_outlined, 'তাসবিহ', () => push(context, const TasbihScreen())),
        action(Icons.front_hand_outlined, 'দোয়া', () => HomeShell.tab.value = HomeShell.duas),
      ],
    );
  }
}

class _ReadBadge extends StatelessWidget {
  const _ReadBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.palette.mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 15, color: t.foreground),
          const SizedBox(width: 4),
          Text(
            'পড়া হয়েছে',
            style: TextStyle(fontSize: 14, color: t.foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard({
    required this.item,
    required this.isToday,
    required this.read,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final ContentItem item;
  final bool isToday;
  final bool read;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      radius: radiusL,
      onTap: () => push(context, ReaderScreen(items: [item])),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppLogo(size: 30, withBackground: false),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isToday ? 'আজকের আয়াত' : 'আয়াত'} · ${item.category}',
                      style: TextStyle(
                        color: p.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: titleFont,
                      ),
                    ),
                    Text(item.title, style: TextStyle(color: p.goldText, fontSize: 14)),
                  ],
                ),
              ),
              if (read) const _ReadBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ArabicText(item.arabic, size: 26, color: p.arabic),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OrnamentDivider(color: p.gold),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BanglaText(item.banglaPlain, size: 16.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _ListenButton(item)),
              FavoriteButton(item),
              ShareButton(item),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('আগের'),
              ),
              const Spacer(),
              if (!isToday) TextButton(onPressed: onToday, child: const Text('আজকের আয়াতে ফিরুন')),
              const Spacer(),
              TextButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                iconAlignment: IconAlignment.end,
                label: const Text('পরের'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Emerald "শুনুন" button for the ayah card.
class _ListenButton extends StatefulWidget {
  const _ListenButton(this.item);

  final ContentItem item;

  @override
  State<_ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<_ListenButton> {
  final _audio = AudioController.instance;
  int _seen = AudioController.instance.problemCount;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_changed);
  }

  @override
  void dispose() {
    _audio.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (_audio.problemCount != _seen && _audio.currentId == widget.item.id) {
      _seen = _audio.problemCount;
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = _audio.isActive(widget.item.id);
    final loading = active && _audio.status == AudioStatus.loading;
    return FilledButton.icon(
      onPressed: () => _audio.toggleItem(widget.item),
      icon: loading
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: p.onPrimary),
            )
          : Icon(active ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 26),
      label: Text(active ? 'থামান' : 'শুনুন'),
    );
  }
}

class _HadithCard extends StatelessWidget {
  const _HadithCard({
    required this.item,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final ContentItem item;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      radius: radiusL,
      onTap: () => push(context, ReaderScreen(items: [item])),
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category,
                  style: TextStyle(color: p.goldText, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              ItemAudioButton(item),
              FavoriteButton(item),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: BanglaText(item.banglaPlain, size: 16, maxLines: 7),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: p.goldText,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: p.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (item.subtitle.isNotEmpty)
                        Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.muted, fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('আগের'),
              ),
              const Spacer(),
              if (!isToday) TextButton(onPressed: onToday, child: const Text('আজ')),
              const Spacer(),
              TextButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                iconAlignment: IconAlignment.end,
                label: const Text('পরের'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// কুরআন বুঝি: lessons done, words in review and the streak. Opens the dashboard.
class _LearnCard extends StatefulWidget {
  const _LearnCard();

  @override
  State<_LearnCard> createState() => _LearnCardState();
}

class _LearnCardState extends State<_LearnCard> {
  @override
  void initState() {
    super.initState();
    Learn.instance.ensureReady().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final learn = Learn.instance;
    return ListenableBuilder(
      listenable: learn,
      builder: (context, _) {
        final total = learn.lessons.length;
        final done = learn.lessonsDone;
        final started = learn.ready && (done > 0 || learn.known.isNotEmpty);
        return AppCard(
          key: const ValueKey('learn-card'),
          radius: radiusL,
          onTap: () => push(context, const LearnDashboardScreen()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconSquare(Icons.translate_rounded, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'কুরআন বুঝি',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                            fontFamily: titleFont,
                          ),
                        ),
                        Text(
                          started
                              ? '${toBanglaDigits(done)}/${toBanglaDigits(total)} পাঠ, '
                                    '${toBanglaDigits(learn.known.length)}টি শব্দ'
                                    '${learn.streak > 0 ? ', ${toBanglaDigits(learn.streak)} দিন টানা' : ''}'
                              : 'আয়াতের শব্দ চিনে অর্থ বুঝি, প্রতিদিন কয়েক মিনিট',
                          style: TextStyle(fontSize: 14, height: 1.4, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.muted),
                ],
              ),
              if (started && total > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: done / total,
                    minHeight: 8,
                    semanticsLabel: 'কুরআন বুঝি অগ্রগতি',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Opens সহজ আরবি.
class _ArabicCard extends StatelessWidget {
  const _ArabicCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.night,
      borderRadius: BorderRadius.circular(radiusL),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('arabic-card'),
        onTap: () => push(context, const ArabicHomeScreen()),
        child: Stack(
          children: [
            const GirihLayer(cell: 44, opacity: 0.14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.nightLine,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'أ ب',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: arabicFont, fontSize: 22, color: p.gold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('সহজ আরবি', style: nightTitleStyle(p, size: 17)),
                        Text(
                          'বাংলা থেকে কুরআন পড়তে শিখি: অক্ষর, চিহ্ন, তাজবীদ, খেলা',
                          style: TextStyle(color: p.onNightMuted, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.gold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
