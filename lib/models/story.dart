import 'dart:convert';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// A story about a Sahabi (companion of the Prophet ﷺ).
class Story {
  const Story({
    required this.id,
    required this.companion,
    required this.title,
    required this.body,
    required this.lesson,
    required this.source,
    required this.status,
    this.note = '',
    this.hasAudio = false,
  });

  final String id;
  final String companion;
  final String title;
  final String body;
  final String lesson;
  final String source;

  /// Optional note for the reader (e.g. about sources), shown after the story.
  final String note;

  /// "draft - needs scholar review" until a scholar has checked it.
  final String status;

  /// True when a recorded MP3 is bundled in assets/story_audio/.
  final bool hasAudio;

  bool get isDraft => status.toLowerCase().contains('draft');

  String get audioAsset => 'assets/story_audio/$id.mp3';

  /// What the phone's voice reads aloud.
  String get spokenText => '$companion। $title।\n\n$body\n\nশিক্ষা: $lesson';

  /// Text used when the story is shared.
  String get shareText => [
    '$companion — $title',
    body,
    'শিক্ষা: $lesson',
    if (source.isNotEmpty) 'সূত্র: $source',
    if (note.isNotEmpty) note,
    '— আয়াত রিমাইন্ডার',
  ].join('\n\n');

  static Story fromJson(Map<String, dynamic> j, {bool hasAudio = false}) => Story(
    id: j['id'],
    companion: j['companion'],
    title: j['title'],
    body: j['body'],
    lesson: j['lesson'],
    source: j['source'],
    status: j['status'] ?? '',
    note: j['note'] ?? '',
    hasAudio: hasAudio,
  );

  static List<Story> listFromJson(String raw, Set<String> audioAssets) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return (data['stories'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      return fromJson(m, hasAudio: audioAssets.contains('assets/story_audio/${m['id']}.mp3'));
    }).toList();
  }

  static Future<List<Story>> load() async {
    final raw = await rootBundle.loadString('assets/stories.json');
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return listFromJson(raw, manifest.listAssets().toSet());
  }
}
