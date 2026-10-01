import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/permissions.dart';
import '../theme.dart';
import '../widgets/permission_widgets.dart';
import '../widgets/ui.dart';
import 'prayer_screen.dart';
import 'settings_screen.dart';

/// More → অনুমতি ও সেটআপ: every permission with a tick or "বাকি", checked
/// again each time the user comes back from a settings page.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final st = await Permissions.check(AppState.instance.settings);
    if (mounted) setState(() => _status = st);
  }

  Future<void> _open(PermKey k) async {
    if (k == PermKey.location) {
      await showLocationSheet(context);
    } else {
      await Permissions.request(k);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('অনুমতি ও সেটআপ')),
      body: st == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _Summary(missing: st.missingForReminders),
                const SizedBox(height: 14),
                for (final item in st.items) ...[
                  _PermissionCard(
                    item: item,
                    granted: st.isGranted(item.key),
                    subtitle: item.key == PermKey.location && st.isGranted(item.key)
                        ? 'বর্তমান: ${AppState.instance.settings.placeName}'
                        : null,
                    onOpen: item.key == PermKey.brand ? null : () => _open(item.key),
                    child: item.key == PermKey.brand && st.brand != null
                        ? BrandStepsList(brand: st.brand!, onChanged: _refresh)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => SettingsScreen.sendTestReminder(context),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.alarm_on_rounded),
                  label: const Text('১ মিনিট পর পরীক্ষা করুন'),
                ),
                const SizedBox(height: 10),
                Text(
                  'পরীক্ষা বোতাম চাপার পর ফোন লক করে রাখুন। এক মিনিট পর শব্দসহ পুরো স্ক্রিনে '
                  'আয়াতটি খুললে সব ঠিক আছে।',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
                ),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.missing});

  final int missing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ok = missing == 0;
    final color = ok ? p.primary : warnOrange;
    return AppCard(
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(ok ? Icons.verified_rounded : Icons.error_outline_rounded, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok
                  ? 'রিমাইন্ডারের জন্য দরকারি সব অনুমতি দেওয়া আছে।'
                  : 'রিমাইন্ডার ঠিকমতো কাজ করতে ${toBanglaDigits(missing)}টি অনুমতি বাকি।',
              style: TextStyle(fontWeight: FontWeight.w600, color: p.text, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.item,
    required this.granted,
    this.subtitle,
    this.onOpen,
    this.child,
  });

  final PermissionInfo item;
  final bool granted;
  final String? subtitle;
  final VoidCallback? onOpen;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(item.icon, tint: granted ? p.mint : p.sand, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
              StatusChip(granted),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.why, style: TextStyle(color: p.muted, height: 1.55, fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: p.text, fontSize: 14)),
          ],
          if (child != null) ...[const SizedBox(height: 12), child!],
          if (onOpen != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: granted
                  ? TextButton(onPressed: onOpen, child: const Text('সেটিংস দেখুন'))
                  : FilledButton(onPressed: onOpen, child: const Text('অনুমতি দিন')),
            ),
          ],
        ],
      ),
    );
  }
}

/// Orange banner on the home screen while something reminders need is off.
class SetupBanner extends StatefulWidget {
  const SetupBanner({super.key});

  @override
  State<SetupBanner> createState() => _SetupBannerState();
}

class _SetupBannerState extends State<SetupBanner> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Permissions.check(AppState.instance.settings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Permissions.check(AppState.instance.settings);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: Permissions.status,
    builder: (context, st, _) {
      final missing = st?.missingForReminders ?? 0;
      if (missing == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: warnOrange.withValues(alpha: 0.14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
            side: BorderSide(color: warnOrange.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: warnOrange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'রিমাইন্ডার ঠিকমতো কাজ করতে ${toBanglaDigits(missing)}টি অনুমতি বাকি',
                    style: TextStyle(
                      color: context.palette.text,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => push(context, const SetupScreen()),
                  style: FilledButton.styleFrom(
                    backgroundColor: warnOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('ঠিক করুন'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
