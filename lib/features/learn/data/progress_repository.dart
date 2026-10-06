import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

/// The learner's own data: review cards, review log, lesson progress, settings
/// and daily activity. Kept in learn_user.db (the app had no database before).
/// Times are stored as UTC ISO strings.
class ProgressRepository {
  ProgressRepository(this.db);

  final Database db;

  static const version = 1;

  /// Version 1 = the spec's four learn_* tables plus learn_activity (local daily
  /// counts; the app has no analytics). Later versions add migrations to [_upgrade].
  static Future<ProgressRepository> open([String? path]) async {
    final p = path ?? '${await getDatabasesPath()}/learn_user.db';
    final db = await openDatabase(
      p,
      version: version,
      onCreate: (db, v) => _upgrade(db, 0, v),
      onUpgrade: _upgrade,
    );
    return ProgressRepository(db);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 1) {
      final b = db.batch()
        ..execute('''CREATE TABLE learn_card (
          lemma_id INTEGER PRIMARY KEY, source TEXT,
          fsrs_json TEXT, due_utc TEXT, created_utc TEXT)''')
        ..execute('CREATE INDEX learn_card_due ON learn_card (due_utc)')
        ..execute('''CREATE TABLE learn_review_log (
          id INTEGER PRIMARY KEY, lemma_id INTEGER, rating INTEGER,
          reviewed_utc TEXT, elapsed_ms INTEGER, kind TEXT)''')
        ..execute('''CREATE TABLE learn_lesson_progress (
          lesson_id TEXT PRIMARY KEY, status TEXT,
          best_score INTEGER, completed_utc TEXT)''')
        ..execute('CREATE TABLE learn_settings (key TEXT PRIMARY KEY, value TEXT)')
        ..execute('''CREATE TABLE learn_activity (
          day TEXT PRIMARY KEY, seconds INTEGER DEFAULT 0, reviews INTEGER DEFAULT 0,
          lessons INTEGER DEFAULT 0, words_added INTEGER DEFAULT 0, ayah_taps INTEGER DEFAULT 0,
          error_reports INTEGER DEFAULT 0)''');
      await b.commit(noResult: true);
    }
  }

  // ------------------------------------------------------------ cards

  Future<Map<String, Object?>?> card(int lemmaId) async {
    final r = await db.query('learn_card', where: 'lemma_id = ?', whereArgs: [lemmaId]);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, Object?>>> cards() => db.query('learn_card');

  Future<List<Map<String, Object?>>> dueCards(String nowUtc, int limit) => db.query(
    'learn_card',
    where: 'due_utc <= ?',
    whereArgs: [nowUtc],
    orderBy: 'due_utc',
    limit: limit,
  );

  Future<int> dueCount(String nowUtc) async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM learn_card WHERE due_utc <= ?', [nowUtc]),
      ) ??
      0;

  Future<void> saveCard({
    required int lemmaId,
    required String source,
    required String fsrsJson,
    required String dueUtc,
    required String createdUtc,
  }) => db.insert('learn_card', {
    'lemma_id': lemmaId,
    'source': source,
    'fsrs_json': fsrsJson,
    'due_utc': dueUtc,
    'created_utc': createdUtc,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> addLog(int lemmaId, int rating, String reviewedUtc, int? elapsedMs, String kind) =>
      db.insert('learn_review_log', {
        'lemma_id': lemmaId,
        'rating': rating,
        'reviewed_utc': reviewedUtc,
        'elapsed_ms': elapsedMs,
        'kind': kind,
      });

  /// Reviews (kind = review) since [fromUtc].
  Future<int> reviewsSince(String fromUtc) async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM learn_review_log WHERE kind = 'review' AND reviewed_utc >= ?",
          [fromUtc],
        ),
      ) ??
      0;

  // ------------------------------------------------------------ lessons

  Future<Map<String, LessonProgress>> lessonProgress() async => {
    for (final r in await db.query('learn_lesson_progress'))
      r['lesson_id'] as String: LessonProgress(
        LessonStatus.values.byName(r['status'] as String),
        r['best_score'] as int?,
        r['completed_utc'] == null ? null : DateTime.parse(r['completed_utc'] as String),
      ),
  };

  Future<void> saveLesson(String id, LessonStatus status, int? bestScore, String? completedUtc) =>
      db.insert('learn_lesson_progress', {
        'lesson_id': id,
        'status': status.name,
        'best_score': bestScore,
        'completed_utc': completedUtc,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ------------------------------------------------------------ settings

  Future<Map<String, String>> settings() async => {
    for (final r in await db.query('learn_settings')) r['key'] as String: r['value'] as String,
  };

  Future<void> setSetting(String key, String value) => db.insert('learn_settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ------------------------------------------------------------ activity

  /// Adds to today's local counts ([day] = yyyy-mm-dd, local date).
  Future<void> addActivity(
    String day, {
    int seconds = 0,
    int reviews = 0,
    int lessons = 0,
    int wordsAdded = 0,
    int ayahTaps = 0,
    int errorReports = 0,
  }) async {
    await db.rawInsert('INSERT OR IGNORE INTO learn_activity (day) VALUES (?)', [day]);
    await db.rawUpdate(
      'UPDATE learn_activity SET seconds = seconds + ?, reviews = reviews + ?, '
      'lessons = lessons + ?, words_added = words_added + ?, ayah_taps = ayah_taps + ?, '
      'error_reports = error_reports + ? WHERE day = ?',
      [seconds, reviews, lessons, wordsAdded, ayahTaps, errorReports, day],
    );
  }

  /// Days with any learning (a lesson, a review or a new word), newest first.
  Future<List<String>> activeDays() async => [
    for (final r in await db.query(
      'learn_activity',
      columns: ['day'],
      where: 'reviews > 0 OR lessons > 0 OR words_added > 0',
      orderBy: 'day DESC',
    ))
      r['day'] as String,
  ];
}
