import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';

/// Privacy policy in simple Bangla (the English version is in docs/PRIVACY.md).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const sections = [
    (
      'কোনো তথ্য সংগ্রহ করা হয় না',
      'আয়াত রিমাইন্ডারে কোনো অ্যাকাউন্ট নেই। আপনার নাম, ফোন নম্বর বা অন্য কোনো ব্যক্তিগত তথ্য নেওয়া হয় না। '
          'কোনো বিজ্ঞাপন নেই, কোনো অ্যানালিটিক্স বা ট্র্যাকিং নেই।',
    ),
    (
      'অবস্থান (লোকেশন)',
      'নামাজের সময় ও কিবলার দিক হিসাব করার জন্য ফোনের আনুমানিক অবস্থান ব্যবহার করা হয়। '
          'হিসাব ফোনেই হয়; অবস্থান শুধু ফোনে থাকে, কোথাও পাঠানো হয় না। '
          'অনুমতি না দিলেও চলে — হাতে শহর বেছে নেওয়া যায়।',
    ),
    (
      'ইন্টারনেট',
      'ইন্টারনেট শুধু আরবি তিলাওয়াত শোনার সময় EveryAyah.com থেকে অডিও আনতে লাগে। '
          'একবার শোনা তিলাওয়াত ফোনে জমা থাকে। এই অনুরোধে আপনার কোনো তথ্য পাঠানো হয় না '
          '(যেকোনো ওয়েবসাইটের মতো, তাদের সার্ভার শুধু সংযোগের IP ঠিকানা দেখতে পায়)।',
    ),
    (
      'নোটিফিকেশন',
      'সকাল-রাতের রিমাইন্ডার ও আজানের নোটিফিকেশন ফোনেই তৈরি হয়; কোনো সার্ভার থেকে আসে না। '
          'রিমাইন্ডার অ্যালার্মের মতো পুরো স্ক্রিনে খুলতে "ফুল-স্ক্রিন", "সময়মতো অ্যালার্ম" ও '
          '"অন্য অ্যাপের উপরে দেখানো" অনুমতি ব্যবহার হয়; এগুলো শুধু রিমাইন্ডারের পাতা দেখাতে লাগে, '
          'কোনো তথ্য পড়ে না। আরও → সেটিংস থেকে রিমাইন্ডার ও আজান যেকোনো সময় বন্ধ করা যায়।',
    ),
    (
      'ফোনে যা থাকে',
      'আপনার সেটিংস, প্রিয় তালিকা, কোন জীবনী কতটুকু শুনেছেন এবং বেছে নেওয়া অবস্থান শুধু ফোনে থাকে। '
          'অ্যাপ মুছে ফেললে এগুলোও মুছে যায়।',
    ),
    (
      'বাংলা কণ্ঠ',
      'বাংলা অর্থ ও হাদিস পড়তে ফোনের নিজস্ব Text-to-speech ব্যবহার হয়। '
          'এটি আপনার ফোনের সেটিং অনুযায়ী কাজ করে।',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('গোপনীয়তা নীতি')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          for (final (title, body) in sections) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: TextStyle(color: p.text, height: 1.65)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
