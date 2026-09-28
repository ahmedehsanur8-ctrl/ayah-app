import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/reminders.dart';
import '../services/system_settings.dart';
import '../models/content.dart';
import '../theme.dart';
import 'settings_screen.dart';
import '../widgets/pattern.dart';
import 'home_shell.dart';

/// Asks for the permissions reminders need, with simple Bangla explanations.
/// Shown the first time the app opens, and later from Settings.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.firstTime = false});

  final bool firstTime;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  bool? _notifications;
  bool? _fullScreen;
  bool? _exactAlarm;
  bool? _battery;

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

  /// Coming back from a system settings page: check again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final android = Reminders.android;
    final n = await android?.areNotificationsEnabled();
    final e = await android?.canScheduleExactNotifications();
    final f = await SystemSettings.canUseFullScreenIntent();
    final b = await SystemSettings.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _notifications = n;
      _exactAlarm = e;
      _fullScreen = f;
      _battery = b;
    });
  }

  Future<void> _finish() async {
    final s = AppState.instance;
    await s.settings.setSetupDone();
    await Reminders.reschedule(s.settings, s.data);
    if (!mounted) return;
    if (widget.firstTime) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final granted = [
      _notifications,
      _fullScreen,
      _exactAlarm,
      _battery,
    ].where((v) => v == true).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('শুরু করার আগে'),
        automaticallyImplyLeading: !widget.firstTime,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radiusL),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.heroEnd, p.heroStart, Brand.night],
                ),
              ),
              child: Stack(
                children: [
                  const PatternLayer(color: Brand.lightGold, opacity: 0.08, cell: 48),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const AppLogo(size: 58),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'আসসালামু আলাইকুম!',
                                style: TextStyle(
                                  fontFamily: headingFont,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 19,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'প্রতিদিন সকালে একটি আয়াত আর রাতে একটি হাদিস মনে করিয়ে দিতে '
                                'অ্যাপটির কিছু অনুমতি দরকার। প্রতিটি বোতামে একবার করে চাপ দিন।',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13.5,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: granted / 4,
                    minHeight: 8,
                    backgroundColor: p.border,
                    color: p.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${toBanglaDigits(granted)}/৪ সম্পন্ন',
                style: TextStyle(
                  fontFamily: headingFont,
                  fontWeight: FontWeight.w700,
                  color: p.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Step(
            number: 1,
            icon: Icons.notifications_active_rounded,
            title: 'নোটিফিকেশনের অনুমতি',
            body: 'এটি না দিলে অ্যাপ আপনাকে কোনো রিমাইন্ডার দেখাতে পারবে না।',
            done: _notifications,
            button: 'অনুমতি দিন',
            onPressed: () async {
              await Reminders.android?.requestNotificationsPermission();
              _refresh();
            },
          ),
          _Step(
            number: 2,
            icon: Icons.fullscreen_rounded,
            title: 'পুরো স্ক্রিনে দেখানোর অনুমতি',
            body:
                'ফোন লক থাকলেও রিমাইন্ডার ও আজানের পাতা পুরো স্ক্রিনে খুলে যাবে, যেন আয়াত বা হাদিসটি চোখে পড়ে। '
                'খোলা পাতায় "Ayah Reminder"-এর পাশের সুইচটি চালু করুন।',
            done: _fullScreen,
            button: 'অনুমতি দিন',
            onPressed: () async {
              await Reminders.android?.requestFullScreenIntentPermission();
              _refresh();
            },
          ),
          _Step(
            number: 3,
            icon: Icons.alarm_rounded,
            title: 'ঠিক সময়ে অ্যালার্মের অনুমতি',
            body:
                'এতে রিমাইন্ডার ও আজান ঠিক সময়েই বাজবে, দেরি করে নয়। '
                'খোলা পাতায় সুইচটি চালু করুন।',
            done: _exactAlarm,
            button: 'অনুমতি দিন',
            onPressed: () async {
              await Reminders.android?.requestExactAlarmsPermission();
              _refresh();
            },
          ),
          _Step(
            number: 4,
            icon: Icons.battery_saver_rounded,
            title: 'ব্যাটারি সেভার থেকে বাদ দিন',
            body:
                'ফোন ব্যাটারি বাঁচাতে অনেক সময় অ্যাপ বন্ধ করে দেয়, তখন রিমাইন্ডার আসে না। '
                '"Allow" বা "অনুমতি দিন" চাপুন। তালিকা এলে Ayah Reminder বেছে "Don\'t optimize" / "Unrestricted" দিন।',
            done: _battery,
            button: 'সেটিংস খুলুন',
            onPressed: () async {
              await SystemSettings.requestIgnoreBatteryOptimizations();
            },
          ),
          _Step(
            number: 5,
            icon: Icons.restart_alt_rounded,
            title: 'অটোস্টার্ট চালু করুন',
            body:
                'Xiaomi, Redmi, Oppo, Realme, Vivo, Huawei, Tecno ইত্যাদি ফোনে "Autostart" বন্ধ থাকলে '
                'ফোন রিস্টার্টের পর রিমাইন্ডার আসে না। খোলা পাতায় Ayah Reminder খুঁজে সুইচটি চালু করুন। '
                'আপনার ফোনে এই অপশন না থাকলে এই ধাপটি বাদ দিন।',
            done: null,
            button: 'সেটিংস খুলুন',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final opened = await SystemSettings.openAutostartSettings();
              if (!opened) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'আপনার ফোনে আলাদা অটোস্টার্ট পাতা পাওয়া যায়নি। '
                      'অ্যাপের তথ্য পাতায় "Battery" অংশটি দেখে নিন।',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => SettingsScreen.sendTestReminder(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('পরীক্ষামূলক রিমাইন্ডার পাঠান'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.firstTime ? 'শুরু করুন' : 'ঠিক আছে'),
          ),
          const SizedBox(height: 10),
          Text(
            'পরে যেকোনো সময় আরও → "অনুমতি ও সেটআপ" থেকে আবার এই পাতায় আসতে পারবেন।',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.done,
    required this.button,
    required this.onPressed,
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;

  /// true = granted, false = not yet, null = unknown.
  final bool? done;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ok = done == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
          side: BorderSide(color: ok ? p.primary.withValues(alpha: 0.5) : p.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ok ? p.primary : p.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      ok ? Icons.check_rounded : icon,
                      color: ok ? (p.isDark ? Brand.night : Colors.white) : p.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ধাপ ${toBanglaDigits(number)}',
                          style: TextStyle(fontSize: 12, color: p.accent, fontFamily: headingFont),
                        ),
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                  if (done == false) const Icon(Icons.error_outline_rounded, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 10),
              Text(body, style: TextStyle(height: 1.6, color: p.text)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ok
                    ? Text(
                        '✓ হয়ে গেছে',
                        style: TextStyle(
                          fontFamily: headingFont,
                          color: p.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : OutlinedButton(onPressed: onPressed, child: Text(button)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
