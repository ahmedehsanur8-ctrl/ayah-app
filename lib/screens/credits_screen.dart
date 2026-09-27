import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
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
                'Tanzil Quran Text (Uthmani) — Copyright © Tanzil Project. '
                'License: Creative Commons Attribution 3.0. https://tanzil.net',
            extra: data.tanzilLicense,
          ),
          _Source(
            icon: Icons.translate,
            name: 'QuranEnc.com',
            what: 'আয়াতের বাংলা অনুবাদ ও টীকা — ড. আবু বকর মুহাম্মাদ যাকারিয়া',
            details: [
              if (data.quranEncTitle.isNotEmpty) data.quranEncTitle,
              version.isEmpty
                  ? 'সংস্করণ (Version): QuranEnc-এর API এই অনুবাদের সংস্করণ নম্বর দেয় না'
                  : 'সংস্করণ (Version): $version',
              'ডাউনলোডের তারিখ: ${toBanglaDigits(data.downloadedOn)}',
              'Key: bengali_zakaria',
              'https://quranenc.com',
            ].join('\n'),
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
            what: 'আরবি তিলাওয়াতের অডিও (আয়াত অনুযায়ী MP3)',
            details:
                'ক্বারী: মিশারি রাশিদ আলাফাসি, আব্দুল বাসিত আব্দুস সামাদ, মাহমুদ খলিল আল-হুসারি। '
                'শুধু মানুষের কণ্ঠের তিলাওয়াত। https://everyayah.com',
          ),
          const _Source(
            icon: Icons.record_voice_over_rounded,
            name: 'ElevenLabs',
            what: 'সাহাবিদের গল্পের কণ্ঠ — Story voice by ElevenLabs',
            details:
                'যে গল্পের অডিও এখনো তৈরি হয়নি, সেটি ফোনের বাংলা কণ্ঠে (Text-to-speech) পড়া হয়। '
                'আরবি তিলাওয়াত কখনো কৃত্রিম কণ্ঠে নয়। https://elevenlabs.io',
          ),
          const _Source(
            icon: Icons.menu_book_outlined,
            name: 'সাহাবিদের গল্প',
            what: 'সহীহ হাদিস ও সীরাত গ্রন্থের ভিত্তিতে সহজ বাংলায় লেখা',
            details: 'প্রতিটি গল্পের শেষে সূত্র দেওয়া আছে। গল্পগুলো এখনো খসড়া; একজন আলেমের যাচাই প্রয়োজন।',
          ),
          const _Source(
            icon: Icons.font_download_outlined,
            name: 'ফন্ট',
            what: 'Amiri Quran (আরবি), Noto Sans Bengali ও Hind Siliguri (বাংলা)',
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
                      color: context.palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: context.palette.primary),
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
