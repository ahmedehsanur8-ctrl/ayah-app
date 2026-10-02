import 'dart:async';

import 'package:flutter/material.dart';

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
import '../widgets/share_card.dart';
import '../widgets/ui.dart';
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

/// আজ (Home): greeting, search / প্রিয় / সেটিংস, next prayer, today's ayah and
/// hadith, then shortcuts to prayer times, Qibla, tasbih, adhkar, Quran and Arabic.
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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: state.settings,
          builder: (context, _) {
            final marks = state.settings.readMarks;
            final todayKey = dateKey(now);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _Header(now: now),
                const SizedBox(height: 12),
                ActionRow(
                  children: [
                    LabeledAction(
                      icon: Icons.search_rounded,
                      label: 'খুঁজুন',
                      onTap: () => push(context, const SearchScreen()),
                    ),
                    LabeledAction(
                      icon: Icons.favorite_border_rounded,
                      label: 'প্রিয়',
                      onTap: () => push(context, const FavoritesScreen()),
                    ),
                    LabeledAction(
                      icon: Icons.settings_outlined,
                      label: 'সেটিংস',
                      onTap: () => push(context, const SettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const SetupBanner(),
                const NextPrayerStrip(),
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                const _Shortcuts(),
                const SizedBox(height: 14),
                const AdhkarCard(showAllButton: true),
                const SizedBox(height: 14),
                const QuranContinueCard(showWhenEmpty: true),
                const SizedBox(height: 14),
                const _LearnCard(),
                const SizedBox(height: 14),
                const _ArabicCard(),
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

  /// The next reminder time, e.g. "রাত ৯:০০".
  static String? nextReminder() {
    final s = AppState.instance.settings;
    if (!s.remindersOn) return null;
    final now = Reminders.nowDhaka();
    final times = [
      s.morningTime,
      s.nightTime,
    ].map((t) => DateTime(now.year, now.month, now.day, t.hour, t.minute)).toList();
    final today = times.where((t) => t.isAfter(now)).toList()..sort();
    final next = today.isNotEmpty
        ? today.first
        : (times..sort()).first.add(const Duration(days: 1));
    return formatClock(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final next = nextReminder();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'আসসালামু আলাইকুম',
                    style: TextStyle(color: p.goldText, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(greeting(now.hour), style: titleStyle(p, size: 26)),
                  Text(banglaDate(now), style: TextStyle(color: p.muted, fontSize: 14)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InfoPill(
                icon: next == null
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_none_rounded,
                text: next ?? 'রিমাইন্ডার বন্ধ',
                tint: p.sand,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "পরের নামাজ" strip with a live countdown. Opens the prayer times page.
class NextPrayerStrip extends StatefulWidget {
  const NextPrayerStrip({super.key});

  @override
  State<NextPrayerStrip> createState() => _NextPrayerStripState();
}

class _NextPrayerStripState extends State<NextPrayerStrip> {
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
    return AppCard(
      onTap: () => push(context, const PrayerScreen()),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          IconBubble(Icons.mosque_outlined, tint: p.mint, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: next == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'নামাজের সময়',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                      ),
                      Text(
                        'দেখতে আপনার এলাকা বেছে নিন',
                        style: TextStyle(fontSize: 14, color: p.muted),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('পরের নামাজ', style: TextStyle(fontSize: 14, color: p.muted)),
                      Text(
                        '${next.name} · ${formatClock(next.time)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
                      ),
                    ],
                  ),
          ),
          if (next != null)
            Text(
              formatCountdown(next.time.difference(now)),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.primary),
            ),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
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
    final white = Colors.white.withValues(alpha: 0.85);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.greenCard, p.greenCardDark],
        ),
        borderRadius: BorderRadius.circular(radiusL),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusL),
          onTap: () => push(context, ReaderScreen(items: [item])),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${isToday ? 'আজকের আয়াত' : 'আয়াত'} · ${item.category}',
                          softWrap: true,
                          style: TextStyle(
                            color: p.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    FavoriteButton(item, color: white),
                    IconButton(
                      tooltip: 'ছবি হিসেবে শেয়ার করুন',
                      onPressed: () => showShareSheet(context, item),
                      icon: Icon(Icons.share_outlined, color: white),
                    ),
                  ],
                ),
                if (read) const Align(alignment: Alignment.centerLeft, child: _ReadBadge()),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ArabicText(item.arabic, size: 26, color: Brand.cream),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: OrnamentDivider(color: p.gold),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: BanglaText(item.banglaPlain, size: 16.5, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: TextStyle(color: p.gold, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    children: [
                      _RoundNav(icon: Icons.chevron_left_rounded, tooltip: 'আগের', onTap: onPrev),
                      const SizedBox(width: 10),
                      Expanded(child: _GoldListenButton(item)),
                      const SizedBox(width: 10),
                      _RoundNav(icon: Icons.chevron_right_rounded, tooltip: 'পরের', onTap: onNext),
                    ],
                  ),
                ),
                if (!isToday)
                  Center(
                    child: TextButton(
                      onPressed: onToday,
                      style: TextButton.styleFrom(foregroundColor: p.gold),
                      child: const Text('আজকের আয়াতে ফিরুন'),
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

class _RoundNav extends StatelessWidget {
  const _RoundNav({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, size: 26),
    ),
  );
}

/// Big gold "শুনুন" button for the ayah card.
class _GoldListenButton extends StatefulWidget {
  const _GoldListenButton(this.item);

  final ContentItem item;

  @override
  State<_GoldListenButton> createState() => _GoldListenButtonState();
}

class _GoldListenButtonState extends State<_GoldListenButton> {
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
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: () => _audio.toggleItem(widget.item),
        style: FilledButton.styleFrom(
          backgroundColor: p.gold,
          foregroundColor: Brand.greenDark,
          shape: const StadiumBorder(),
        ),
        icon: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Brand.greenDark),
              )
            : Icon(active ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 28),
        label: Text(
          active ? 'থামান' : 'শুনুন',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Big shortcut cards: prayer times, Qibla, tasbih.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ActionRow(
      children: [
        LabeledAction(
          icon: Icons.schedule_outlined,
          label: 'নামাজের সময়',
          tint: p.mint,
          onTap: () => push(context, const PrayerScreen()),
        ),
        LabeledAction(
          icon: Icons.explore_outlined,
          label: 'কিবলা',
          tint: p.sky,
          onTap: () => push(context, const QiblaScreen()),
        ),
        LabeledAction(
          icon: Icons.touch_app_outlined,
          label: 'তাসবিহ',
          tint: p.sand,
          onTap: () => push(context, const TasbihScreen()),
        ),
      ],
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

/// Opens সহজ আরবি.
/// Opens কুরআন বুঝি.
class _LearnCard extends StatelessWidget {
  const _LearnCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      key: const ValueKey('learn-card'),
      onTap: () => push(context, const LearnDashboardScreen()),
      child: Row(
        children: [
          IconBubble(Icons.translate_rounded, tint: p.mint, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'কুরআন বুঝি',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
                ),
                Text(
                  'আয়াতের শব্দ চিনে অর্থ বুঝি · প্রতিদিন কয়েক মিনিট',
                  style: TextStyle(fontSize: 14, height: 1.4, color: p.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
  }
}

class _ArabicCard extends StatelessWidget {
  const _ArabicCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.greenCard,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('arabic-card'),
        onTap: () => push(context, const ArabicHomeScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'أ ب',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: arabicFont, fontSize: 22, color: Brand.gold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'সহজ আরবি',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'বাংলা থেকে কুরআন পড়তে শিখি: অক্ষর, চিহ্ন, তাজবীদ, খেলা',
                      style: TextStyle(color: p.gold, fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Brand.gold),
            ],
          ),
        ),
      ),
    );
  }
}
