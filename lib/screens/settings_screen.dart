import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/duas.dart';
import '../services/audio.dart';
import '../services/bangla_tts.dart';
import '../services/reminders.dart';
import '../services/rotation.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/audio_button.dart';
import '../widgets/ui.dart';
import 'reader_screen.dart' show speedLabel;

enum SettingsSection { reminders, audio, display }

/// One part of the settings, opened from আরও.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.section});

  final SettingsSection section;

  static String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final part = t.hour < 12 ? 'সকাল' : (t.hour < 16 ? 'দুপুর' : (t.hour < 18 ? 'বিকাল' : 'রাত'));
    return '$part ${toBanglaDigits('$h:$m')}';
  }

  static Future<void> reschedule() async {
    final s = AppState.instance;
    await Reminders.reschedule(s.settings, s.data);
  }

  /// Rings a test reminder in one minute (lock the phone and wait).
  static void sendTestReminder(BuildContext context) {
    final s = AppState.instance;
    final item = s.rotation.morning(Rotation.dayNumber(Reminders.nowDhaka()));
    if (item != null) Reminders.testIn(item, seconds: 60);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 6),
        content: Text('১ মিনিট পর একটি পরীক্ষামূলক রিমাইন্ডার আসবে। এখন ফোন লক করে অপেক্ষা করুন।'),
      ),
    );
  }

  static const reminderSounds = {
    'chime': 'মৃদু ঘণ্টাধ্বনি',
    'bell': 'শান্ত ঘণ্টা',
    'phone': 'ফোনের নোটিফিকেশন শব্দ',
    'tilawat': 'আয়াতের তিলাওয়াতের শুরু',
    'off': 'শব্দ ছাড়া',
  };

  @override
  Widget build(BuildContext context) {
    final settings = AppState.instance.settings;
    final title = switch (section) {
      SettingsSection.reminders => 'রিমাইন্ডার',
      SettingsSection.audio => 'অডিও ও ক্বারী',
      SettingsSection.display => 'লেখার আকার ও ডার্ক মোড',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: switch (section) {
            SettingsSection.reminders => _reminders(context, settings),
            SettingsSection.audio => _audio(context, settings),
            SettingsSection.display => _display(context, settings),
          },
        ),
      ),
    );
  }

  List<Widget> _reminders(BuildContext context, AppSettings settings) {
    Future<void> pickTime(
      TimeOfDay initial,
      String help,
      Future<void> Function(TimeOfDay) save,
    ) async {
      final t = await showTimePicker(
        context: context,
        initialTime: initial,
        helpText: help,
        cancelText: 'বাতিল',
        confirmText: 'ঠিক আছে',
      );
      if (t == null) return;
      await save(t);
      await reschedule();
    }

    return [
      RowGroup(
        children: [
          NavRow(
            icon: Icons.notifications_none_rounded,
            title: 'রিমাইন্ডার চালু',
            subtitle: 'প্রতিদিন সকাল ও রাতে মনে করিয়ে দেবে',
            trailing: Switch(
              value: settings.remindersOn,
              onChanged: (v) async {
                await settings.setRemindersOn(v);
                await reschedule();
              },
            ),
          ),
          NavRow(
            icon: Icons.wb_sunny_outlined,
            tint: context.palette.sand,
            title: 'সকালের সময় · আয়াত',
            subtitle: formatTime(settings.morningTime),
            onTap: settings.remindersOn
                ? () => pickTime(
                    settings.morningTime,
                    'সকালের রিমাইন্ডারের সময়',
                    settings.setMorningTime,
                  )
                : null,
          ),
          NavRow(
            icon: Icons.nightlight_outlined,
            tint: context.palette.lilac,
            title: settings.hadithAtNight ? 'রাতের সময় · হাদিস' : 'রাতের সময় · আয়াত',
            subtitle: formatTime(settings.nightTime),
            onTap: settings.remindersOn
                ? () =>
                      pickTime(settings.nightTime, 'রাতের রিমাইন্ডারের সময়', settings.setNightTime)
                : null,
          ),
          NavRow(
            icon: Icons.format_quote_rounded,
            tint: context.palette.sky,
            title: 'রাতে হাদিস দেখাও',
            subtitle: 'বন্ধ করলে রাতেও একটি আয়াত আসবে',
            trailing: Switch(
              value: settings.hadithAtNight,
              onChanged: settings.remindersOn
                  ? (v) async {
                      await settings.setHadithAtNight(v);
                      await reschedule();
                    }
                  : null,
            ),
          ),
          NavRow(
            icon: Icons.wb_twilight_rounded,
            tint: context.palette.mint,
            title: 'সকালের জিকিরের রিমাইন্ডার',
            subtitle: 'ফজরের ২০ মিনিট পর',
            trailing: Switch(
              value: settings.adhkarMorning,
              onChanged: (v) async {
                await settings.setAdhkarMorning(v);
                await AdhkarReminders.schedule(settings);
              },
            ),
          ),
          NavRow(
            icon: Icons.nights_stay_outlined,
            tint: context.palette.lilac,
            title: 'সন্ধ্যার জিকিরের রিমাইন্ডার',
            subtitle: 'আসরের ২০ মিনিট পর',
            trailing: Switch(
              value: settings.adhkarEvening,
              onChanged: (v) async {
                await settings.setAdhkarEvening(v);
                await AdhkarReminders.schedule(settings);
              },
            ),
          ),
          NavRow(
            icon: Icons.music_note_outlined,
            tint: context.palette.sand,
            title: 'রিমাইন্ডারের শব্দ',
            subtitle: '${reminderSounds[settings.reminderSound]} · অ্যালার্মের মতো, সাইলেন্টেও',
            onTap: () async {
              final v = await pickOption<String>(
                context,
                'রিমাইন্ডারের শব্দ',
                settings.reminderSound,
                reminderSounds,
              );
              if (v != null) {
                await settings.setReminderSound(v);
                await reschedule();
              }
            },
          ),
          NavRow(
            icon: Icons.vibration_rounded,
            tint: context.palette.mint,
            title: 'কাঁপুনি (ভাইব্রেশন)',
            trailing: Switch(
              value: settings.reminderVibrate,
              onChanged: (v) async {
                await settings.setReminderVibrate(v);
                await reschedule();
              },
            ),
          ),
          NavRow(
            icon: Icons.play_circle_outline_rounded,
            tint: context.palette.rose,
            title: '১ মিনিট পর পরীক্ষা করুন',
            subtitle: 'চাপ দিয়ে ফোন লক করুন — ১ মিনিট পর রিমাইন্ডার আসবে',
            onTap: () => sendTestReminder(context),
          ),
        ],
      ),
    ];
  }

  List<Widget> _audio(BuildContext context, AppSettings settings) => [
    RowGroup(
      children: [
        NavRow(
          icon: Icons.mic_none_rounded,
          title: 'ক্বারী (আরবি তিলাওয়াত)',
          subtitle: Reciter.byId(settings.reciterId).name,
          onTap: () async {
            final v = await pickOption<String>(context, 'ক্বারী বেছে নিন', settings.reciterId, {
              for (final r in Reciter.all) r.id: r.name,
            });
            if (v != null) await settings.setReciter(v);
          },
        ),
        NavRow(
          icon: Icons.graphic_eq_rounded,
          tint: context.palette.sky,
          title: 'কী শুনবেন',
          subtitle: settings.readBanglaAfterArabic ? 'আরবি + বাংলা অর্থ' : 'শুধু আরবি',
          onTap: () async {
            final v = await pickOption<bool>(context, 'কী শুনবেন', settings.readBanglaAfterArabic, {
              false: 'শুধু আরবি',
              true: 'আরবি + বাংলা অর্থ (তিলাওয়াতের পর ফোনের বাংলা কণ্ঠে)',
            });
            if (v != null) await settings.setReadBanglaAfterArabic(v);
          },
        ),
        NavRow(
          icon: Icons.speed_rounded,
          tint: context.palette.sand,
          title: 'তিলাওয়াতের গতি',
          subtitle: speedLabel(settings.playbackSpeed),
          onTap: () async {
            final v = await pickOption<double>(context, 'তিলাওয়াতের গতি', settings.playbackSpeed, {
              for (final s in AudioController.speeds) s: speedLabel(s),
            });
            if (v != null) await AudioController.instance.setSpeed(v);
          },
        ),
        NavRow(
          icon: Icons.translate_rounded,
          tint: context.palette.lilac,
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
  ];

  List<Widget> _display(BuildContext context, AppSettings settings) {
    final p = context.palette;
    return [
      const SectionLabel('লেখার আকার'),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('অ', style: TextStyle(fontSize: 14, color: p.muted)),
                Expanded(
                  child: Slider(
                    value: settings.textScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    label: '${toBanglaDigits((settings.textScale * 100).round())}%',
                    onChanged: settings.setTextScale,
                  ),
                ),
                Text('অ', style: TextStyle(fontSize: 24, color: p.muted)),
              ],
            ),
            Text(
              'নমুনা: আল্লাহর রহমত থেকে নিরাশ হয়ো না।',
              style: TextStyle(fontSize: 16 * settings.textScale, color: p.text),
            ),
          ],
        ),
      ),
      const SectionLabel('ডার্ক মোড'),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: RadioGroup<String>(
          groupValue: settings.themeModeName,
          onChanged: (v) => settings.setThemeMode(v ?? 'system'),
          child: const Column(
            children: [
              RadioListTile<String>(value: 'system', title: Text('ফোনের সেটিং অনুযায়ী')),
              RadioListTile<String>(value: 'light', title: Text('সবসময় আলো')),
              RadioListTile<String>(value: 'dark', title: Text('সবসময় ডার্ক')),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Bottom sheet with radio options; returns the picked value.
Future<T?> pickOption<T>(BuildContext context, String title, T current, Map<T, String> options) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: RadioGroup<T>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: titleStyle(context.palette, size: 18)),
              ),
              for (final e in options.entries) RadioListTile<T>(value: e.key, title: Text(e.value)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}
