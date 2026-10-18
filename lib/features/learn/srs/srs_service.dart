import 'dart:convert';

import 'package:fsrs/fsrs.dart' as fsrs;

import '../data/progress_repository.dart';

export 'package:fsrs/fsrs.dart' show Rating;

/// Spaced repetition with FSRS (package:fsrs, MIT): default parameters, desired
/// retention 0.90, all times UTC, at most [dailyCap] reviews a day, most overdue first.
class SrsService {
  SrsService(this.progress, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ProgressRepository progress;
  final DateTime Function() _clock;
  final scheduler = fsrs.Scheduler(desiredRetention: 0.9);

  static const dailyCap = 30;

  DateTime get nowUtc => _clock().toUtc();

  /// Start of the learner's local day, in UTC (the daily cap resets at local midnight).
  DateTime get _dayStartUtc {
    final l = _clock().toLocal();
    return DateTime(l.year, l.month, l.day).toUtc();
  }

  /// Adds a new card for [lemmaId] (due now). Does nothing if it already exists.
  /// [source] is 'lesson' or 'ayah_tap'. Returns true if a card was added.
  Future<bool> addCard(int lemmaId, String source) async {
    if (await progress.card(lemmaId) != null) return false;
    final now = nowUtc;
    final card = fsrs.Card(cardId: lemmaId, due: now);
    await progress.saveCard(
      lemmaId: lemmaId,
      source: source,
      fsrsJson: jsonEncode(card.toMap()),
      dueUtc: card.due.toIso8601String(),
      createdUtc: now.toIso8601String(),
    );
    return true;
  }

  Future<bool> hasCard(int lemmaId) async => await progress.card(lemmaId) != null;

  /// Due cards for today's review: most overdue first, within what is left of
  /// today's cap.
  Future<List<int>> dueCards({int limit = dailyCap}) async {
    final left = dailyCap - await reviewedToday();
    if (left <= 0) return const [];
    final rows = await progress.dueCards(nowUtc.toIso8601String(), limit < left ? limit : left);
    return [for (final r in rows) r['lemma_id'] as int];
  }

  Future<int> reviewedToday() => progress.reviewsSince(_dayStartUtc.toIso8601String());

  /// How many cards are due now (not capped).
  Future<int> dueCount() => progress.dueCount(nowUtc.toIso8601String());

  /// Rates a card. [kind] is 'review' (daily review, counts toward the cap) or
  /// 'lesson' (the recall step of a lesson).
  Future<DateTime> review(
    int lemmaId,
    fsrs.Rating rating, {
    int? elapsedMs,
    String kind = 'review',
  }) async {
    final row = await progress.card(lemmaId);
    if (row == null) throw StateError('No card for $lemmaId');
    final card = fsrs.Card.fromMap(_decode(row['fsrs_json'] as String));
    final now = nowUtc;
    final r = scheduler.reviewCard(card, rating, reviewDateTime: now, reviewDuration: elapsedMs);
    await progress.saveCard(
      lemmaId: lemmaId,
      source: row['source'] as String,
      fsrsJson: jsonEncode(r.card.toMap()),
      dueUtc: r.card.due.toUtc().toIso8601String(),
      createdUtc: row['created_utc'] as String,
    );
    await progress.addLog(lemmaId, rating.value, now.toIso8601String(), elapsedMs, kind);
    return r.card.due;
  }

  /// fsrs stores doubles; JSON may bring back whole numbers as int.
  static Map<String, dynamic> _decode(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    for (final k in ['stability', 'difficulty']) {
      if (m[k] is int) m[k] = (m[k] as int).toDouble();
    }
    return m;
  }

  Future<SrsStats> stats() async {
    final rows = await progress.cards();
    var retained = 0;
    for (final r in rows) {
      final c = fsrs.Card.fromMap(_decode(r['fsrs_json'] as String));
      if ((c.stability ?? 0) >= 21) retained++;
    }
    return SrsStats(
      cards: rows.length,
      retained: retained,
      due: await dueCount(),
      reviewedToday: await reviewedToday(),
    );
  }
}

class SrsStats {
  const SrsStats({
    required this.cards,
    required this.retained,
    required this.due,
    required this.reviewedToday,
  });

  /// Words in review (= words the learner knows or is learning).
  final int cards;

  /// Cards with stability of at least 21 days.
  final int retained;
  final int due;
  final int reviewedToday;

  /// What is left for today's review, within the daily cap.
  int get todayLeft {
    final left = SrsService.dailyCap - reviewedToday;
    return due < left ? due : (left < 0 ? 0 : left);
  }
}
