import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import '../widgets/ui.dart';
import 'about_screen.dart';
import 'credits_screen.dart';
import 'favorites_screen.dart';
import 'prayer_screen.dart';
import 'qibla_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

/// আরও: prayer times, Qibla, favourites, settings and about.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const shareText =
      'আয়াত রিমাইন্ডার — প্রতিদিন সকালে কুরআনের একটি আয়াত আর রাতে একটি হাদিস, '
      'আরবি ও বাংলা অর্থসহ। মন কেমন সেই অনুযায়ী আয়াত, নামাজের সময় ও কিবলা। '
      'সম্পূর্ণ বিনামূল্যে, কোনো বিজ্ঞাপন নেই।';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget big(IconData icon, String label, Tint tint, Widget page) => Expanded(
      child: Material(
        color: tint.background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => push(context, page),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: tint.foreground, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tint.foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const PageTitle('আরও'),
            Row(
              children: [
                big(Icons.schedule_outlined, 'নামাজের সময়', p.mint, const PrayerScreen()),
                const SizedBox(width: 10),
                big(Icons.explore_outlined, 'কিবলা', p.sky, const QiblaScreen()),
                const SizedBox(width: 10),
                big(Icons.favorite_border_rounded, 'প্রিয়', p.rose, const FavoritesScreen()),
              ],
            ),
            const SectionLabel('সেটিংস'),
            RowGroup(
              children: [
                NavRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'রিমাইন্ডার',
                  subtitle: 'সকাল ও রাতের সময়',
                  onTap: () =>
                      push(context, const SettingsScreen(section: SettingsSection.reminders)),
                ),
                NavRow(
                  icon: Icons.mic_none_rounded,
                  tint: p.sky,
                  title: 'অডিও ও ক্বারী',
                  subtitle: 'ক্বারী, বাংলা অর্থ, গতি',
                  onTap: () => push(context, const SettingsScreen(section: SettingsSection.audio)),
                ),
                NavRow(
                  icon: Icons.format_size_rounded,
                  tint: p.sand,
                  title: 'লেখার আকার ও ডার্ক মোড',
                  onTap: () =>
                      push(context, const SettingsScreen(section: SettingsSection.display)),
                ),
                NavRow(
                  icon: Icons.verified_user_outlined,
                  tint: p.lilac,
                  title: 'অনুমতি ও সেটআপ',
                  subtitle: 'রিমাইন্ডার না এলে এখানে দেখুন · পরীক্ষামূলক রিমাইন্ডার',
                  onTap: () => push(context, const SetupScreen()),
                ),
              ],
            ),
            const SectionLabel('অ্যাপ সম্পর্কে'),
            RowGroup(
              children: [
                NavRow(
                  icon: Icons.person_outline_rounded,
                  title: 'ডেভেলপার সম্পর্কে',
                  onTap: () => push(context, const AboutScreen()),
                ),
                NavRow(
                  icon: Icons.volunteer_activism_outlined,
                  tint: p.sand,
                  title: 'কৃতজ্ঞতা ও উৎস',
                  onTap: () => push(context, const CreditsScreen()),
                ),
                NavRow(
                  icon: Icons.share_outlined,
                  tint: p.sky,
                  title: 'অ্যাপ শেয়ার করুন',
                  onTap: () => SharePlus.instance.share(ShareParams(text: shareText)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
