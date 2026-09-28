import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/content.dart';
import '../models/quran_names.dart';
import '../models/surah_names.dart';

/// One of the 114 surahs.
class Surah {
  const Surah({
    required this.n,
    required this.start,
    required this.ayahCount,
    required this.nameAr,
    required this.nameTr,
    required this.nameEn,
    required this.meccan,
  });

  final int n;

  /// Index of its first ayah among all 6236.
  final int start;
  final int ayahCount;
  final String nameAr;

  /// Transliteration, e.g. "Al-Baqara".
  final String nameTr;

  /// English meaning, e.g. "The Cow".
  final String nameEn;
  final bool meccan;

  String get nameBn => surahNameBn(n);
  String get meaningBn => n >= 1 && n <= surahMeaningsBn.length ? surahMeaningsBn[n - 1] : '';
  String get typeBn => meccan ? 'মাক্কী' : 'মাদানী';

  /// Surah 1's basmala is its first ayah; surah 9 has none.
  bool get hasSeparateBasmala => n != 1 && n != 9;
}

/// One of the 30 paras (juz).
class Juz {
  const Juz(this.n, this.surah, this.ayah);

  final int n;
  final int surah;
  final int ayah;

  String get nameAr => juzNamesAr[n - 1];
}

/// A Bangla translation: who made it and where it comes from.
class TranslationInfo {
  const TranslationInfo(this.j);

  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get name => (j['name'] ?? '') as String;
  String get nameEn => (j['nameEn'] ?? '') as String;
  bool get bundled => j['bundled'] == true;

  /// "QuranEnc.com" or "Tanzil.net".
  String get publisher => (j['publisher'] ?? '') as String;
  String get url => (j['url'] ?? '') as String;
  String get title => (j['title'] ?? '') as String;
  String get version => (j['version'] ?? '').toString();

  /// Download size in bytes.
  int get size => (j['size'] ?? 0) as int;

  /// Tanzil's comment block (translator, last update, source).
  String get licenseHeader => (j['licenseHeader'] ?? '') as String;
  String get terms => (j['terms'] ?? '') as String;
  bool get nonCommercial => (j['source'] ?? '') == 'tanzil';

  /// "Last Update: April 30, 2011" from the Tanzil header, if any.
  String get lastUpdate {
    final m = RegExp(r'Last Update:\s*(.+)').firstMatch(licenseHeader);
    return m?.group(1)?.trim() ?? '';
  }
}

/// A translation's text for all 6236 ayahs.
class TranslationText {
  TranslationText(this.info, this.text, this.notes);

  final TranslationInfo info;
  final List<String> text;

  /// Footnotes per ayah ('' when none).
  final List<String> notes;
}

/// Surah and ayah numbers.
class AyahRef {
  const AyahRef(this.surah, this.ayah);

  final int surah;
  final int ayah;

  /// "২:২৫৫".
  String get bn => '${toBanglaDigits(surah)}:${toBanglaDigits(ayah)}';

  @override
  bool operator ==(Object other) => other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => surah * 1000 + ayah;

  @override
  String toString() => '$surah:$ayah';

  static AyahRef? parse(String s) {
    final m = RegExp(r'^(\d+):(\d+)$').firstMatch(s);
    return m == null ? null : AyahRef(int.parse(m[1]!), int.parse(m[2]!));
  }
}

/// The full Quran: Tanzil Uthmani Arabic and Bangla translations.
///
/// The list of surahs loads at start-up ([loadMeta], small); the text loads
/// the first time the Quran is opened ([load]).
class Quran {
  Quran._();

  static const total = 6236;

  /// Where the downloadable translations are kept (made by the "Quran data"
  /// workflow from QuranEnc.com / Tanzil.net, text unchanged).
  static const downloadBase =
      'https://github.com/ahmedehsanur8-ctrl/ayah-app/releases/download/quran-data';

  static List<Surah> surahs = const [];
  static List<Juz> juz = const [];
  static List<TranslationInfo> translations = const [];

  /// Tanzil's info block for the Arabic text.
  static Map<String, dynamic> arabicInfo = const {};

  /// When the text was downloaded from the sources (yyyy-mm-dd).
  static String downloadedOn = '';

  static bool get metaLoaded => surahs.length == 114;

  static Future<void> loadMeta() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/quran/meta.json'));
      surahs = [
        for (final s in (j['surahs'] as List).cast<Map<String, dynamic>>())
          Surah(
            n: s['n'],
            start: s['start'],
            ayahCount: s['ayahs'],
            nameAr: s['ar'],
            nameTr: s['tr'],
            nameEn: s['en'],
            meccan: s['type'] == 'Meccan',
          ),
      ];
      final jz = (j['juz'] as List).cast<List>();
      juz = [for (var i = 0; i < jz.length; i++) Juz(i + 1, jz[i][0] as int, jz[i][1] as int)];
      translations = [
        for (final t in (j['translations'] as List).cast<Map<String, dynamic>>())
          TranslationInfo(t),
      ];
      arabicInfo = (j['arabic'] as Map).cast<String, dynamic>();
      downloadedOn = ((j['generatedAt'] ?? '') as String).split('T').first;
    } catch (e) {
      debugPrint('Quran meta failed: $e');
    }
  }

  static Surah surah(int n) => surahs[n - 1];

  static TranslationInfo? info(String id) {
    for (final t in translations) {
      if (t.id == id) return t;
    }
    return null;
  }

  static int indexOf(int s, int a) => surah(s).start + a - 1;

  /// The surah and ayah of index [i] (0–6235).
  static AyahRef refAt(int i) {
    var lo = 0, hi = surahs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (surahs[mid].start <= i) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return AyahRef(lo + 1, i - surahs[lo].start + 1);
  }

  static bool isValid(int s, int a) =>
      metaLoaded && s >= 1 && s <= 114 && a >= 1 && a <= surahs[s - 1].ayahCount;

  /// Which para an ayah is in.
  static int juzOf(int s, int a) {
    var n = 1;
    for (final j in juz) {
      if (j.surah < s || (j.surah == s && j.ayah <= a)) n = j.n;
    }
    return n;
  }

  // ------------------------------------------------------------------ text

  static List<String> arabic = const [];
  static final Map<String, TranslationText> loaded = {};
  static Future<void>? _loading;

  static bool get textLoaded => arabic.length == total;

  /// Loads the Arabic and the bundled Zakaria translation (once).
  static Future<void> load() => textLoaded ? Future.value() : (_loading ??= _load());

  static Future<void> _load() async {
    if (!metaLoaded) await loadMeta();
    final ar = await rootBundle.load('assets/quran/arabic.txt.gz');
    final bn = await rootBundle.load('assets/quran/bn_zakaria.json.gz');
    final result = await compute(_decode, [
      ar.buffer.asUint8List(ar.offsetInBytes, ar.lengthInBytes),
      bn.buffer.asUint8List(bn.offsetInBytes, bn.lengthInBytes),
    ]);
    arabic = result[0];
    loaded['bn_zakaria'] = TranslationText(
      info('bn_zakaria') ?? const TranslationInfo({'id': 'bn_zakaria'}),
      result[1],
      result[2],
    );
    _arabicPlain = null;
  }

  static List<List<String>> _decode(List<Uint8List> files) {
    final ar = const LineSplitter().convert(utf8.decode(gzip.decode(files[0])));
    final t = _decodeTranslation(files[1]);
    return [ar, t[0], t[1]];
  }

  static List<List<String>> _decodeTranslation(Uint8List gz) {
    final j = jsonDecode(utf8.decode(gzip.decode(gz))) as Map<String, dynamic>;
    final rows = (j['verses'] as List).cast<List>();
    if (rows.length != total) throw FormatException('${rows.length} verses');
    return [
      [for (final r in rows) r[0] as String],
      [for (final r in rows) r.length > 1 ? (r[1] as String? ?? '') : ''],
    ];
  }

  /// Arabic of an ayah exactly as in Tanzil.
  static String arabicOf(int s, int a) => arabic[indexOf(s, a)];

  /// The basmala as Tanzil writes it (the first ayah of Al-Fatiha).
  static String get basmala => textLoaded ? arabic[0] : '';

  /// Arabic for display: Tanzil puts the basmala in front of ayah 1 of most
  /// surahs; it is shown on its own line above the surah instead.
  static String displayArabic(int s, int a) {
    final t = arabicOf(s, a);
    final b = basmala;
    if (a == 1 && s != 1 && b.isNotEmpty && t.startsWith('$b ')) {
      return t.substring(b.length + 1);
    }
    return t;
  }

  // --------------------------------------------------------- translations

  static Directory? _dir;

  static Future<Directory> _translationDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    return _dir = await Directory('${base.path}/quran_translations').create(recursive: true);
  }

  static Future<File> _file(String id) async =>
      File('${(await _translationDir()).path}/$id.json.gz');

  static Future<bool> isDownloaded(String id) async {
    if (info(id)?.bundled ?? false) return true;
    try {
      return await (await _file(id)).exists();
    } catch (_) {
      return false;
    }
  }

  /// Makes a downloaded translation ready to show. Returns false if it is not
  /// on the phone (or broken).
  static Future<bool> loadTranslation(String id) async {
    if (loaded.containsKey(id)) return true;
    if (id == 'bn_zakaria') {
      await load();
      return true;
    }
    try {
      final f = await _file(id);
      if (!await f.exists()) return false;
      final t = await compute(_decodeTranslation, await f.readAsBytes());
      loaded[id] = TranslationText(info(id) ?? TranslationInfo({'id': id}), t[0], t[1]);
      return true;
    } catch (e) {
      debugPrint('translation $id: $e');
      return false;
    }
  }

  /// Downloads a translation. [onProgress] gets 0..1.
  static Future<bool> download(String id, {void Function(double)? onProgress}) async {
    final f = await _file(id);
    final tmp = File('${f.path}.part');
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('$downloadBase/$id.json.gz'));
      final res = await req.close();
      if (res.statusCode != 200) return false;
      final total = res.contentLength > 0 ? res.contentLength : (info(id)?.size ?? 0);
      final sink = tmp.openWrite();
      var got = 0;
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress?.call((got / total).clamp(0, 1));
      }
      await sink.close();
      // Check it before keeping it.
      await compute(_decodeTranslation, await tmp.readAsBytes());
      await tmp.rename(f.path);
      loaded.remove(id);
      return await loadTranslation(id);
    } catch (e) {
      debugPrint('download $id: $e');
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return false;
    } finally {
      client.close();
    }
  }

  static Future<void> deleteTranslation(String id) async {
    if (info(id)?.bundled ?? false) return;
    loaded.remove(id);
    _bnPlain.remove(id);
    try {
      final f = await _file(id);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- search

  static List<String>? _arabicPlain;
  static final Map<String, List<String>> _bnPlain = {};

  /// Arabic without vowel marks, for searching.
  static String plainArabic(String s) => s
      .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
      .replaceAll(RegExp('[ٱآأإ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ی', 'ي');

  /// Bangla without joiners and with ASCII digits, for searching.
  static String plainBangla(String s) => s
      .replaceAll('্‌', '')
      .replaceAll(RegExp('[‌‍]'), '')
      .replaceAllMapped(RegExp('[০-৯]'), (m) => '${m[0]!.codeUnitAt(0) - 0x09E6}');

  static String _latin(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '')
      .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

  static String _bnName(String s) =>
      plainBangla(s)
          .replaceAll(RegExp(r'[\s\-‘’\x27]'), '')
          .replaceAll('সূরা', '')
          .replaceAll('সুরা', '');

  /// "২:২৫৫", "2:255", "2 255", "2.255" → the ayah (if it exists).
  static AyahRef? parseRef(String q) {
    final m = RegExp(r'^\s*(\d{1,3})\s*[:：.\-/ ]\s*(\d{1,3})\s*$').firstMatch(plainBangla(q));
    if (m == null) return null;
    final r = AyahRef(int.parse(m[1]!), int.parse(m[2]!));
    return isValid(r.surah, r.ayah) ? r : null;
  }

  /// Surahs whose number or name (Bangla, English, Arabic) matches [q].
  static List<Surah> searchSurahs(String q) {
    final query = plainBangla(q.trim());
    if (query.isEmpty) return const [];
    final number = int.tryParse(query);
    if (number != null) return number >= 1 && number <= 114 ? [surah(number)] : const [];
    final bn = _bnName(query);
    final lat = _latin(query.replaceAll(RegExp(r'^(surah?|sura)\s+', caseSensitive: false), ''));
    final ar = plainArabic(query).replaceAll(' ', '');
    final isArabic = ar.isNotEmpty && RegExp('[\u0600-\u06FF]').hasMatch(ar);
    return [
      for (final s in surahs)
        if ((bn.isNotEmpty && _bnName(s.nameBn).contains(bn)) ||
            (lat.length >= 2 &&
                (_latin(s.nameTr).contains(lat) || _latin(s.nameEn).contains(lat))) ||
            (isArabic && plainArabic(s.nameAr).contains(ar)) ||
            (bn.isNotEmpty && plainBangla(s.meaningBn).contains(query)))
          s,
    ];
  }

  /// Ayahs whose Bangla (any loaded translation) or Arabic contains [q].
  static List<AyahRef> searchAyahs(String q, {int limit = 300}) {
    final query = q.trim();
    if (query.length < 2 || !textLoaded) return const [];
    final isArabic = RegExp('[؀-ۿ]').hasMatch(query);
    final out = <AyahRef>[];
    if (isArabic) {
      final plain = _arabicPlain ??= [for (final a in arabic) plainArabic(a)];
      final aq = plainArabic(query);
      for (var i = 0; i < total && out.length < limit; i++) {
        if (plain[i].contains(aq)) out.add(refAt(i));
      }
      return out;
    }
    final bq = plainBangla(query).toLowerCase();
    final texts = [
      for (final e in loaded.entries)
        _bnPlain[e.key] ??= [for (final t in e.value.text) plainBangla(t).toLowerCase()],
    ];
    for (var i = 0; i < total && out.length < limit; i++) {
      for (final t in texts) {
        if (t[i].contains(bq)) {
          out.add(refAt(i));
          break;
        }
      }
    }
    return out;
  }
}
