import 'package:flutter/material.dart';

import '../models/content.dart';
import '../services/quran.dart';
import '../services/quran_player.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/quran_widgets.dart';
import '../widgets/ui.dart';

/// Recitations and translations saved on the phone, with their size.
class QuranDownloadsScreen extends StatefulWidget {
  const QuranDownloadsScreen({super.key});

  @override
  State<QuranDownloadsScreen> createState() => _QuranDownloadsScreenState();
}

class _QuranDownloadsScreenState extends State<QuranDownloadsScreen> {
  List<({String reciter, int surah, int files, int bytes})>? _audio;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final a = await QuranAudioFiles.all();
    if (mounted) setState(() => _audio = a);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final audio = _audio;
    final total = audio?.fold<int>(0, (s, e) => s + e.bytes) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('কুরআন ডাউনলোড')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SectionLabel('অনুবাদ'),
          AppCard(
            child: Row(
              children: [
                Icon(Icons.translate_rounded, color: p.primary),
                const SizedBox(width: 12),
                const Expanded(child: Text('অনুবাদ বেছে নিন, ডাউনলোড বা মুছে ফেলুন')),
                TextButton(
                  onPressed: () => showQuranSettingsSheet(context),
                  child: const Text('খুলুন'),
                ),
              ],
            ),
          ),
          SectionLabel(
            audio == null || audio.isEmpty ? 'তিলাওয়াত' : 'তিলাওয়াত · মোট ${formatBytes(total)}',
          ),
          if (audio == null)
            const Center(child: CircularProgressIndicator())
          else if (audio.isEmpty)
            Text(
              'এখনো কোনো তিলাওয়াত ফোনে রাখা হয়নি। সূরা পড়ার পাতায় তিলাওয়াতের অপশন থেকে পুরো সূরা '
              'ডাউনলোড করা যায়; একবার শোনা আয়াতও ফোনে থেকে যায়।',
              style: TextStyle(color: p.muted, height: 1.6),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < audio.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    ListTile(
                      title: Text('সূরা ${Quran.surah(audio[i].surah).nameBn}'),
                      subtitle: Text(
                        '${Reciter.byId(audio[i].reciter).name} · '
                        '${toBanglaDigits(audio[i].files)}/${toBanglaDigits(Quran.surah(audio[i].surah).ayahCount)} আয়াত · '
                        '${formatBytes(audio[i].bytes)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'মুছে ফেলুন',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () async {
                          await QuranAudioFiles.deleteSurah(audio[i].reciter, audio[i].surah);
                          _refresh();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
