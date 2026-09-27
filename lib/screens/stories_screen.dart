import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../models/story.dart';
import '../services/audio.dart';
import '../theme.dart';
import '../widgets/audio_button.dart';
import '../widgets/item_view.dart';
import '../widgets/pattern.dart';

/// "সাহাবিদের গল্প": a card for each story.
class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stories = AppState.instance.stories;
    return Scaffold(
      appBar: AppBar(title: const Text('সাহাবিদের গল্প')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: stories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) =>
            i == 0 ? const _Intro() : _StoryCard(story: stories[i - 1], number: i),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text(
      'রাসূলুল্লাহ (সা.)-এর সাহাবিদের জীবনের সত্য ঘটনা—সহীহ হাদিস ও সীরাত গ্রন্থ থেকে সহজ ভাষায়। '
      'গল্পগুলো এখনো খসড়া; একজন আলেম যাচাই করে দেখবেন।',
      style: TextStyle(color: p.muted, height: 1.6, fontSize: 13.5),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.number});

  final Story story;
  final int number;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => StoryScreen(story: story))),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              width: 110,
              height: 110,
              child: Stack(children: [PatternLayer(color: p.pattern, opacity: 0.08, cell: 34)]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [p.heroEnd, p.heroStart]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      toBanglaDigits(number),
                      style: const TextStyle(
                        fontFamily: headingFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: Brand.lightGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(story.companion, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(story.title, style: TextStyle(color: p.muted, fontSize: 13.5)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              story.hasAudio
                                  ? Icons.headphones_rounded
                                  : Icons.record_voice_over_rounded,
                              size: 15,
                              color: p.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              story.hasAudio ? 'অডিও আছে' : 'ফোনের কণ্ঠে শোনা যাবে',
                              style: TextStyle(fontSize: 12, color: p.accent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reading page for one story, with Listen and Share buttons.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.story});

  final Story story;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  @override
  void dispose() {
    if (AudioController.instance.currentId == widget.story.id) {
      AudioController.instance.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = widget.story;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.companion, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'শেয়ার করুন',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => SharePlus.instance.share(ShareParams(text: s.shareText)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(s.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AudioButton(
                  id: s.id,
                  label: 'শুনুন',
                  onToggle: () => AudioController.instance.toggleStory(s),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: s.shareText)),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('শেয়ার'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.hasAudio ? 'কণ্ঠ: ElevenLabs' : 'এই গল্পটি এখন ফোনের বাংলা কণ্ঠে শোনা যাবে।',
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          BanglaText(s.body, size: 17),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(radiusM),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded, color: p.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: BanglaText('শিক্ষা: ${s.lesson}', size: 16, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (s.source.isNotEmpty) BanglaText('সূত্র: ${s.source}', size: 13.5, color: p.muted),
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: p.border),
                borderRadius: BorderRadius.circular(radiusM),
              ),
              child: BanglaText(s.note, size: 13.5, color: p.muted),
            ),
          ],
          if (s.isDraft) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'খসড়া — একজন আলেমের যাচাই প্রয়োজন (draft - needs scholar review)',
                style: TextStyle(fontSize: 12.5, color: Colors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
