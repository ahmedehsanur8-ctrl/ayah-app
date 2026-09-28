import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/permissions.dart';
import '../theme.dart';

/// Orange for things still to do.
const warnOrange = Color(0xFFE0851B);

/// Green "✓ চালু" or orange "বাকি".
class StatusChip extends StatelessWidget {
  const StatusChip(this.granted, {super.key});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = granted ? p.primary : warnOrange;
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
            granted ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            granted ? 'চালু' : 'বাকি',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
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
                    Text(st.how, style: TextStyle(color: p.muted, fontSize: 13, height: 1.5)),
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
