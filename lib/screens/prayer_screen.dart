import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/location.dart';
import '../services/prayer.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../utils/bangla.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart' show pickOption;

/// নামাজের সময় ও আজান.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  Timer? _timer;

  AppSettings get _s => AppState.instance.settings;

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

  Future<void> _changed() => Prayers.schedule(_s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নামাজের সময়')),
      body: ListenableBuilder(
        listenable: _s,
        builder: (context, _) => _s.hasLocation ? _times(context) : const ChooseLocationView(),
      ),
    );
  }

  Widget _times(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final list = Prayers.forDay(_s, now);
    final next = Prayers.next(_s, now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Row(
          children: [
            Flexible(
              child: InfoPill(
                icon: Icons.location_on_outlined,
                text: _s.placeName.isEmpty ? 'অবস্থান' : _s.placeName,
                onTap: () => showLocationSheet(context),
              ),
            ),
            const Spacer(),
            Text(banglaDate(now), style: TextStyle(color: p.muted, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 14),
        if (next != null)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.greenCard, p.greenCardDark],
              ),
              borderRadius: BorderRadius.circular(radiusL),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'পরের নামাজ',
                  style: TextStyle(color: p.gold, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  next.name,
                  style: const TextStyle(
                    fontFamily: titleFont,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  formatClock(next.time),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, color: p.gold, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'আর ${formatCountdown(next.time.difference(now))}',
                      style: TextStyle(color: p.gold, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.border),
                _PrayerRow(
                  prayer: list[i],
                  isNext:
                      next != null && next.key == list[i].key && _sameDay(next.time, list[i].time),
                  onBell: list[i].isSunrise
                      ? null
                      : () async {
                          await _s.setAzanOn(list[i].key, !_s.azanOn(list[i].key));
                          await _changed();
                        },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ঘণ্টার চিহ্নে চাপ দিয়ে কোন ওয়াক্তে আজান হবে তা ঠিক করুন। ফোন সাইলেন্ট থাকলে আজান বাজবে না।',
          style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
        ),
        const SectionLabel('সেটিংস'),
        RowGroup(
          children: [
            NavRow(
              icon: Icons.calculate_outlined,
              title: 'হিসাবের পদ্ধতি',
              subtitle: Prayers.methodById(_s.calcMethod).name,
              onTap: () async {
                final v = await pickOption<String>(context, 'হিসাবের পদ্ধতি', _s.calcMethod, {
                  for (final m in Prayers.methods) m.id: m.name,
                });
                if (v != null) {
                  await _s.setCalcMethod(v);
                  await _changed();
                }
              },
            ),
            NavRow(
              icon: Icons.wb_twilight_outlined,
              tint: p.sand,
              title: 'আসরের সময়',
              subtitle: _s.asrMethod == 'hanafi' ? 'হানাফি' : 'শাফেয়ি, মালেকি, হাম্বলি',
              onTap: () async {
                final v = await pickOption<String>(context, 'আসরের সময়', _s.asrMethod, {
                  'hanafi': 'হানাফি (বাংলাদেশে প্রচলিত)',
                  'shafi': 'শাফেয়ি, মালেকি, হাম্বলি',
                });
                if (v != null) {
                  await _s.setAsrMethod(v);
                  await _changed();
                }
              },
            ),
            NavRow(
              icon: Icons.volume_up_outlined,
              tint: p.sky,
              title: 'আজানের শব্দ',
              subtitle: _soundName(_s.azanSound),
              onTap: () async {
                final v = await pickOption<String>(context, 'আজানের শব্দ', _s.azanSound, {
                  if (Prayers.azanBundled) 'azan': 'আজান',
                  'soft': 'মৃদু নোটিফিকেশন শব্দ',
                  'silent': 'শব্দ ছাড়া (শুধু নোটিফিকেশন)',
                });
                if (v != null) {
                  await _s.setAzanSound(v);
                  await _changed();
                }
              },
            ),
            NavRow(
              icon: Icons.play_circle_outline_rounded,
              tint: p.rose,
              title: 'আজান পরীক্ষা করুন',
              subtitle: 'এখনই একবার শুনে দেখুন ("থামান" দিয়ে বন্ধ করুন)',
              onTap: () => Prayers.showTest(_s),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'নামাজের সময় ফোনেই হিসাব করা হয়, ইন্টারনেট লাগে না। প্রতিবার অ্যাপ খুললে '
          'পরের ১৪ দিনের আজান নতুন করে ঠিক করা হয়। স্থানীয় মসজিদের সময়ের সাথে '
          '১–২ মিনিট পার্থক্য হতে পারে।',
          style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _soundName(String v) {
    if (v == 'azan' && !Prayers.azanBundled) return 'মৃদু নোটিফিকেশন শব্দ';
    return switch (v) {
      'azan' => 'আজান',
      'silent' => 'শব্দ ছাড়া',
      _ => 'মৃদু নোটিফিকেশন শব্দ',
    };
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({required this.prayer, required this.isNext, required this.onBell});

  final PrayerTime prayer;
  final bool isNext;
  final VoidCallback? onBell;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    final on = !prayer.isSunrise && s.azanOn(prayer.key);
    return Container(
      color: isNext ? p.pill : null,
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
      child: Row(
        children: [
          Icon(
            prayer.isSunrise ? Icons.wb_sunny_outlined : Icons.mosque_outlined,
            size: 22,
            color: isNext ? p.primary : p.muted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              prayer.name,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: prayer.isSunrise ? p.muted : p.text,
              ),
            ),
          ),
          Text(
            formatClock(prayer.time),
            style: TextStyle(
              fontSize: 16,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              color: isNext ? p.primary : p.text,
            ),
          ),
          SizedBox(
            width: 52,
            child: onBell == null
                ? null
                : IconButton(
                    tooltip: on ? 'আজান বন্ধ করুন' : 'আজান চালু করুন',
                    onPressed: onBell,
                    icon: Icon(
                      on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      color: on ? p.primary : p.muted,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown until a location is chosen.
class ChooseLocationView extends StatelessWidget {
  const ChooseLocationView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(child: IconBubble(Icons.location_on_outlined, tint: p.mint, size: 84)),
        const SizedBox(height: 18),
        Text('আপনার এলাকা বেছে নিন', textAlign: TextAlign.center, style: titleStyle(p, size: 22)),
        const SizedBox(height: 10),
        Text(
          'নামাজের সময় ও কিবলার দিক হিসাব করতে আপনার এলাকা জানা দরকার। '
          'অবস্থান শুধু আপনার ফোনে থাকে, কোথাও পাঠানো হয় না।',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, height: 1.6),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => useMyLocation(context),
          icon: const Icon(Icons.my_location_rounded),
          label: const Text('আমার অবস্থান ব্যবহার করুন'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => pickCity(context),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.location_city_outlined),
          label: const Text('হাতে শহর বেছে নিন'),
        ),
      ],
    );
  }
}

/// Explains, asks for location permission and saves the location.
Future<void> useMyLocation(BuildContext context) async {
  final s = AppState.instance.settings;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.location_on_outlined),
      title: const Text('অবস্থানের অনুমতি'),
      content: const Text(
        'নামাজের সময় ও কিবলার দিক ঠিকভাবে হিসাব করতে অ্যাপটি ফোনের আনুমানিক অবস্থান ব্যবহার করবে। '
        'হিসাব ফোনেই হয়, অবস্থান কোথাও পাঠানো হয় না।\n\nপরের ধাপে ফোন অনুমতি চাইবে।',
        style: TextStyle(height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('না, শহর বেছে নেব'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('চালিয়ে যান'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (ok != true) return pickCity(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('অবস্থান খোঁজা হচ্ছে…')));
  final r = await LocationService.useCurrentLocation(s);
  messenger.hideCurrentSnackBar();
  if (!context.mounted) return;
  switch (r) {
    case LocationResult.ok:
      await Prayers.schedule(s);
      messenger.showSnackBar(SnackBar(content: Text('অবস্থান ঠিক হয়েছে: ${s.placeName}')));
    case LocationResult.serviceOff:
      messenger.showSnackBar(
        SnackBar(
          content: const Text('ফোনের লোকেশন বন্ধ আছে।'),
          action: SnackBarAction(
            label: 'চালু করুন',
            onPressed: LocationService.openLocationSettings,
          ),
        ),
      );
    case LocationResult.deniedForever:
      messenger.showSnackBar(
        SnackBar(
          content: const Text('অবস্থানের অনুমতি বন্ধ। সেটিংস থেকে দিন, অথবা শহর বেছে নিন।'),
          action: SnackBarAction(label: 'সেটিংস', onPressed: LocationService.openAppSettings),
        ),
      );
      await pickCity(context);
    case LocationResult.denied || LocationResult.failed:
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            r == LocationResult.denied
                ? 'অনুমতি দেওয়া হয়নি — শহর বেছে নিন।'
                : 'অবস্থান পাওয়া যায়নি — শহর বেছে নিন।',
          ),
        ),
      );
      await pickCity(context);
  }
}

/// List of cities with a search box.
Future<void> pickCity(BuildContext context) async {
  final s = AppState.instance.settings;
  final city = await showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CityPicker(),
  );
  if (city == null) return;
  await s.setLocation(city.lat, city.lng, city.name, 'city');
  await Prayers.schedule(s);
}

/// Change the location: phone location or a city.
Future<void> showLocationSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  builder: (sheet) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.my_location_rounded),
          title: const Text('আমার অবস্থান ব্যবহার করুন'),
          onTap: () {
            Navigator.pop(sheet);
            useMyLocation(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_city_outlined),
          title: const Text('শহর বেছে নিন'),
          onTap: () {
            Navigator.pop(sheet);
            pickCity(context);
          },
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

class _CityPicker extends StatefulWidget {
  const _CityPicker();

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cities = City.all.where((c) => c.name.contains(_q.trim())).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'শহরের নাম খুঁজুন',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: cities.length,
                itemBuilder: (context, i) => ListTile(
                  minTileHeight: 52,
                  leading: Icon(Icons.location_on_outlined, color: p.primary),
                  title: Text(cities[i].name),
                  onTap: () => Navigator.pop(context, cities[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'তালিকায় আপনার শহর না থাকলে সবচেয়ে কাছের শহরটি বেছে নিন।',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
