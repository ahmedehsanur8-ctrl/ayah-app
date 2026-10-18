import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

/// The bundled, read-only content DB (assets/learn/learn_content.db): Tanzil words,
/// corpus grammar, lemmas, Bangla meanings and lessons.
class ContentRepository {
  ContentRepository(this.db);

  final Database db;

  static const asset = 'assets/learn/learn_content.db';

  /// Copies the asset to the app folder once per app build (so an app update
  /// replaces it) and opens it read-only.
  static Future<ContentRepository> openBundled() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/learn');
    await dir.create(recursive: true);
    final build = (await PackageInfo.fromPlatform()).buildNumber;
    final file = File('${dir.path}/learn_content_$build.db');
    if (!await file.exists()) {
      final data = await rootBundle.load(asset);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      await tmp.rename(file.path);
      await for (final f in dir.list()) {
        if (f is File && f.path != file.path && f.path.endsWith('.db')) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }
    return ContentRepository(await openDatabase(file.path, readOnly: true));
  }

  final _lemmaCache = <int, Lemma>{};
  final _wordCache = <int, QuranWord>{};
  List<Lesson>? _lessons;

  Future<Map<String, String>> meta() async => {
    for (final r in await db.query('meta')) r['key'] as String: (r['value'] ?? '') as String,
  };

  // ------------------------------------------------------------ lessons

  Future<List<Lesson>> lessons() async {
    if (_lessons != null) return _lessons!;
    final meta = await this.meta();
    final rows = await db.query('lesson', orderBy: 'ord');
    final links = await db.query('lesson_lemma', orderBy: 'lesson_id, ord');
    final news = <String, List<int>>{};
    for (final l in links) {
      news.putIfAbsent(l['lesson_id'] as String, () => []).add(l['lemma_id'] as int);
    }
    return _lessons = [
      for (final r in rows)
        Lesson(
          id: r['id'] as String,
          level: r['level'] as int,
          ord: r['ord'] as int,
          title: r['title_bn'] as String,
          objective: r['objective_bn'] as String,
          minutes: r['minutes'] as int,
          anchorSurah: r['anchor_surah'] as int,
          anchorFrom: r['anchor_ayah_from'] as int,
          anchorTo: r['anchor_ayah_to'] as int,
          steps: [
            for (final s in (jsonDecode(r['body_json'] as String)['steps'] as List))
              LessonStep.fromJson(s as Map<String, dynamic>),
          ],
          newLemmas: news[r['id']] ?? const [],
          reviewedBy: meta['lesson_reviewed_by:${r['id']}'],
        ),
    ];
  }

  // ------------------------------------------------------------ lemmas

  Lemma _lemma(Map<String, Object?> r) => Lemma(
    id: r['id'] as int,
    key: r['lemma_key'] as String,
    root: r['root'] as String?,
    pos: r['pos'] as String?,
    frequency: r['frequency'] as int,
    displayWordId: r['display_word_id'] as int,
    meaning: r['meaning_bn'] as String?,
    translit: r['translit_bn'] as String?,
    note: r['note_bn'] as String?,
    reviewedBy: r['reviewed_by'] as String?,
  );

  Future<Map<int, Lemma>> lemmas(Iterable<int> ids) async {
    final want = ids.toSet()..removeAll(_lemmaCache.keys);
    if (want.isNotEmpty) {
      final rows = await db.query(
        'lemma',
        where: 'id IN (${List.filled(want.length, '?').join(',')})',
        whereArgs: want.toList(),
      );
      for (final r in rows) {
        final l = _lemma(r);
        _lemmaCache[l.id] = l;
      }
    }
    return {
      for (final i in ids)
        if (_lemmaCache[i] != null) i: _lemmaCache[i]!,
    };
  }

  Future<Lemma?> lemma(int id) async => (await lemmas([id]))[id];

  /// Lemmas that have a Bangla meaning (the curriculum and any authored extras).
  Future<List<Lemma>> authoredLemmas() async {
    final rows = await db.query('lemma', where: 'meaning_bn IS NOT NULL');
    return [for (final r in rows) _lemmaCache[r['id'] as int] = _lemma(r)];
  }

  /// Up to [limit] other lemmas from the same root, most frequent first.
  Future<List<Lemma>> sameRoot(String root, int exceptId, {int limit = 3}) async {
    final rows = await db.query(
      'lemma',
      where: 'root = ? AND id != ? AND lemma_key NOT LIKE ?',
      whereArgs: [root, exceptId, 'AFFIX|%'],
      orderBy: 'frequency DESC',
      limit: limit,
    );
    return [for (final r in rows) _lemmaCache[r['id'] as int] = _lemma(r)];
  }

  /// The short Bangla idea of a root ("লেখা"), if written.
  Future<({String meaning, bool draft})?> rootIdea(String root) async {
    final r = await db.query('root_info', where: 'root = ?', whereArgs: [root]);
    if (r.isEmpty) return null;
    return (
      meaning: r.first['meaning_bn'] as String,
      draft: (r.first['reviewed_by'] ?? 'DRAFT') == 'DRAFT',
    );
  }

  // ------------------------------------------------------------ words

  QuranWord _word(Map<String, Object?> r) => QuranWord(
    id: r['id'] as int,
    surah: r['surah'] as int,
    ayah: r['ayah'] as int,
    index: r['word_index'] as int,
    text: r['text_uthmani'] as String,
    lemmaId: r['lemma_id'] as int?,
    root: r['root'] as String?,
    pos: r['pos'] as String?,
  );

  Future<List<QuranWord>> _withSegments(List<QuranWord> words) async {
    if (words.isEmpty) return words;
    final ids = words.map((w) => w.id).toList();
    final rows = await db.query(
      'word_segment',
      where: 'word_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'word_id, seg_index',
    );
    final segs = <int, List<Segment>>{};
    for (final r in rows) {
      segs
          .putIfAbsent(r['word_id'] as int, () => [])
          .add(
            Segment(
              kind: r['kind'] as String,
              lemmaId: r['lemma_id'] as int?,
              start: r['char_start'] as int?,
              end: r['char_end'] as int?,
            ),
          );
    }
    return [for (final w in words) _wordCache[w.id] = w.withSegments(segs[w.id] ?? const [])];
  }

  /// The words of an ayah range (optionally only the first [wordTo] words of one ayah).
  Future<List<QuranWord>> ayahWords(int surah, int from, [int? to, int? wordTo]) async {
    final rows = await db.query(
      'quran_word',
      where: 'surah = ? AND ayah BETWEEN ? AND ?',
      whereArgs: [surah, from, to ?? from],
      orderBy: 'id',
    );
    var words = [for (final r in rows) _word(r)];
    if (wordTo != null) words = words.where((w) => w.index <= wordTo).toList();
    return _withSegments(words);
  }

  Future<QuranWord?> word(int surah, int ayah, int index) async {
    final rows = await db.query(
      'quran_word',
      where: 'surah = ? AND ayah = ? AND word_index = ?',
      whereArgs: [surah, ayah, index],
    );
    if (rows.isEmpty) return null;
    return (await _withSegments([_word(rows.first)])).first;
  }

  Future<Map<int, QuranWord>> wordsById(Iterable<int> ids) async {
    final want = ids.toSet()..removeAll(_wordCache.keys);
    if (want.isNotEmpty) {
      final rows = await db.query(
        'quran_word',
        where: 'id IN (${List.filled(want.length, '?').join(',')})',
        whereArgs: want.toList(),
      );
      await _withSegments([for (final r in rows) _word(r)]);
    }
    return {
      for (final i in ids)
        if (_wordCache[i] != null) i: _wordCache[i]!,
    };
  }

  /// Number of ayahs in a surah (from the words).
  Future<int> ayahCount(int surah) async =>
      (await db.rawQuery('SELECT MAX(ayah) AS n FROM quran_word WHERE surah = ?', [
            surah,
          ])).first['n']
          as int? ??
      0;

  final _rangeLemmas = <String, List<int>>{};

  /// The stem lemma of every word from [fromSurah] to [toSurah] (for coverage).
  Future<List<int>> stemLemmas(int fromSurah, int toSurah) async {
    final k = '$fromSurah-$toSurah';
    return _rangeLemmas[k] ??= [
      for (final r in await db.query(
        'quran_word',
        columns: ['lemma_id'],
        where: 'surah BETWEEN ? AND ? AND lemma_id IS NOT NULL',
        whereArgs: [fromSurah, toSurah],
      ))
        r['lemma_id'] as int,
    ];
  }
}
