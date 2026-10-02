import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/prayer.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart' show pickOption;

/// Reminder before the azan: off or minutes before.
const azanBeforeOptions = {
  0: 'বন্ধ',
  5: '৫ মিনিট আগে',
  10: '১০ মিনিট আগে',
  15: '১৫ মিনিট আগে',
  30: '৩০ মিনিট আগে',
};

/// Iqamah reminder: off or minutes after the azan.
const iqamahOptions = {
  0: 'বন্ধ',
  10: 'আজানের ১০ মিনিট পর',
  15: 'আজানের ১৫ মিনিট পর',
  20: 'আজানের ২০ মিনিট পর',
};

/// "+১০ মিনিট", "−৫ মিনিট", "ঠিক সময়ে".
String offsetLabel(int minutes) {
  if (minutes == 0) return 'ঠিক সময়ে';
  final sign = minutes > 0 ? '+' : '−';
  return '$sign${toBanglaDigits(minutes.abs())} মিনিট';
}

/// One prayer's azan: sound, time, reminders.
class AzanPrayerScreen extends StatefulWidget {
  const AzanPrayerScreen({super.key, required this.prayer});

  /// 'fajr', 'dhuhr', 'asr', 'maghrib' or 'isha'.
  final String prayer;

  @override
  State<AzanPrayerScreen> createState() => _AzanPrayerScreenState();
}

class _AzanPrayerScreenState extends State<AzanPrayerScreen> {
  AppSettings get _s => AppState.instance.settings;
  String get _k => widget.prayer;

  /// The adjustment while the slider is dragged (saved when let go).
  int? _dragOffset;

  Future<void> _changed() => Prayers.schedule(_s);

  PrayerTime? _today() {
    for (final p in Prayers.forDay(_s, DateTime.now())) {
      if (p.key == _k) return p;
    }
    return null;
  }

  Future<void> _pickFixedTime() async {
    final today = _today();
    final current = _s.azanFixedMinutes(_k);
    final start = current != null
        ? TimeOfDay(hour: current ~/ 60, minute: current % 60)
        : TimeOfDay.fromDateTime(today?.time ?? DateTime.now());
    final t = await showTimePicker(
      context: context,
      initialTime: start,
      helpText: '${Prayers.genitive(_k)} আজানের সময়',
    );
    if (t == null) return;
    await _s.setAzanFixedMinutes(_k, t.hour * 60 + t.minute);
    await _changed();
  }

  @override
  Widget build(BuildContext context) {
    final name = Prayers.names[_k]!;
    return Scaffold(
      appBar: AppBar(title: Text('$name · আজান')),
      body: ListenableBuilder(listenable: _s, builder: (context, _) => _body(context, name)),
    );
  }

  Widget _body(BuildContext context, String name) {
    final p = context.palette;
    final today = _today();
    final sound = _s.azanSound(_k);
    final fixed = _s.azanFixedMinutes(_k);
    final offset = _dragOffset ?? _s.azanOffset(_k);
    final fajr = _k == 'fajr';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        if (today != null)
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Text('আজ', style: TextStyle(color: p.muted, fontSize: 14)),
                ),
                Text(
                  adjustedTimeText(_s, today),
                  key: const ValueKey('azan-today'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
                ),
              ],
            ),
          ),
        const SectionLabel('আজানের শব্দ'),
        RowGroup(
          children: [
            for (final e in Prayers.azanSounds.entries)
              _SoundRow(
                id: e.key,
                label: e.value,
                selected: sound == e.key,
                subtitle: switch (e.key) {
                  'nabawi' || 'haram' => fajr ? 'ফজরের নিজস্ব আজান' : null,
                  'notify' => 'আজান বাজবে না, শুধু নোটিফিকেশন',
                  _ => 'এই ওয়াক্তে কিছু জানাবে না',
                },
                onSelect: () async {
                  await _s.setAzanSound(_k, e.key);
                  await _changed();
                },
                onListen: e.key == 'nabawi' || e.key == 'haram'
                    ? () => Prayers.playNow(sound: e.key, fajr: fajr)
                    : null,
              ),
          ],
        ),
        const SectionLabel('আজানের সময়'),
        RowGroup(
          children: [
            NavRow(
              icon: Icons.edit_calendar_outlined,
              tint: p.sand,
              title: 'নিজে সময় দিন',
              subtitle: fixed == null
                  ? 'যেমন মসজিদের নিজের আজানের সময়; প্রতিদিন এই সময়েই বাজবে'
                  : 'প্রতিদিন ${formatClock(DateTime(2000, 1, 1, fixed ~/ 60, fixed % 60))} · বদলাতে চাপ দিন',
              onTap: _pickFixedTime,
              trailing: Switch(
                value: fixed != null,
                onChanged: (v) async {
                  if (v) {
                    await _pickFixedTime();
                  } else {
                    await _s.setAzanFixedMinutes(_k, null);
                    await _changed();
                  }
                },
              ),
            ),
            if (fixed == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'সময় আগে-পিছে করুন',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                        ),
                        Text(
                          offsetLabel(offset),
                          style: TextStyle(color: p.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      'স্থানীয় মসজিদের সাথে মেলাতে, −৩০ থেকে +৩০ মিনিট',
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: '১ মিনিট আগে',
                          onPressed: offset <= -30 ? null : () => _setOffset(offset - 1),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Expanded(
                          child: Slider(
                            min: -30,
                            max: 30,
                            divisions: 60,
                            value: offset.toDouble(),
                            label: offsetLabel(offset),
                            onChanged: (v) => setState(() => _dragOffset = v.round()),
                            onChangeEnd: (v) => _setOffset(v.round()),
                          ),
                        ),
                        IconButton(
                          tooltip: '১ মিনিট পরে',
                          onPressed: offset >= 30 ? null : () => _setOffset(offset + 1),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SectionLabel('রিমাইন্ডার'),
        RowGroup(
          children: [
            NavRow(
              icon: Icons.alarm_outlined,
              tint: p.sky,
              title: 'নামাজের আগে রিমাইন্ডার',
              subtitle: azanBeforeOptions[_s.azanBefore(_k)] ?? 'বন্ধ',
              onTap: () async {
                final v = await pickOption<int>(
                  context,
                  'আজানের কত আগে জানাবে',
                  _s.azanBefore(_k),
                  azanBeforeOptions,
                );
                if (v != null) {
                  await _s.setAzanBefore(_k, v);
                  await _changed();
                }
              },
            ),
            NavRow(
              icon: Icons.groups_outlined,
              tint: p.lilac,
              title: 'ইকামতের রিমাইন্ডার',
              subtitle: iqamahOptions[_s.iqamahAfter(_k)] ?? 'বন্ধ',
              onTap: () async {
                final v = await pickOption<int>(
                  context,
                  'ইকামতের রিমাইন্ডার',
                  _s.iqamahAfter(_k),
                  iqamahOptions,
                );
                if (v != null) {
                  await _s.setIqamahAfter(_k, v);
                  await _changed();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'ভলিউম, সাইলেন্ট মোড ও কম্পন সব ওয়াক্তের জন্য একসাথে: নামাজের সময় পাতার নিচে '
          '"আজানের সেটিংস"-এ। হিসাবের পদ্ধতি ও আসরের (হানাফি) সময় আগের মতোই থাকবে।',
          style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
        ),
      ],
    );
  }

  Future<void> _setOffset(int v) async {
    setState(() => _dragOffset = null);
    await _s.setAzanOffset(_k, v);
    await _changed();
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.id,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.subtitle,
    this.onListen,
  });

  final String id;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onSelect,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? p.primary : p.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: p.text,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 13)),
                  ],
                ),
              ),
              if (onListen != null)
                TextButton.icon(
                  key: ValueKey('listen-$id'),
                  onPressed: onListen,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('শুনে দেখুন'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "আসর ৩:৪৫ → আজান ৩:৫৫" when the azan is moved, else "আসর ৩:৪৫".
String adjustedTimeText(AppSettings s, PrayerTime p) {
  final calc = '${p.name} ${formatClock(p.time, withPart: false)}';
  if (!Prayers.isAdjusted(s, p.key)) return calc;
  return '$calc → আজান ${formatClock(Prayers.azanTime(s, p), withPart: false)}';
}
