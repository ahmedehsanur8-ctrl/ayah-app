import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/prayer.dart';
import '../services/quran.dart';
import '../theme.dart';
import '../widgets/pattern.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppState.instance.data;
    final version = data.quranEncVersion;
    return Scaffold(
      appBar: AppBar(title: const Text('কৃতজ্ঞতা ও উৎস')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: AppLogo(size: 84)),
          const SizedBox(height: 12),
          Text(
            'আয়াত রিমাইন্ডার',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'এই অ্যাপের সব আয়াত ও হাদিস নিচের উৎসগুলো থেকে হুবহু নেওয়া হয়েছে। কোনো লেখা পরিবর্তন করা হয়নি। অ্যাপটি সম্পূর্ণ বিনামূল্যে, কোনো বিজ্ঞাপন নেই।',
            style: TextStyle(height: 1.6, color: context.palette.text),
          ),
          const SizedBox(height: 16),
          _Source(
            icon: Icons.menu_book_rounded,
            name: 'Tanzil.net',
            what: 'কুরআনের আরবি লেখা (উসমানি লিপি)',
            details:
                'Tanzil Quran Text (Uthmani${Quran.arabicInfo['version'] != null && '${Quran.arabicInfo['version']}'.isNotEmpty ? ', Version ${Quran.arabicInfo['version']}' : ''}) — Copyright © Tanzil Project. '
                'License: Creative Commons Attribution 3.0. https://tanzil.net\n'
                'পূর্ণ কুরআন (৬২৩৬ আয়াত) অ্যাপের ভেতরেই রাখা, হুবহু। '
                'ডাউনলোডের তারিখ: ${toBanglaDigits(Quran.downloadedOn)}',
            extra: data.tanzilLicense.isNotEmpty
                ? data.tanzilLicense
                : '${Quran.arabicInfo['licenseHeader'] ?? ''}',
          ),
          for (final t in Quran.translations)
            _Source(
              icon: Icons.translate,
              name: t.name,
              what: t.bundled
                  ? 'পূর্ণ কুরআনের বাংলা অনুবাদ ও টীকা (অ্যাপের সাথেই আছে)'
                  : 'পূর্ণ কুরআনের বাংলা অনুবাদ (বেছে নিলে ডাউনলোড হয়)',
              details: [
                '${t.nameEn} — ${t.publisher}',
                if (t.title.isNotEmpty) t.title,
                if (t.version.isNotEmpty) 'সংস্করণ: ${t.version}',
                if (t.lastUpdate.isNotEmpty) 'সর্বশেষ হালনাগাদ (উৎসে): ${t.lastUpdate}',
                if (t.nonCommercial)
                  'শর্ত: Tanzil-এর অনুবাদ শুধু অবাণিজ্যিক ব্যবহারের জন্য। '
                      'এই অ্যাপ বিনামূল্যে ও বিজ্ঞাপনমুক্ত।',
                'লেখা হুবহু, কোনো পরিবর্তন করা হয়নি।',
                t.url,
              ].join('\n'),
              extra: t.licenseHeader,
            ),
          _Source(
            icon: Icons.translate,
            name: 'QuranEnc.com',
            what: 'আয়াতের বাংলা অনুবাদ ও টীকা — ড. আবু বকর মুহাম্মাদ যাকারিয়া',
            details: [
              if (data.quranEncTitle.isNotEmpty) data.quranEncTitle,
              if (version.isNotEmpty) 'সংস্করণ: $version',
              'ডাউনলোডের তারিখ: ${toBanglaDigits(data.downloadedOn)}',
              'https://quranenc.com',
            ].join('\n'),
          ),
          const _Source(
            icon: Icons.front_hand_outlined,
            name: 'দোয়া ও জিকির',
            what:
                'দোয়ার আরবি পাঠ: কুরআন ও সহিহ হাদিস গ্রন্থসমূহ; কিছু হাদিস HadeethEnc.com থেকে। '
                'বাংলা অর্থ ও উচ্চারণ: অ্যাপ টিম (আলেম কর্তৃক যাচাই সাপেক্ষে)।',
            details:
                'কুরআনের দোয়ার আরবি Tanzil থেকে, বাংলা অর্থ ড. আবু বকর মুহাম্মাদ যাকারিয়ার অনুবাদ '
                '(QuranEnc.com) থেকে, হুবহু। প্রতিটি দোয়ার সঙ্গে মূল গ্রন্থের সূত্র ও মান দেওয়া আছে। '
                'সব দোয়া একজন আলেমের যাচাইয়ের অপেক্ষায়।',
          ),
          const _Source(
            icon: Icons.format_quote_rounded,
            name: 'HadeethEnc.com',
            what: 'হাদিসের আরবি, বাংলা অনুবাদ ও সংক্ষিপ্ত ব্যাখ্যা',
            details: 'Encyclopedia of Translated Prophetic Hadiths. https://hadeethenc.com',
          ),
          const _Source(
            icon: Icons.headphones_rounded,
            name: 'EveryAyah.com',
            what: 'আরবি তিলাওয়াতের অডিও (আয়াত অনুযায়ী MP3; কুরআন অংশে ডাউনলোড করে রাখা যায়)',
            details:
                'ক্বারী: মিশারি রাশিদ আলাফাসি, আব্দুল বাসিত আব্দুস সামাদ, মাহমুদ খলিল আল-হুসারি। '
                'শুধু মানুষের কণ্ঠের তিলাওয়াত। https://everyayah.com',
          ),
          const _Source(
            icon: Icons.record_voice_over_rounded,
            name: 'ElevenLabs',
            what: 'সাহাবিদের জীবনীর কণ্ঠ — Story voice by ElevenLabs',
            details:
                'যে জীবনীর অডিও এখনো তৈরি হয়নি, সেটি ফোনের বাংলা কণ্ঠে (Text-to-speech) পড়া হয়। '
                'আরবি তিলাওয়াত কখনো কৃত্রিম কণ্ঠে নয়। https://elevenlabs.io',
          ),
          _Source(
            icon: Icons.mosque_outlined,
            name: 'আজান',
            what: Prayers.azanBundled
                ? 'আজানের অডিও (Wikimedia Commons থেকে, অ্যাপের ভেতরেই রাখা, ইন্টারনেট লাগে না)'
                : 'আজানের অডিও এখনো যোগ করা হয়নি; শুধু নোটিফিকেশন আসে',
            details: [
              if (Prayers.azanBundled) _licenseText('সব ওয়াক্ত', Prayers.azanLicense),
              if (Prayers.azanLicense['fajr'] is Map)
                _licenseText('ফজর', (Prayers.azanLicense['fajr'] as Map).cast<String, dynamic>()),
            ].join('\n\n'),
          ),
          const _Source(
            icon: Icons.schedule_outlined,
            name: 'নামাজের সময় ও কিবলা',
            what: 'ফোনেই হিসাব করা হয়, ইন্টারনেট লাগে না',
            details: 'adhan (Dart) লাইব্রেরি — MIT License। অবস্থান শুধু ফোনে থাকে, কোথাও পাঠানো হয় না।',
          ),
          const _Source(
            icon: Icons.menu_book_outlined,
            name: 'সাহাবিদের জীবনী',
            what: 'সহীহ হাদিস ও সীরাত গ্রন্থের ভিত্তিতে সহজ বাংলায় লেখা',
            details: 'প্রতিটি জীবনীর শেষে সূত্র ও নোট দেওয়া আছে। লেখাগুলো এখনো খসড়া; একজন আলেমের যাচাই প্রয়োজন।',
          ),
          const _Source(
            icon: Icons.font_download_outlined,
            name: 'ফন্ট',
            what:
                'Amiri Quran (আরবি), Noto Serif Bengali, Hind Siliguri ও Noto Sans Bengali (বাংলা)',
            details: 'SIL Open Font License 1.1 — The Amiri Project Authors, The Noto Project Authors, Indian Type Foundry.',
          ),
          const _Source(
            icon: Icons.auto_awesome_rounded,
            name: 'নকশা',
            what: 'লোগো, জ্যামিতিক নকশা ও আইকন',
            details:
                'লোগো ও ইসলামি জ্যামিতিক নকশা অ্যাপের কোডেই আঁকা। '
                'আইকন: Material Icons (Apache License 2.0)।',
          ),
        ],
      ),
    );
  }
}

/// Title, author, licence and link of a bundled recording.
String _licenseText(String label, Map<String, dynamic> l) => [
  '$label: ${(l['title'] ?? '').toString().replaceFirst('File:', '')}',
  if ((l['author'] ?? '').toString().isNotEmpty) 'শিল্পী/আপলোডকারী: ${l['author']}',
  'লাইসেন্স: ${l['license']}',
  if ((l['source'] ?? '').toString().isNotEmpty) '${l['source']}',
].join('\n');

class _Source extends StatelessWidget {
  const _Source({
    required this.icon,
    required this.name,
    required this.what,
    required this.details,
    this.extra = '',
  });

  final IconData icon;
  final String name;
  final String what;
  final String details;
  final String extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.palette.mint.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: context.palette.mint.foreground),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.palette.text,
                      fontFamily: headingFont,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(what, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              SelectableText(details, style: TextStyle(color: context.palette.muted, height: 1.5)),
              if (extra.trim().isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('লাইসেন্সের পূর্ণ লেখা', style: TextStyle(fontSize: 14)),
                  children: [
                    SelectableText(
                      extra,
                      style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
