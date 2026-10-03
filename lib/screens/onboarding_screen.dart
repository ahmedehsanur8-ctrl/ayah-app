import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/permissions.dart';
import '../services/planner.dart';
import '../theme.dart';
import '../widgets/pattern.dart';
import '../widgets/permission_widgets.dart';
import 'home_shell.dart';
import 'prayer_screen.dart';
import 'settings_screen.dart';

/// First-open setup: a welcome page, one page per permission, then a summary.
/// Nothing here blocks the app; every page can be skipped with "পরে করব".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _pages = PageController();
  PermissionStatus? _status;
  int _index = 0;

  /// The permission whose settings page the user just opened; when it comes
  /// back granted, the next page opens by itself.
  PermKey? _waitingFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  List<PermissionInfo> get _items => _status?.items ?? const [];

  /// Welcome + permissions + summary.
  int get _count => _items.length + 2;

  Future<void> _recheck() async {
    final st = await Permissions.check(AppState.instance.settings);
    if (!mounted) return;
    setState(() => _status = st);
    final w = _waitingFor;
    if (w != null && st.isGranted(w)) {
      _waitingFor = null;
      // Let the green tick show for a moment, then move on.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted && _pageKey(_index) == w) _next();
    }
  }

  PermKey? _pageKey(int i) => i >= 1 && i <= _items.length ? _items[i - 1].key : null;

  void _next() {
    if (_index < _count - 1) {
      _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _goTo(int i) =>
      _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  Future<void> _ask(PermKey k) async {
    _waitingFor = k;
    await Permissions.request(k);
    // The notification dialog comes back without a "resumed" event.
    await _recheck();
  }

  Future<void> _location() async {
    _waitingFor = PermKey.location;
    await useMyLocation(context, explain: false);
    await _recheck();
  }

  Future<void> _city() async {
    _waitingFor = PermKey.location;
    await pickCity(context);
    await _recheck();
  }

  Future<void> _finish() async {
    final s = AppState.instance;
    await s.settings.setSetupDone();
    await Planner.planAll(s.settings, s.data);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final status = _status;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: status == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_index > 0) _progress(p),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() {
                        _index = i;
                        _waitingFor = null;
                      }),
                      children: [
                        _WelcomePage(onStart: _next),
                        for (final item in _items) _permissionPage(item, status),
                        _SummaryPage(status: status, onOpen: (i) => _goTo(i + 1), onDone: _finish),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _progress(Palette p) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'আগের ধাপ',
          onPressed: () => _goTo(_index - 1),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_index + 1) / _count,
              minHeight: 6,
              backgroundColor: p.border,
              color: p.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${toBanglaDigits(_index + 1)} / ${toBanglaDigits(_count)}',
          style: TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, color: p.primary),
        ),
      ],
    ),
  );

  Widget _permissionPage(PermissionInfo item, PermissionStatus status) {
    final granted = status.isGranted(item.key);
    final brand = status.brand;
    return _StepPage(
      icon: item.icon,
      title: item.title,
      why: item.why,
      granted: granted,
      extra: switch (item.key) {
        PermKey.brand when brand != null => BrandStepsList(brand: brand, onChanged: _recheck),
        PermKey.location when granted => Text(
          'বর্তমান: ${AppState.instance.settings.placeName}',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.muted),
        ),
        _ => null,
      },
      actions: [
        if (granted || item.key == PermKey.brand)
          FilledButton.icon(
            onPressed: _next,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('পরবর্তী'),
          )
        else if (item.key == PermKey.location) ...[
          FilledButton.icon(
            onPressed: _location,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('অনুমতি দিন'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _city,
            icon: const Icon(Icons.location_city_rounded),
            label: const Text('শহর বেছে নিন'),
          ),
        ] else
          FilledButton.icon(
            onPressed: () => _ask(item.key),
            icon: const Icon(Icons.check_rounded),
            label: const Text('অনুমতি দিন'),
          ),
        if (!granted) TextButton(onPressed: _next, child: const Text('পরে করব')),
      ],
    );
  }
}

/// Logo, welcome line and "শুরু করি".
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.greenCard, p.greenCardDark],
        ),
      ),
      child: Stack(
        children: [
          const PatternLayer(color: Brand.gold, opacity: 0.07, cell: 52),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Column(
              children: [
                const Spacer(),
                const AppLogo(size: 116),
                const SizedBox(height: 28),
                const Text(
                  '"আয়াত রিমাইন্ডার"-এ স্বাগতম',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: Brand.onNight,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'প্রতিদিন কুরআনের একটি আয়াত ও একটি হাদিস, ঠিক সময়ে অ্যালার্মের মতো মনে করিয়ে দেবে।',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Brand.onNight.withValues(alpha: 0.85),
                    fontSize: 15.5,
                    height: 1.6,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.gold,
                    foregroundColor: Brand.greenDark,
                    minimumSize: const Size.fromHeight(54),
                    textStyle: const TextStyle(
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  child: const Text('শুরু করি'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One permission: icon, title, why, buttons. A green tick once granted.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.icon,
    required this.title,
    required this.why,
    required this.granted,
    required this.actions,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String why;
  final bool granted;
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey(granted),
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: granted ? p.primary : p.greenCard,
                      border: Border.all(color: p.gold, width: 3),
                    ),
                    child: Icon(
                      granted ? Icons.check_rounded : icon,
                      size: 54,
                      color: granted ? p.onPrimary : p.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: headingFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 23,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                why,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 15, height: 1.6),
              ),
              if (granted) ...[
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    '✓ অনুমতি দেওয়া হয়েছে',
                    style: TextStyle(
                      color: p.primary,
                      fontWeight: FontWeight.w700,
                      fontFamily: headingFont,
                    ),
                  ),
                ),
              ],
              if (extra != null) ...[const SizedBox(height: 18), extra!],
              const SizedBox(height: 28),
              for (final a in actions)
                a is SizedBox ? a : SizedBox(height: a is TextButton ? 44 : 52, child: a),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tick or "বাকি" for every item, a test button and "শুরু করুন".
class _SummaryPage extends StatelessWidget {
  const _SummaryPage({required this.status, required this.onOpen, required this.onDone});

  final PermissionStatus status;

  /// Opens the page for the item at this index.
  final ValueChanged<int> onOpen;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = status.items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          'সব প্রস্তুত!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: headingFont,
            fontWeight: FontWeight.w700,
            fontSize: 23,
            color: p.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          status.missingForReminders == 0
              ? 'রিমাইন্ডার ঠিক সময়ে অ্যালার্মের মতো আসবে ইনশাআল্লাহ।'
              : '"বাকি" লেখা ঘরে চাপ দিয়ে পরেও চালু করতে পারবেন।',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        Material(
          color: p.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
            side: BorderSide(color: p.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.border),
                ListTile(
                  leading: Icon(items[i].icon, color: p.primary),
                  title: Text(items[i].title),
                  trailing: StatusChip(status.isGranted(items[i].key), optional: items[i].optional),
                  onTap: status.isGranted(items[i].key) ? null : () => onOpen(i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => SettingsScreen.sendTestReminder(context),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.alarm_on_rounded),
          label: const Text('১ মিনিট পর পরীক্ষা করুন'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onDone,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          icon: const Icon(Icons.check_rounded),
          label: const Text('শুরু করুন'),
        ),
        const SizedBox(height: 10),
        Text(
          'পরে যেকোনো সময় সেটিংস → "অনুমতি ও সেটআপ" থেকে এগুলো দেখতে পারবেন।',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 14),
        ),
      ],
    );
  }
}
