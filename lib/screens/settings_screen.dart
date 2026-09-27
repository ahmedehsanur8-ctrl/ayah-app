import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/bangla_tts.dart';
import '../services/reminders.dart';
import '../services/rotation.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/audio_button.dart';
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
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const _Header('রিমাইন্ডার'),
            _Group(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_active_rounded,
                  title: 'রিমাইন্ডার চালু',
                  subtitle: 'প্রতিদিন সকাল ও রাতে মনে করিয়ে দেবে',
                  value: settings.remindersOn,
                  onChanged: (v) async {
                    await settings.setRemindersOn(v);
                    await _reschedule();
                  },
                ),
                _Row(
                  icon: Icons.wb_sunny_rounded,
                  title: 'সকালের সময় · আয়াত',
                  trailing: formatTime(settings.morningTime),
                  enabled: settings.remindersOn,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: settings.morningTime,
                      helpText: 'সকালের রিমাইন্ডারের সময়',
                      cancelText: 'বাতিল',
                      confirmText: 'ঠিক আছে',
                    );
                    if (t == null) return;
                    await settings.setMorningTime(t);
                    await _reschedule();
                  },
                ),
                _Row(
                  icon: Icons.nightlight_round,
                  title: settings.hadithAtNight ? 'রাতের সময় · হাদিস' : 'রাতের সময় · আয়াত',
                  trailing: formatTime(settings.nightTime),
                  enabled: settings.remindersOn,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: settings.nightTime,
                      helpText: 'রাতের রিমাইন্ডারের সময়',
                      cancelText: 'বাতিল',
                      confirmText: 'ঠিক আছে',
                    );
                    if (t == null) return;
                    await settings.setNightTime(t);
                    await _reschedule();
                  },
                ),
                _SwitchRow(
                  icon: Icons.format_quote_rounded,
                  title: 'রাতে হাদিস দেখাও',
                  subtitle: 'বন্ধ করলে রাতেও একটি আয়াত আসবে',
                  value: settings.hadithAtNight,
                  onChanged: settings.remindersOn
                      ? (v) async {
                          await settings.setHadithAtNight(v);
                          await _reschedule();
                        }
                      : null,
                ),
                _Row(
                  icon: Icons.play_circle_rounded,
                  title: 'পরীক্ষামূলক রিমাইন্ডার',
                  subtitle: 'রিমাইন্ডার ঠিকমতো আসে কিনা এখনই দেখে নিন',
                  onTap: () {
                    final s = AppState.instance;
                    final item = s.rotation.morning(Rotation.dayNumber(Reminders.nowDhaka()));
                    if (item != null) Reminders.showTest(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('একটি পরীক্ষামূলক রিমাইন্ডার পাঠানো হয়েছে')),
                    );
                  },
                ),
              ],
            ),
            const _Header('অডিও'),
            _Group(
              children: [
                _Row(
                  icon: Icons.record_voice_over_rounded,
                  title: 'ক্বারী (আরবি তিলাওয়াত)',
                  subtitle: Reciter.byId(settings.reciterId).name,
                  onTap: () => _pickReciter(context),
                ),
                _Row(
                  icon: Icons.graphic_eq_rounded,
                  title: 'কী শুনবেন',
                  subtitle: settings.readBanglaAfterArabic ? 'আরবি + বাংলা অর্থ' : 'শুধু আরবি',
                  onTap: () => _pickAudioMode(context),
                ),
                _Row(
                  icon: Icons.translate_rounded,
                  title: 'বাংলা কণ্ঠ পরীক্ষা করুন',
                  subtitle: 'ফোনের বাংলা কণ্ঠে একটি বাক্য শুনুন',
                  onTap: () async {
                    if (await BanglaTts.init()) {
                      await BanglaTts.speak('আসসালামু আলাইকুম। বাংলা কণ্ঠ ঠিকমতো কাজ করছে।');
                    } else if (context.mounted) {
                      showNoBanglaVoiceDialog(context);
                    }
                  },
                ),
              ],
            ),
            const _Header('লেখার আকার'),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text('অ', style: TextStyle(fontSize: 14, color: p.muted)),
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
                      Text('অ', style: TextStyle(fontSize: 24, color: p.muted)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    'নমুনা: আল্লাহর রহমত থেকে নিরাশ হয়ো না।',
                    style: TextStyle(fontSize: 16 * settings.textScale, color: p.text),
                  ),
                ),
              ],
            ),
            const _Header('অন্যান্য'),
            _Group(
              children: [
                _Row(
                  icon: Icons.verified_user_rounded,
                  title: 'অনুমতি ও সেটআপ',
                  subtitle: 'রিমাইন্ডার না এলে এখানে দেখুন',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const SetupScreen())),
                ),
                _Row(
                  icon: Icons.dark_mode_rounded,
                  title: 'ডার্ক মোড',
                  subtitle: 'ফোনের সেটিং অনুযায়ী নিজে থেকেই বদলায়',
                ),
                _Row(
                  icon: Icons.favorite_rounded,
                  title: 'কৃতজ্ঞতা ও উৎস',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const CreditsScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pickReciter(BuildContext context) async {
  final settings = AppState.instance.settings;
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: RadioGroup<String>(
        groupValue: settings.reciterId,
        onChanged: (v) => Navigator.pop(context, v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'ক্বারী বেছে নিন',
                style: TextStyle(fontFamily: headingFont, fontSize: 18),
              ),
            ),
            for (final r in Reciter.all) RadioListTile<String>(value: r.id, title: Text(r.name)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (picked != null) await settings.setReciter(picked);
}

Future<void> _pickAudioMode(BuildContext context) async {
  final settings = AppState.instance.settings;
  final picked = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: RadioGroup<bool>(
        groupValue: settings.readBanglaAfterArabic,
        onChanged: (v) => Navigator.pop(context, v),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('কী শুনবেন', style: TextStyle(fontFamily: headingFont, fontSize: 18)),
            ),
            RadioListTile<bool>(value: false, title: Text('শুধু আরবি')),
            RadioListTile<bool>(
              value: true,
              title: Text('আরবি + বাংলা অর্থ'),
              subtitle: Text('আরবি তিলাওয়াতের পর ফোনের বাংলা কণ্ঠে অর্থ শোনাবে'),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (picked != null) await settings.setReadBanglaAfterArabic(picked);
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: headingFont,
        color: context.palette.accent,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
  );
}

/// Rounded card that groups several rows, with thin dividers between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(indent: 64, height: 1));
      rows.add(children[i]);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 21, color: p.primary),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: _IconBubble(icon),
        title: Text(
          title,
          style: const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 12.5)),
        trailing: trailing != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailing!,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                  ),
                ),
              )
            : (onTap != null ? Icon(Icons.chevron_right_rounded, color: p.muted) : null),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Opacity(
      opacity: onChanged == null ? 0.45 : 1,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        secondary: _IconBubble(icon),
        title: Text(
          title,
          style: const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: p.muted, fontSize: 12.5)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
