import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/permissions.dart';
import '../services/system_settings.dart';
import '../theme.dart';

/// Orange for things still to do.
const warnOrange = Brand.warn;

/// Green "✓ চালু", orange "বাকি", or grey "ঐচ্ছিক" for an optional item that is off.
class StatusChip extends StatelessWidget {
  const StatusChip(this.granted, {super.key, this.optional = false});

  final bool granted;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = granted ? p.primary : (optional ? p.muted : warnOrange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            granted
                ? Icons.check_circle_rounded
                : (optional ? Icons.info_outline_rounded : Icons.error_outline_rounded),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            granted ? 'চালু' : (optional ? 'ঐচ্ছিক' : 'বাকি'),
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// The phone maker's settings, each with an "open" button and a "করেছি" tick
/// (Android can't tell whether these are on).
class BrandStepsList extends StatelessWidget {
  const BrandStepsList({super.key, required this.brand, this.onChanged});

  final PhoneBrand brand;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance.settings;
    final p = context.palette;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final done = s.brandStepsDone;
        return Column(
          children: [
            for (final st in brand.steps)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(radiusM),
                  border: Border.all(
                    color: done.contains(st.id) ? p.primary.withValues(alpha: 0.5) : p.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st.title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text),
                    ),
                    const SizedBox(height: 2),
                    Text(st.how, style: TextStyle(color: p.muted, fontSize: 14, height: 1.5)),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: st.open,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('খুলুন'),
                        ),
                        const Spacer(),
                        Text('করেছি', style: TextStyle(color: p.text)),
                        Checkbox(
                          value: done.contains(st.id),
                          onChanged: (v) async {
                            await s.setBrandStepDone(st.id, v ?? false);
                            onChanged?.call();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// When "Display over other apps" is greyed out ("App restricted …"): Android
/// blocks it for apps installed from a file (not from Play Store) until the
/// user allows restricted settings.
class RestrictedSettingsHelp extends StatelessWidget {
  const RestrictedSettingsHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget step(String n, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.pill, shape: BoxShape.circle),
            child: Text(
              n,
              style: TextStyle(color: p.primary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: p.text, fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(radiusM),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'সুইচটি ধূসর / "restricted" লেখা দেখালে',
            style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'ফাইল থেকে ইনস্টল করা অ্যাপে (Play Store ছাড়া) Android এই অনুমতি আটকে রাখতে পারে। '
            'Play Store থেকে ইনস্টল করলে এই সমস্যা হয় না।',
            style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
          ),
          step('১', 'নিচের বোতাম চেপে "অ্যাপের তথ্য" (App info) খুলুন।'),
          step(
            '২',
            'উপরে ডান কোণের ⋮ চাপুন → "Allow restricted settings" (সীমাবদ্ধ সেটিং অনুমতি দিন)।',
          ),
          step('৩', 'তারপর "Display over other apps" / "অন্য অ্যাপের উপরে দেখানো" চালু করুন।'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: SystemSettings.openAppDetails,
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('অ্যাপের তথ্য খুলুন'),
          ),
          const SizedBox(height: 4),
          Text(
            'এটি চালু না করলেও রিমাইন্ডার, আজান ও সেহরির অ্যালার্ম নোটিফিকেশন হিসেবে আসবে।',
            style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
