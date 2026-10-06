/// Data of কুরআন বুঝি (Understand the Quran). Arabic text only ever comes from
/// [QuranWord.text], which is the Tanzil word, verbatim.
library;

/// One word of the Quran (Tanzil Uthmani), with its corpus grammar.
class QuranWord {
  const QuranWord({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.index,
    required this.text,
    required this.lemmaId,
    required this.root,
    required this.pos,
    this.segments = const [],
  });

  final int id;
  final int surah;
  final int ayah;

  /// 1-based position in the ayah.
  final int index;

  /// The Tanzil word, character for character.
  final String text;

  /// The stem's lemma (null for the 30 disconnected-letter words).
  final int? lemmaId;
  final String? root;
  final String? pos;

  /// Prefixes, stem and suffixes in reading order.
  final List<Segment> segments;

  QuranWord withSegments(List<Segment> s) => QuranWord(
    id: id,
    surah: surah,
    ayah: ayah,
    index: index,
    text: text,
    lemmaId: lemmaId,
    root: root,
    pos: pos,
    segments: s,
  );

  /// Every lemma in this word (prefixes, stem, attached pronouns).
  Iterable<int> get allLemmas => segments.map((s) => s.lemmaId).nonNulls;

  /// The part of [text] that belongs to [lemmaId], or null if the word is not split.
  (int, int)? spanOf(int lemmaId) {
    for (final s in segments) {
      if (s.lemmaId == lemmaId && s.start != null && s.end != null) return (s.start!, s.end!);
    }
    return null;
  }

  /// The Tanzil slice for [lemmaId] (a prefix or pronoun), else the whole word.
  String partFor(int lemmaId) {
    final s = spanOf(lemmaId);
    if (s == null || (s.$1 == 0 && s.$2 == text.length)) return text;
    return text.substring(s.$1, s.$2);
  }

  String get ref => '$surah:$ayah:$index';
}

/// A prefix, stem or suffix inside a [QuranWord].
class Segment {
  const Segment({required this.kind, required this.lemmaId, this.start, this.end});

  /// prefix, stem or suffix.
  final String kind;
  final int? lemmaId;

  /// Character span inside [QuranWord.text]; null where the corpus and Tanzil differ.
  final int? start;
  final int? end;
}

/// A dictionary word (or a prefix / attached pronoun) to learn.
class Lemma {
  const Lemma({
    required this.id,
    required this.key,
    required this.root,
    required this.pos,
    required this.frequency,
    required this.displayWordId,
    this.meaning,
    this.translit,
    this.note,
    this.reviewedBy,
  });

  final int id;
  final String key;

  /// Root letters, spaced (e.g. "ك ت ب"), or null for particles.
  final String? root;
  final String? pos;

  /// How many times it occurs in the Quran.
  final int frequency;

  /// The Tanzil word used to show it when no lesson word is at hand.
  final int displayWordId;
  final String? meaning;
  final String? translit;
  final String? note;
  final String? reviewedBy;

  bool get isDraft => reviewedBy == null || reviewedBy == 'DRAFT';
  bool get isAffix => key.startsWith('AFFIX|');
}

/// One lesson: metadata plus the steps from its body_json.
class Lesson {
  const Lesson({
    required this.id,
    required this.level,
    required this.ord,
    required this.title,
    required this.objective,
    required this.minutes,
    required this.anchorSurah,
    required this.anchorFrom,
    required this.anchorTo,
    required this.steps,
    required this.newLemmas,
    this.reviewedBy,
  });

  final String id;
  final int level;
  final int ord;
  final String title;
  final String objective;
  final int minutes;
  final int anchorSurah;
  final int anchorFrom;
  final int anchorTo;
  final List<LessonStep> steps;
  final List<int> newLemmas;
  final String? reviewedBy;

  bool get isDraft => reviewedBy == null || reviewedBy == 'DRAFT';

  /// A level's last lesson ends with a test.
  bool get isCheckpoint => id.endsWith('-10') || id.endsWith('-20') || id.endsWith('-30');
}

sealed class LessonStep {
  const LessonStep();

  static LessonStep fromJson(Map<String, dynamic> j) => switch (j['type']) {
    'ayah' => AyahStep(AyahRange.fromJson(j)),
    'ayah_recap' => AyahRecapStep(AyahRange.fromJson(j)),
    'words' => WordsStep((j['lemma_ids'] as List).cast<int>(), [
      for (final r in (j['word_refs'] as List? ?? const [])) WordRef.fromList(r as List),
    ]),
    'explain' => ExplainStep(j['text_bn'] as String, [
      WordRef.fromJson(j['example'] as Map<String, dynamic>),
      for (final e in (j['more_examples'] as List? ?? const []))
        WordRef.fromJson(e as Map<String, dynamic>),
    ]),
    'quiz' => QuizStep([
      for (final i in j['items'] as List) QuizItem.fromJson(i as Map<String, dynamic>),
    ]),
    'recall' => RecallStep((j['lemma_ids'] as List).cast<int>()),
    _ => throw FormatException('Unknown step ${j['type']}'),
  };
}

class AyahRange {
  const AyahRange(this.surah, this.from, this.to, {this.wordTo});

  factory AyahRange.fromJson(Map<String, dynamic> j) => AyahRange(
    j['surah'] as int,
    j['ayah'] as int,
    (j['ayah_to'] ?? j['ayah']) as int,
    wordTo: j['word_to'] as int?,
  );

  final int surah;
  final int from;
  final int to;

  /// Only the first words of the (single) ayah.
  final int? wordTo;
}

class WordRef {
  const WordRef(this.surah, this.ayah, this.index);

  factory WordRef.fromList(List r) => WordRef(r[0] as int, r[1] as int, r[2] as int);

  factory WordRef.fromJson(Map<String, dynamic> j) =>
      WordRef(j['surah'] as int, j['ayah'] as int, j['word_index'] as int);

  final int surah;
  final int ayah;
  final int index;
}

class AyahStep extends LessonStep {
  const AyahStep(this.range);
  final AyahRange range;
}

class AyahRecapStep extends LessonStep {
  const AyahRecapStep(this.range);
  final AyahRange range;
}

class WordsStep extends LessonStep {
  const WordsStep(this.lemmaIds, this.refs);
  final List<int> lemmaIds;

  /// Where each lemma is shown (same order as [lemmaIds]).
  final List<WordRef> refs;
}

class ExplainStep extends LessonStep {
  const ExplainStep(this.text, this.examples);
  final String text;
  final List<WordRef> examples;
}

class QuizStep extends LessonStep {
  const QuizStep(this.items);
  final List<QuizItem> items;
}

class RecallStep extends LessonStep {
  const RecallStep(this.lemmaIds);
  final List<int> lemmaIds;
}

class QuizItem {
  const QuizItem({
    required this.kind,
    this.lemmaId,
    this.distractors = const [],
    this.surah,
    this.ayah,
    this.wordIndex,
  });

  factory QuizItem.fromJson(Map<String, dynamic> j) => QuizItem(
    kind: j['kind'] as String,
    lemmaId: j['lemma_id'] as int?,
    distractors: (j['distractor_ids'] as List? ?? const []).cast<int>(),
    surah: j['surah'] as int?,
    ayah: j['ayah'] as int?,
    wordIndex: j['word_index'] as int?,
  );

  /// mcq_ar_bn, mcq_bn_ar, listen_choose, split, order.
  final String kind;
  final int? lemmaId;
  final List<int> distractors;
  final int? surah;
  final int? ayah;
  final int? wordIndex;
}

/// A lesson's saved state.
enum LessonStatus { locked, available, done }

class LessonProgress {
  const LessonProgress(this.status, this.bestScore, this.completedUtc);
  final LessonStatus status;
  final int? bestScore;
  final DateTime? completedUtc;
}
