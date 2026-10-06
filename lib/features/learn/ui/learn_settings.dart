import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../../widgets/ui.dart';
import 'screens/learn_screens.dart';

/// The শিখুন heading of the সেটিংস page.
class LearnSettings extends StatelessWidget {
  const LearnSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return LearnGate(
      builder: (context, learn) {
        final p = context.palette;
        return RowGroup(
          children: [
            NavRow(
              icon: Icons.school_outlined,
              title: 'কুরআন বুঝি খুলুন',
              subtitle: 'পাঠ, রিভিউ ও অগ্রগতি',
              onTap: () => push(context, const LearnDashboardScreen()),
            ),
            NavRow(
              icon: Icons.format_underlined_rounded,
              tint: p.sky,
              title: 'শেখার মোড',
              subtitle: 'রিমাইন্ডারের আয়াতে চেনা শব্দ দাগ দিয়ে দেখাবে',
              trailing: Switch(value: learn.learningMode, onChanged: learn.setLearningMode),
            ),
            NavRow(
              icon: Icons.timer_outlined,
              tint: p.sand,
              title: 'প্রতিদিনের লক্ষ্য',
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 5, label: Text('৫')),
                  ButtonSegment(value: 10, label: Text('১০')),
                  ButtonSegment(value: 15, label: Text('১৫')),
                ],
                selected: {learn.dailyGoal},
                showSelectedIcon: false,
                onSelectionChanged: (v) => learn.setDailyGoal(v.first),
              ),
              subtitle: 'মিনিট',
            ),
            NavRow(
              icon: Icons.record_voice_over_outlined,
              tint: p.mint,
              title: 'বাংলা উচ্চারণ দেখার বোতাম',
              subtitle: 'শুধু প্রথম স্তরে, চাপ দিলে দেখা যায়',
              trailing: Switch(value: learn.showTranslit, onChanged: learn.setShowTranslit),
            ),
          ],
        );
      },
    );
  }
}
