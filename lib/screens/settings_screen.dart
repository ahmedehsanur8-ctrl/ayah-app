import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/reminders.dart';
import '../services/rotation.dart';
import '../theme.dart';
import 'credits_screen.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final part = t.hour < 12 ? 'সকাল' : (t.hour < 16 ? 'দুপুর' : (t.hour < 18 ? 'বিকাল' : 'রাত'));
    return '$part ${toBanglaDigits('$h:$m')}';
  }

  Future<void> _reschedule() async {
    final s = AppState.instance;
    await Reminders.reschedule(s.settings, s.data);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppState.instance.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _Header('রিমাইন্ডার'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.green),
              title: const Text('রিমাইন্ডার চালু'),
              subtitle: const Text('প্রতিদিন সকাল ও রাতে মনে করিয়ে দেবে'),
              value: settings.remindersOn,
              onChanged: (v) async {
                await settings.setRemindersOn(v);
                await _reschedule();
              },
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined, color: AppColors.green),
              title: const Text('সকালের সময় (আয়াত)'),
              subtitle: Text(formatTime(settings.morningTime)),
              enabled: settings.remindersOn,
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: settings.morningTime);
                if (t == null) return;
                await settings.setMorningTime(t);
                await _reschedule();
              },
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_outlined, color: AppColors.green),
              title: Text(settings.hadithAtNight ? 'রাতের সময় (হাদিস)' : 'রাতের সময় (আয়াত)'),
              subtitle: Text(formatTime(settings.nightTime)),
              enabled: settings.remindersOn,
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: settings.nightTime);
                if (t == null) return;
                await settings.setNightTime(t);
                await _reschedule();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.format_quote_outlined, color: AppColors.green),
              title: const Text('রাতে হাদিস দেখাও'),
              subtitle: const Text('বন্ধ করলে রাতেও একটি আয়াত আসবে'),
              value: settings.hadithAtNight,
              onChanged: settings.remindersOn
                  ? (v) async {
                      await settings.setHadithAtNight(v);
                      await _reschedule();
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline, color: AppColors.green),
              title: const Text('পরীক্ষামূলক রিমাইন্ডার'),
              subtitle: const Text('রিমাইন্ডার ঠিকমতো আসে কিনা এখনই দেখে নিন'),
              onTap: () {
                final s = AppState.instance;
                final item = s.rotation.morning(Rotation.dayNumber(Reminders.nowDhaka()));
                if (item != null) Reminders.showTest(item);
              },
            ),
            const Divider(),
            const _Header('লেখার আকার'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('অ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(
                      value: settings.textScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      label: '${toBanglaDigits((settings.textScale * 100).round())}%',
                      onChanged: (v) => settings.setTextScale(v),
                    ),
                  ),
                  const Text('অ', style: TextStyle(fontSize: 24)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'নমুনা: আল্লাহর রহমত থেকে নিরাশ হয়ো না।',
                style: TextStyle(fontSize: 16 * settings.textScale),
              ),
            ),
            const Divider(),
            const _Header('অন্যান্য'),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined, color: AppColors.green),
              title: const Text('অনুমতি ও সেটআপ'),
              subtitle: const Text('রিমাইন্ডার না এলে এখানে দেখুন'),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SetupScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_outline, color: AppColors.green),
              title: const Text('কৃতজ্ঞতা ও উৎস'),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CreditsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}
