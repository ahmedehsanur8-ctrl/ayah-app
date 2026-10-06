import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../models/story.dart';
import '../services/audio.dart';
import '../theme.dart';
import '../widgets/audio_button.dart';
import '../widgets/item_view.dart';
import '../widgets/night.dart';
import '../widgets/ui.dart';

String _mmss(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return toBanglaDigits(h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s');
}

/// "সাহাবিদের জীবনী" (Life of the Sahaba).
class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stories = AppState.instance.stories;
    final settings = AppState.instance.settings;
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            final last = stories
                .where((s) => s.id == settings.lastStoryId && s.hasAudio)
                .firstOrNull;
            final pos = last == null ? Duration.zero : settings.storyPosition(last.id);
            final len = last == null ? Duration.zero : settings.storyLength(last.id);
            final showContinue =
                last != null &&
                pos > const Duration(seconds: 5) &&
                len > Duration.zero &&
                pos < len - const Duration(seconds: 5);
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                NightHeader(
                  title: 'সাহাবিদের জীবনী',
                  subtitle:
                      'রাসূলুল্লাহ (সাঃ)-এর সাহাবিদের জীবনের ঘটনা, সহজ ভাষায়। '
                      'লেখাগুলো এখনো খসড়া; একজন আলেম যাচাই করে দেখবেন।',
                  lip: true,
                  child: showContinue
                      ? _ContinueCard(story: last, position: pos, length: len)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: ListSection(
                    children: [
                      for (var i = 0; i < stories.length; i++)
                        _StoryCard(story: stories[i], number: i + 1),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.story, required this.position, required this.length});

  final Story story;
  final Duration position;
  final Duration length;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dim = p.onNightMuted;
    return Material(
      color: p.nightLine,
      borderRadius: BorderRadius.circular(radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusM),
        onTap: () {
          push(context, StoryScreen(story: story));
          AudioController.instance.playStory(story);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: p.gold, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: p.night, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'শুনছিলেন',
                      style: TextStyle(color: p.gold, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      story.companion,
                      style: TextStyle(color: p.onNight, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: position.inMilliseconds / length.inMilliseconds,
                        minHeight: 4,
                        color: p.gold,
                        backgroundColor: p.nightLine,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_mmss(position)} / ${_mmss(length)}',
                      style: TextStyle(color: dim, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    return ListRow(
      leading: StarBadge(toBanglaDigits(number), size: 44),
      title: story.companion,
      subtitle: '${story.title}, ${story.hasAudio ? 'অডিও আছে' : 'শীঘ্রই অডিও'}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            story.hasAudio ? Icons.headphones_outlined : Icons.schedule_outlined,
            size: 20,
            color: story.hasAudio ? p.primary : p.muted,
            semanticLabel: story.hasAudio ? 'অডিও আছে' : 'শীঘ্রই অডিও',
          ),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
      onTap: () => push(context, StoryScreen(story: story)),
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
    final audio = AudioController.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.companion, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'শেয়ার করুন',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(ShareParams(text: s.shareText)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(s.title, style: titleStyle(p, size: 24)),
          const SizedBox(height: 14),
          AudioButton(id: s.id, label: 'শুনুন', onToggle: () => audio.toggleStory(s)),
          if (s.hasAudio)
            ListenableBuilder(
              listenable: audio,
              builder: (context, _) {
                if (audio.currentId != s.id || audio.status == AudioStatus.idle) {
                  return const SizedBox.shrink();
                }
                return StreamBuilder<Duration>(
                  stream: audio.positionStream,
                  builder: (context, snap) {
                    final dur = audio.duration ?? Duration.zero;
                    final pos = snap.data ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    return Row(
                      children: [
                        Text(_mmss(pos), style: TextStyle(fontSize: 14, color: p.muted)),
                        Expanded(
                          child: Slider(
                            value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, max).toDouble(),
                            max: max <= 0 ? 1 : max,
                            onChanged: max <= 0
                                ? null
                                : (v) => audio.seek(Duration(milliseconds: v.round())),
                          ),
                        ),
                        Text(_mmss(dur), style: TextStyle(fontSize: 14, color: p.muted)),
                      ],
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 4),
          Text(
            s.hasAudio
                ? 'কণ্ঠ: ElevenLabs · যেখানে থেমেছিলেন সেখান থেকে চলবে'
                : 'এই জীবনীটি এখন ফোনের বাংলা কণ্ঠে শোনা যাবে।',
            style: TextStyle(color: p.muted, fontSize: 14),
          ),
          const SizedBox(height: 18),
          BanglaText(s.body, size: 17),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.sand.background,
              borderRadius: BorderRadius.circular(radiusM),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: p.sand.foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: BanglaText(
                    'শিক্ষা: ${s.lesson}',
                    size: 16,
                    weight: FontWeight.w700,
                    color: p.sand.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (s.source.isNotEmpty) BanglaText('সূত্র: ${s.source}', size: 13.5, color: p.muted),
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(child: BanglaText(s.note, size: 13.5, color: p.muted)),
          ],
          if (s.isDraft) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.rose.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'খসড়া — একজন আলেমের যাচাই প্রয়োজন (draft - needs scholar review)',
                style: TextStyle(fontSize: 14, color: p.rose.foreground),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
