import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/reminders.dart';
import '../services/system_settings.dart';
import '../theme.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('শুরু করার আগে'),
        automaticallyImplyLeading: !widget.firstTime,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'আসসালামু আলাইকুম! প্রতিদিন সকালে একটি আয়াত আর রাতে একটি হাদিস আপনাকে মনে করিয়ে দিতে '
            'অ্যাপটির কিছু অনুমতি দরকার। নিচের প্রতিটি বোতামে একবার করে চাপ দিন।',
            style: TextStyle(fontSize: 15.5, height: 1.6),
          ),
          const SizedBox(height: 16),
          _Step(
            number: 1,
            icon: Icons.notifications_outlined,
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
            icon: Icons.fullscreen,
            title: 'পুরো স্ক্রিনে দেখানোর অনুমতি',
            body:
                'ফোন লক থাকলেও রিমাইন্ডারটি পুরো স্ক্রিনে খুলে যাবে, যেন আয়াত বা হাদিসটি চোখে পড়ে। '
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
            icon: Icons.alarm,
            title: 'ঠিক সময়ে অ্যালার্মের অনুমতি',
            body:
                'এতে রিমাইন্ডার ঠিক আপনার বেছে নেওয়া সময়েই আসবে, দেরি করে নয়। '
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
            icon: Icons.battery_saver_outlined,
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
            icon: Icons.restart_alt,
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
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.check),
            label: Text(widget.firstTime ? 'শুরু করুন' : 'ঠিক আছে'),
          ),
          const SizedBox(height: 8),
          const Text(
            'পরে যেকোনো সময় সেটিংস → "অনুমতি ও সেটআপ" থেকে আবার এই পাতায় আসতে পারবেন।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.softGreen,
                    child: Icon(icon, color: AppColors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (done == true)
                    const Icon(Icons.check_circle, color: AppColors.green)
                  else if (done == false)
                    const Icon(Icons.error_outline, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 10),
              Text(body, style: const TextStyle(height: 1.55, color: AppColors.text)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: done == true
                    ? const Text(
                        '✓ হয়ে গেছে',
                        style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
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
