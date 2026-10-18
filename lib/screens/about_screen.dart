import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/content.dart';
import '../theme.dart';
import '../widgets/pattern.dart';
import '../widgets/ui.dart';
import 'privacy_screen.dart';

/// অ্যাপ ও ডেভেলপার.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ ও ডেভেলপার')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          const SizedBox(height: 8),
          const Center(child: AppLogo(size: 92)),
          const SizedBox(height: 14),
          Text('আয়াত রিমাইন্ডার', textAlign: TextAlign.center, style: titleStyle(p, size: 26)),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => Text(
              snap.hasData ? 'সংস্করণ ${toBanglaDigits(snap.data!.version)}' : ' ',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: InfoPill(
              icon: Icons.check_circle_outline_rounded,
              text: 'সম্পূর্ণ বিনামূল্যে · কোনো বিজ্ঞাপন নেই',
              tint: p.mint,
            ),
          ),
          const SizedBox(height: 22),
          AppCard(
            radius: radiusL,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBubble(Icons.person_outline_rounded, tint: p.sand, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('তৈরি করেছেন', style: TextStyle(color: p.muted, fontSize: 14)),
                          Text(
                            'Ahmed Ehsanur Rahman',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                          Text('সিলেট, বাংলাদেশ', style: TextStyle(color: p.muted, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.mint.background,
                    borderRadius: BorderRadius.circular(radiusM),
                  ),
                  child: Text(
                    'এই অ্যাপটি বানানো হয়েছে যেন প্রতিদিন কুরআন ও হাদিসের কথা আমাদের মনে আশা জাগায়। '
                    'উপকার পেলে দোয়ায় রাখবেন।',
                    style: TextStyle(color: p.mint.foreground, fontSize: 15.5, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          RowGroup(
            children: [
              NavRow(
                icon: Icons.privacy_tip_outlined,
                tint: p.sky,
                title: 'গোপনীয়তা নীতি',
                subtitle: 'কোনো তথ্য সংগ্রহ করা হয় না',
                onTap: () => push(context, const PrivacyScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
