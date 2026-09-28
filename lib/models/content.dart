import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'surah_names.dart';

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
const _arDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String toBanglaDigits(Object n) =>
    n.toString().replaceAllMapped(RegExp(r'\d'), (m) => _bnDigits[int.parse(m[0]!)]);

String toArabicDigits(Object n) =>
    n.toString().replaceAllMapped(RegExp(r'\d'), (m) => _arDigits[int.parse(m[0]!)]);

/// Bangla names for the hadith books used in the content list.
const _bookNamesBn = {
  'Bukhari': 'সহীহ বুখারী',
  'Muslim': 'সহীহ মুসলিম',
  'Tirmidhi': 'জামে তিরমিযী',
  'Abu Dawud': 'সুনান আবু দাউদ',
  'Ahmad': 'মুসনাদে আহমাদ',
  'Al-Adab al-Mufrad': 'আল-আদাবুল মুফরাদ',
  'Mustadrak al-Hakim': 'মুস্তাদরাকে হাকিম',
  'Ibn Majah': 'সুনান ইবনে মাজাহ',
};

/// Removes footnote markers like [১] or [2] from a translation.
String withoutFootnoteMarks(String s) =>
    s.replaceAll(RegExp(r'\s*\[[০-৯0-9]+\]'), '').replaceAll(RegExp(r'-{2,}'), '—');

enum ItemType { ayah, hadith }

class Category {
  const Category({required this.id, required this.name, this.nameEn = ''});

  final String id;
  final String name;
  final String nameEn;
}

class ContentItem {
  const ContentItem({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.category,
    required this.reference,
    required this.title,
    required this.arabic,
    required this.bangla,
    required this.note,
    required this.placeholder,
    this.subtitle = '',
    this.surah = 0,
    this.ayahStart = 0,
    this.ayahEnd = 0,
    this.fullSurah = false,
    this.gradeCheck = false,
  });

  /// A whole surah (from the mood lists).
  final bool fullSurah;

  /// The hadith's grade still needs to be checked by a scholar.
  final bool gradeCheck;

  /// Bangla surah name, e.g. "আল-বাকারা" (ayahs only).
  String get surahName => surahNameBn(surah);

  /// Bangla text without footnote markers.
  String get banglaPlain => withoutFootnoteMarks(bangla);

  /// Short one-line label for lists: reference for ayahs, book for hadiths.
  String get shortRef => title;

  /// Surah and verse numbers (ayahs only; 0 for hadiths).
  final int surah;
  final int ayahStart;
  final int ayahEnd;

  final String id;
  final ItemType type;
  final String categoryId;

  /// Bangla category / theme name.
  final String category;

  /// Reference as written in the content list, e.g. "39:53" or "Bukhari 1".
  final String reference;

  /// Reference shown to the reader, e.g. "সূরা الزمر · ৩৯:৫৩".
  final String title;

  /// Extra source line (hadith attribution and grade from HadeethEnc).
  final String subtitle;
  final String arabic;
  final String bangla;

  /// Short Bangla note: QuranEnc footnote for ayahs, HadeethEnc explanation for hadiths.
  final String note;

  /// True when some text could not be downloaded.
  final bool placeholder;

  bool get isAyah => type == ItemType.ayah;

  static ContentItem fromJson(Map<String, dynamic> j, {String basmala = ''}) {
    final type = j['type'] == 'hadith' ? ItemType.hadith : ItemType.ayah;
    if (type == ItemType.ayah) {
      final ar = (j['arabicVerses'] as List).cast<Map<String, dynamic>>();
      final bn = (j['banglaVerses'] as List).cast<Map<String, dynamic>>();
      final multi = ar.length > 1;
      var arabic = ar
          .map((v) => multi ? '${v['text']} (${toArabicDigits(v['n'])})' : '${v['text']}')
          .join(' ');
      // Tanzil puts the basmala in front of verse 1; show it on its own line.
      if (basmala.isNotEmpty && ar.first['n'] == 1 && arabic.startsWith('$basmala ')) {
        arabic = '$basmala\n${arabic.substring(basmala.length + 1)}';
      }
      final bangla = bn
          .map((v) => multi ? '(${toBanglaDigits(v['n'])}) ${v['text']}' : '${v['text']}')
          .join('\n');
      final surahAr = (j['surahNameAr'] ?? '') as String;
      final surahEn = (j['surahNameEn'] ?? '') as String;
      final refBn = (j['referenceBn'] ?? toBanglaDigits(j['reference'])) as String;
      final surahNo = (j['surah'] ?? 0) as int;
      final full = j['fullSurah'] == true;
      final bnName = surahNameBn(surahNo);
      final name = bnName.isNotEmpty
          ? 'সূরা $bnName'
          : (surahAr.isNotEmpty ? 'সূরা $surahAr' : 'সূরা');
      return ContentItem(
        id: j['id'],
        type: type,
        categoryId: j['categoryId'] ?? '',
        category: j['category'] ?? '',
        reference: j['reference'],
        title: full ? '$name (সম্পূর্ণ)' : '$name · $refBn',
        fullSurah: full,
        subtitle: surahEn,
        arabic: arabic,
        bangla: bangla,
        note: (j['note'] ?? '') as String,
        placeholder: j['placeholder'] == true,
        surah: (j['surah'] ?? 0) as int,
        ayahStart: (j['ayahStart'] ?? 0) as int,
        ayahEnd: (j['ayahEnd'] ?? 0) as int,
      );
    }
    final ref = j['reference'] as String;
    final m = RegExp(r'^(.*?)\s+(\d+)$').firstMatch(ref);
    final title = m != null && _bookNamesBn.containsKey(m[1])
        ? '${_bookNamesBn[m[1]]} ${toBanglaDigits(m[2]!)}'
        : ref;
    final attribution = (j['attribution'] ?? '') as String;
    final grade = (j['grade'] ?? '') as String;
    return ContentItem(
      id: j['id'],
      type: type,
      categoryId: j['categoryId'] ?? '',
      category: j['category'] ?? '',
      reference: ref,
      title: title,
      gradeCheck: j['gradeCheck'] == true,
      subtitle: [attribution, grade].where((s) => s.trim().isNotEmpty).join(' · '),
      arabic: j['arabic'] ?? '',
      bangla: j['bangla'] ?? '',
      note: (j['note'] ?? '') as String,
      placeholder: j['placeholder'] == true,
    );
  }
}

/// A feeling (মন) with the ayahs, full surahs and hadiths chosen for it.
class Mood {
  const Mood({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.ayahIds,
    required this.surahIds,
    required this.hadithIds,
  });

  final String id;
  final String name;
  final String nameEn;
  final List<String> ayahIds;
  final List<String> surahIds;
  final List<String> hadithIds;

  static Mood fromJson(Map<String, dynamic> j) {
    List<String> ids(String k) => ((j[k] ?? []) as List).cast<String>();
    return Mood(
      id: j['id'],
      name: j['name'],
      nameEn: j['nameEn'] ?? '',
      ayahIds: ids('ayahs'),
      surahIds: ids('surahs'),
      hadithIds: ids('hadiths'),
    );
  }
}

class ContentData {
  ContentData({
    required this.ayahCategories,
    required this.hadithThemes,
    required this.items,
    required this.meta,
    this.moods = const [],
    this.moodItems = const [],
  }) : _byId = {
         for (final i in [...items, ...moodItems]) i.id: i,
       };

  final List<Category> ayahCategories;
  final List<Category> hadithThemes;

  /// Items that belong to a topic (used for topics and the daily reminders).
  final List<ContentItem> items;
  final Map<String, dynamic> meta;
  final List<Mood> moods;

  /// Extra ayahs, surahs and hadiths that only appear in moods.
  final List<ContentItem> moodItems;
  final Map<String, ContentItem> _byId;

  ContentItem? byId(String id) => _byId[id];

  /// The items with these ids, in order (unknown ids are skipped).
  List<ContentItem> byIds(Iterable<String> ids) => [
    for (final id in ids)
      if (_byId[id] != null) _byId[id]!,
  ];

  List<ContentItem> itemsIn(String categoryId) =>
      items.where((i) => i.categoryId == categoryId).toList();

  /// Categories that actually contain items, in list order.
  List<Category> nonEmpty(List<Category> cats) =>
      cats.where((c) => items.any((i) => i.categoryId == c.id)).toList();

  String get quranEncVersion => (meta['sources']?['quranenc']?['version'] ?? '').toString();

  String get quranEncTitle => (meta['sources']?['quranenc']?['title'] ?? '').toString();

  /// Date the content was downloaded (yyyy-mm-dd).
  String get downloadedOn => (meta['generatedAt'] ?? '').toString().split('T').first;

  String get tanzilLicense => (meta['sources']?['tanzil']?['licenseHeader'] ?? '').toString();

  static ContentData fromJson(Map<String, dynamic> j) {
    final basmala = (j['meta']?['sources']?['tanzil']?['basmala'] ?? '').toString();
    List<Category> cats(String key) => ((j[key] ?? []) as List)
        .map((c) => Category(id: c['id'], name: c['name'], nameEn: c['nameEn'] ?? ''))
        .toList();
    return ContentData(
      ayahCategories: cats('ayahCategories'),
      hadithThemes: cats('hadithThemes'),
      items: ((j['items'] ?? []) as List)
          .map((e) => ContentItem.fromJson(e as Map<String, dynamic>, basmala: basmala))
          .toList(),
      meta: (j['meta'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      moods: ((j['moods'] ?? []) as List)
          .map((m) => Mood.fromJson(m as Map<String, dynamic>))
          .toList(),
      moodItems: ((j['moodItems'] ?? []) as List)
          .map((e) => ContentItem.fromJson(e as Map<String, dynamic>, basmala: basmala))
          .toList(),
    );
  }

  static Future<ContentData> load() async {
    final raw = await rootBundle.loadString('assets/content.json');
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
