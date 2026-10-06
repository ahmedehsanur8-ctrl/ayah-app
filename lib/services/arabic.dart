import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import 'audio.dart';
import 'settings.dart';

/// One thing to learn: a letter, a letter with a mark, a Quran word, a stop sign.
@immutable
class ArItem {
  ArItem(this.id, Map<String, dynamic> j)
    : ar = j['ar'] as String,
      bn = (j['bn'] ?? '') as String,
      name = j['name'] as String?,
      tip = j['tip'] as String?,
      meaning = j['meaning'] as String?,
      ref = j['ref'] as String?,
      note = j['note'] as String?,
      kind = (j['kind'] ?? '') as String,
      audio = j['audio'] as String?;

  final String id;
  final String ar;

  /// How it sounds, in Bangla letters.
  final String bn;
  final String? name;
  final String? tip;
  final String? meaning;

  /// surah:ayah of a Quran word.
  final String? ref;
  final String? note;
  final String kind;

  /// File name in assets/arabic_audio/.
  final String? audio;

  /// Text for a match game column.
  String field(String key) => switch (key) {
    'name' => name ?? bn,
    'meaning' => meaning ?? '',
    'note' => note ?? '',
    'form:med' => 'ـ$arـ',
    _ => bn,
  };
}

@immutable
class ArLevel {
  const ArLevel(this.n, this.title, this.subtitle, this.ready);

  final int n;
  final String title;
  final String subtitle;
  final bool ready;
}

@immutable
class ArLesson {
  ArLesson(Map<String, dynamic> j)
    : id = j['id'] as String,
      n = j['n'] as int,
      title = j['title'] as String,
      subtitle = j['subtitle'] as String,
      minutes = j['minutes'] as int,
      intro = (j['intro'] as List).cast<String>(),
      cards = (j['cards'] as List).cast<String>(),
      games = (j['games'] as List).cast<Map<String, dynamic>>(),
      extra = (j['extra'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      ayahs = ((j['ayahs'] ?? const []) as List).cast<String>();

  final String id;
  final int n;
  final String title;
  final String subtitle;
  final int minutes;
  final List<String> intro;
  final List<String> cards;
  final List<Map<String, dynamic>> games;
  final Map<String, dynamic> extra;

  /// surah:ayah refs for the surah lessons.
  final List<String> ayahs;
}

/// সহজ আরবি lessons, loaded once from assets/arabic/level1.json.
class ArabicCourse {
  ArabicCourse._();

  static List<ArLevel> levels = const [];
  static Map<String, ArItem> items = const {};
  static List<ArLesson> lessons = const [];
  static Future<void>? _loading;

  static bool get loaded => lessons.isNotEmpty;

  static Future<void> load() => loaded ? Future.value() : (_loading ??= _load());

  static Future<void> _load() async {
    try {
      final j = jsonDecode(
        await rootBundle.loadString('assets/arabic/level1.json'),
      ) as Map<String, dynamic>;
      levels = [
        for (final l in (j['levels'] as List).cast<Map<String, dynamic>>())
          ArLevel(l['n'] as int, l['title'] as String, l['subtitle'] as String, l['ready'] as bool),
      ];
      items = {
        for (final e in (j['items'] as Map<String, dynamic>).entries)
          e.key: ArItem(e.key, e.value as Map<String, dynamic>),
      };
      lessons = [for (final l in (j['lessons'] as List).cast<Map<String, dynamic>>()) ArLesson(l)];
      await ArabicAudio.load();
      await ArabicProgress.instance.load();
    } catch (e) {
      debugPrint('arabic: $e');
      _loading = null;
    }
  }

  static ArItem? item(String id) => items[id];

  static int indexOf(String lessonId) => lessons.indexWhere((l) => l.id == lessonId);
}

/// Qari recordings in assets/arabic_audio/. Only existing files are played;
/// there is no synthetic voice for Arabic.
class ArabicAudio {
  ArabicAudio._();

  static Set<String> _files = {};

  static Future<void> load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _files = {
        for (final a in manifest.listAssets())
          if (a.startsWith('assets/arabic_audio/') && a.endsWith('.mp3'))
            a.substring('assets/arabic_audio/'.length),
      };
    } catch (_) {
      _files = {};
    }
  }

  /// For tests.
  @visibleForTesting
  static set files(Set<String> f) => _files = f;

  static bool has(ArItem i) => i.audio != null && _files.contains(i.audio);

  static Future<void> play(ArItem i) async {
    if (!has(i)) return;
    await AudioController.instance.playClip(
      'ar-${i.id}',
      AudioSource.asset(
        'assets/arabic_audio/${i.audio}',
        tag: AudioController.mediaItem('ar-${i.id}', i.ar, 'সহজ আরবি'),
      ),
    );
  }

  /// A Quran ayah from the chosen reciter (EveryAyah.com, cached after the first time).
  static Future<void> playAyah(String ref) async {
    final parts = ref.split(':');
    final s = int.parse(parts[0]), a = int.parse(parts[1]);
    final reciter = Reciter.byId(AppState.instance.settings.reciterId);
    await AudioController.instance.playClip(
      'ar-ayah-$ref',
      // ignore: experimental_member_use
      LockCachingAudioSource(
        AudioController.ayahUrl(reciter.id, s, a),
        tag: AudioController.mediaItem('ar-ayah-$ref', 'আয়াত $ref', reciter.name),
      ),
    );
  }

  static Future<void> stop() => AudioController.instance.stop();
}

/// Stars, the daily streak and the review list, saved on the phone only.
class ArabicProgress extends ChangeNotifier {
  ArabicProgress._();

  static final instance = ArabicProgress._();

  /// Days until a word comes back, by how often it was answered right.
  static const intervals = [1, 2, 4, 7, 15];

  SharedPreferences? _p;

  Future<void> load() async => _p ??= await SharedPreferences.getInstance();

  /// For tests, after the preferences were replaced.
  @visibleForTesting
  Future<void> reload() async {
    _p = await SharedPreferences.getInstance();
    notifyListeners();
  }

  /// "সঠিক দিক অনুসরণ করুন" in লিখে দেখুন: also check the start point and
  /// the writing direction (off by default).
  bool get traceStrict => _p?.getBool('ar.traceStrict') ?? false;

  Future<void> setTraceStrict(bool v) async {
    await load();
    await _p!.setBool('ar.traceStrict', v);
    notifyListeners();
  }

  static int dayNumber(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  Map<String, int> get _stars {
    final raw = _p?.getString('ar.stars');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
  }

  int starsOf(String lessonId) => _stars[lessonId] ?? 0;

  bool isDone(String lessonId) => starsOf(lessonId) > 0;

  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  int get doneCount => ArabicCourse.lessons.where((l) => isDone(l.id)).length;

  /// Lessons open one by one; a finished lesson can always be repeated.
  bool isUnlocked(int index) => index <= 0 || isDone(ArabicCourse.lessons[index - 1].id);

  /// The first lesson not yet finished (or the last one).
  int get nextIndex {
    final i = ArabicCourse.lessons.indexWhere((l) => !isDone(l.id));
    return i < 0 ? ArabicCourse.lessons.length - 1 : i;
  }

  /// 3 stars with at most 2 mistakes, 2 with at most 6, else 1.
  static int starsFor(int mistakes) => mistakes <= 2 ? 3 : (mistakes <= 6 ? 2 : 1);

  Future<void> finishLesson(String lessonId, int stars, {DateTime? now}) async {
    final s = _stars;
    s[lessonId] = math.max(s[lessonId] ?? 0, stars);
    await _p?.setString('ar.stars', jsonEncode(s));
    await practiced(now: now);
  }

  // ------------------------------------------------------------ streak

  /// Days in a row with at least one finished lesson or review.
  int streak({DateTime? now}) {
    final last = _p?.getInt('ar.lastDay');
    if (last == null) return 0;
    final today = dayNumber(now ?? DateTime.now());
    return today - last <= 1 ? (_p?.getInt('ar.streak') ?? 0) : 0;
  }

  bool practicedToday({DateTime? now}) =>
      _p?.getInt('ar.lastDay') == dayNumber(now ?? DateTime.now());

  Future<void> practiced({DateTime? now}) async {
    final today = dayNumber(now ?? DateTime.now());
    final last = _p?.getInt('ar.lastDay');
    if (last != today) {
      final s = (last != null && today - last == 1) ? (_p?.getInt('ar.streak') ?? 0) + 1 : 1;
      await _p?.setInt('ar.streak', s);
      await _p?.setInt('ar.lastDay', today);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ review

  /// item id -> [box, due day]
  Map<String, List<int>> get _review {
    final raw = _p?.getString('ar.review');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List).cast<int>()),
    );
  }

  Future<void> _saveReview(Map<String, List<int>> r) async {
    await _p?.setString('ar.review', jsonEncode(r));
    notifyListeners();
  }

  /// Answered wrong: comes back tomorrow, starting again at the first box.
  Future<void> markWrong(Iterable<String> ids, {DateTime? now}) async {
    if (ids.isEmpty) return;
    final today = dayNumber(now ?? DateTime.now());
    final r = _review;
    for (final id in ids) {
      if (ArabicCourse.items.containsKey(id)) r[id] = [0, today + intervals[0]];
    }
    await _saveReview(r);
  }

  /// Answered right in a review: comes back later and later, then leaves the list.
  Future<void> markRight(Iterable<String> ids, {DateTime? now}) async {
    final today = dayNumber(now ?? DateTime.now());
    final r = _review;
    var changed = false;
    for (final id in ids) {
      final e = r[id];
      if (e == null) continue;
      changed = true;
      final box = e[0] + 1;
      if (box >= intervals.length) {
        r.remove(id);
      } else {
        r[id] = [box, today + intervals[box]];
      }
    }
    if (changed) await _saveReview(r);
  }

  List<String> dueItems({DateTime? now}) {
    final today = dayNumber(now ?? DateTime.now());
    final r = _review.entries.where((e) => e.value[1] <= today).toList()
      ..sort((a, b) => a.value[1].compareTo(b.value[1]));
    return [for (final e in r) e.key];
  }

  int get reviewCount => _review.length;
}
