import '../models/content.dart';

/// Picks which ayah / hadith belongs to a given day.
///
/// Each day moves to the next category, so the same theme never appears two
/// days in a row. Within a category, the items take turns.
class Rotation {
  Rotation(this.data)
    : _ayahCats = data.nonEmpty(data.ayahCategories),
      _hadithCats = data.nonEmpty(data.hadithThemes);

  final ContentData data;
  final List<Category> _ayahCats;
  final List<Category> _hadithCats;

  static final _epoch = DateTime.utc(2024, 1, 1);

  /// Day number of a calendar date (only year/month/day are used).
  static int dayNumber(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).difference(_epoch).inDays;

  bool get hasHadith => _hadithCats.isNotEmpty;

  ContentItem? _pick(List<Category> cats, int d) {
    if (cats.isEmpty) return null;
    final n = cats.length;
    final cat = cats[d % n];
    final items = data.itemsIn(cat.id);
    return items[(d ~/ n) % items.length];
  }

  /// The morning ayah for day [day].
  ContentItem? morning(int day) => _pick(_ayahCats, day);

  /// The night item: a hadith, or an ayah from a different category than
  /// the morning one when hadith is turned off (or none are available).
  ContentItem? night(int day, {required bool hadith}) {
    if (hadith && hasHadith) return _pick(_hadithCats, day);
    return _pick(_ayahCats, day + _ayahCats.length ~/ 2);
  }

  /// A hadith for day [day] (used on the home screen).
  ContentItem? hadithFor(int day) => _pick(_hadithCats, day);
}
