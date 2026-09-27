import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';

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
          const Text(
            'এই অ্যাপের সব আয়াত ও হাদিস নিচের উৎসগুলো থেকে হুবহু নেওয়া হয়েছে। কোনো লেখা পরিবর্তন করা হয়নি।',
            style: TextStyle(height: 1.6),
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
            icon: Icons.font_download_outlined,
            name: 'ফন্ট',
            what: 'Amiri Quran (আরবি) ও Noto Sans Bengali (বাংলা)',
            details:
                'SIL Open Font License 1.1 — The Amiri Project Authors, The Noto Project Authors.',
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
                  Icon(icon, color: AppColors.green),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(what, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              SelectableText(details, style: const TextStyle(color: AppColors.muted, height: 1.5)),
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
