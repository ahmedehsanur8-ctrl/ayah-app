import 'package:flutter/foundation.dart';

import '../../../app_state.dart';
import '../data/content_repository.dart';
import '../data/progress_repository.dart';
import '../domain/models.dart';
import '../srs/srs_service.dart';

/// কুরআন বুঝি state, in the app's usual style: one ChangeNotifier singleton that
/// screens listen to with ListenableBuilder. The databases open on first use.
class Learn extends ChangeNotifier {
  Learn._();

  static final instance = Learn._();

  ContentRepository? content;
  ProgressRepository? progress;
  SrsService? srs;
  Future<void>? _opening;

  bool get ready => content != null && progress != null;

  List<Lesson> lessons = const [];
  Map<String, LessonProgress> lessonProgress = const {};

  /// Lemmas the learner has in review (learned in a lesson or added with শিখব).
  Set<int> known = const {};
  Map<String, String> settings = const {};
  SrsStats stats = const SrsStats(cards: 0, retained: 0, due: 0, reviewedToday: 0);
  int streak = 0;
  List<String> activeDays = const [];

  Future<void> ensureReady() => _opening ??= _open();

  Future<void> _open() async {
    final c = await ContentRepository.openBundled();
    final p = await ProgressRepository.open();
    await _attach(c, p, SrsService(p));
  }

  /// Uses the given stores (tests).
  @visibleForTesting
  Future<void> attachForTests(
    ContentRepository c,
    ProgressRepository p, {
    DateTime Function()? clock,
  }) {
    _opening = Future.value();
    return _attach(c, p, SrsService(p, clock: clock));
  }

  Future<void> _attach(ContentRepository c, ProgressRepository p, SrsService s) async {
    content = c;
    progress = p;
    srs = s;
    lessons = await c.lessons();
    await refresh();
  }

  DateTime _now() => srs?.nowUtc.toLocal() ?? DateTime.now();

  static String dayKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';

  String get today => dayKey(_now());

  Future<void> refresh() async {
    final p = progress!;
    lessonProgress = await p.lessonProgress();
    known = {for (final r in await p.cards()) r['lemma_id'] as int};
    settings = await p.settings();
    stats = await srs!.stats();
    activeDays = await p.activeDays();
    streak = computeStreak(activeDays, _now());
    notifyListeners();
  }

  /// Days in a row with learning, counting back from today. One missed day in
  /// any 7 is forgiven (a free rest day), and today not done yet does not break it.
  static int computeStreak(List<String> days, DateTime now) {
    final set = days.toSet();
    var d = DateTime(now.year, now.month, now.day);
    if (!set.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var count = 0;
    DateTime? lastRest;
    for (var i = 0; i < 3650; i++) {
      if (set.contains(dayKey(d))) {
        count++;
      } else {
        final restOk = lastRest == null || lastRest.difference(d).inDays >= 7;
        final dayBefore = d.subtract(const Duration(days: 1));
        if (count > 0 && restOk && set.contains(dayKey(dayBefore))) {
          lastRest = d;
        } else {
          break;
        }
      }
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  // ------------------------------------------------------------ lessons

  LessonStatus statusOf(Lesson l) {
    final p = lessonProgress[l.id];
    if (p?.status == LessonStatus.done) return LessonStatus.done;
    final i = lessons.indexOf(l);
    if (i <= 0) return LessonStatus.available;
    return lessonProgress[lessons[i - 1].id]?.status == LessonStatus.done
        ? LessonStatus.available
        : LessonStatus.locked;
  }

  /// The first lesson not done yet (null when all are done).
  Lesson? get nextLesson {
    for (final l in lessons) {
      if (statusOf(l) != LessonStatus.done) return l;
    }
    return null;
  }

  int get lessonsDone => lessons.where((l) => statusOf(l) == LessonStatus.done).length;

  bool levelDone(int level) {
    final ls = lessons.where((l) => l.level == level);
    return ls.isNotEmpty && ls.every((l) => statusOf(l) == LessonStatus.done);
  }

  /// Saves a finished lesson: its words enter review with the ratings from the
  /// recall step, the next lesson opens, and learning mode turns on after the
  /// first lesson (unless the learner switched it off before).
  Future<void> completeLesson(
    Lesson lesson,
    int score,
    Map<int, Rating> ratings, {
    int seconds = 0,
  }) async {
    final p = progress!;
    for (final e in ratings.entries) {
      await srs!.addCard(e.key, 'lesson');
      await srs!.review(e.key, e.value, kind: 'lesson');
    }
    final old = lessonProgress[lesson.id];
    final best = old?.bestScore == null || score > old!.bestScore! ? score : old.bestScore;
    await p.saveLesson(lesson.id, LessonStatus.done, best, srs!.nowUtc.toIso8601String());
    await p.addActivity(today, seconds: seconds, lessons: 1, wordsAdded: ratings.length);
    if (!settings.containsKey('learning_mode_on')) {
      await p.setSetting('learning_mode_on', '1');
      await _mirrorLearningMode(true);
    }
    await refresh();
  }

  // ------------------------------------------------------------ words

  bool isKnown(QuranWord w) => w.lemmaId != null && known.contains(w.lemmaId);

  /// শিখব: adds a word to review. Returns false if it was already there.
  Future<bool> addWord(int lemmaId, {String source = 'ayah_tap'}) async {
    final added = await srs!.addCard(lemmaId, source);
    if (added) await progress!.addActivity(today, wordsAdded: 1);
    await refresh();
    return added;
  }

  Future<void> reviewWord(int lemmaId, Rating rating, {int? elapsedMs}) async {
    await srs!.review(lemmaId, rating, elapsedMs: elapsedMs);
    await progress!.addActivity(today, reviews: 1, seconds: ((elapsedMs ?? 0) / 1000).round());
  }

  Future<void> countAyahTap() => progress!.addActivity(today, ayahTaps: 1);
  Future<void> countErrorReport() => progress!.addActivity(today, errorReports: 1);

  // ------------------------------------------------------------ settings

  /// Underline and tint known words in the reminder ayah. Default off; turned on
  /// after Lesson 1.
  bool get learningMode => settings['learning_mode_on'] == '1';

  /// Minutes a day: 5, 10 or 15.
  int get dailyGoal => int.tryParse(settings['daily_goal_min'] ?? '') ?? 10;

  /// Bangla pronunciation on tap (Level 1 only).
  bool get showTranslit => settings['show_translit'] != '0';

  Future<void> setSetting(String key, String value) async {
    await progress!.setSetting(key, value);
    await refresh();
  }

  Future<void> setLearningMode(bool on) async {
    await _mirrorLearningMode(on);
    await setSetting('learning_mode_on', on ? '1' : '0');
  }

  /// Keeps the quick copy in the app settings in step (see AppSettings.learnModeOn).
  static Future<void> _mirrorLearningMode(bool on) async {
    try {
      await AppState.instance.settings.setLearnModeOn(on);
    } catch (_) {
      // AppState not loaded (some tests).
    }
  }

  Future<void> setDailyGoal(int min) => setSetting('daily_goal_min', '$min');
  Future<void> setShowTranslit(bool on) => setSetting('show_translit', on ? '1' : '0');

  // ------------------------------------------------------------ coverage

  /// Share (0–1) of the words in surahs [from]–[to] whose main word is known.
  Future<double> coverage(int from, int to) async {
    final ids = await content!.stemLemmas(from, to);
    if (ids.isEmpty) return 0;
    return ids.where(known.contains).length / ids.length;
  }
}
