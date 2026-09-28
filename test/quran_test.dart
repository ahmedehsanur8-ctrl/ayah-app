import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/services/quran.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppState.load();
    await Quran.loadMeta();
    await Quran.load();
  });

  test('all 114 surahs and 30 paras, 6236 ayahs', () {
    expect(Quran.surahs.length, 114);
    expect(Quran.juz.length, 30);
    expect(Quran.surahs.fold<int>(0, (n, s) => n + s.ayahCount), Quran.total);
    var start = 0;
    for (final s in Quran.surahs) {
      expect(s.start, start, reason: 'surah ${s.n}');
      expect(s.nameBn, isNotEmpty);
      expect(s.meaningBn, isNotEmpty);
      expect(s.nameAr, isNotEmpty);
      start += s.ayahCount;
    }
    expect(Quran.surah(2).ayahCount, 286);
    expect(Quran.surah(1).meccan, isTrue);
    expect(Quran.surah(2).meccan, isFalse);
    expect(Quran.juz.first.surah, 1);
    expect(Quran.juz[29].surah, 78);
  });

  test('every ayah has Arabic and the bundled Bangla translation', () {
    expect(Quran.arabic.length, Quran.total);
    final z = Quran.loaded['bn_zakaria']!;
    expect(z.text.length, Quran.total);
    expect(z.notes.length, Quran.total);
    for (var i = 0; i < Quran.total; i++) {
      expect(Quran.arabic[i].trim(), isNotEmpty, reason: 'Arabic $i');
      expect(z.text[i].trim(), isNotEmpty, reason: 'Bangla $i');
      final r = Quran.refAt(i);
      expect(Quran.indexOf(r.surah, r.ayah), i);
    }
    expect(z.info.name, 'ড. আবু বকর মুহাম্মাদ যাকারিয়া');
  });

  test('basmala is shown apart, the text itself is unchanged', () {
    final b = Quran.basmala;
    expect(b, Quran.arabicOf(1, 1));
    expect(Quran.displayArabic(1, 1), b);
    expect(Quran.arabicOf(2, 1), '$b ${Quran.displayArabic(2, 1)}');
    expect(Quran.displayArabic(9, 1), Quran.arabicOf(9, 1));
    expect(Quran.surah(9).hasSeparateBasmala, isFalse);
    expect(Quran.surah(1).hasSeparateBasmala, isFalse);
    expect(Quran.surah(2).hasSeparateBasmala, isTrue);
  });

  test('search by reference, surah name and words', () {
    expect(Quran.parseRef('২:২৫৫'), const AyahRef(2, 255));
    expect(Quran.parseRef('2:255'), const AyahRef(2, 255));
    expect(Quran.parseRef('2 255'), const AyahRef(2, 255));
    expect(Quran.parseRef('2:287'), isNull);
    expect(Quran.parseRef('115:1'), isNull);
    expect(Quran.searchSurahs('36').single.n, 36);
    expect(Quran.searchSurahs('১১৪').single.n, 114);
    expect(Quran.searchSurahs('বাকারা').map((s) => s.n), contains(2));
    expect(Quran.searchSurahs('সূরা ইয়াসীন').map((s) => s.n), contains(36));
    expect(Quran.searchSurahs('baqara').map((s) => s.n), contains(2));
    expect(Quran.searchSurahs('Fatiha').map((s) => s.n), contains(1));
    expect(Quran.searchSurahs('The Cow').map((s) => s.n), contains(2));
    expect(Quran.searchSurahs('البقرة').map((s) => s.n), contains(2));
    expect(Quran.searchSurahs('গাভী').map((s) => s.n), contains(2));
    expect(Quran.searchAyahs('চিরঞ্জীব'), contains(const AyahRef(2, 255)));
    expect(Quran.searchAyahs('الحي القيوم'), contains(const AyahRef(2, 255)));
    final sw = Stopwatch()..start();
    Quran.searchAyahs('আল্লাহ');
    Quran.searchAyahs('রহমত');
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('last read and bookmarks are remembered', () async {
    final prefs = AppState.instance.settings.quran;
    expect(prefs.hasLastRead, isFalse);
    await prefs.setLastRead(18, 10);
    expect(prefs.hasLastRead, isTrue);
    expect((prefs.lastSurah, prefs.lastAyah), (18, 10));
    await prefs.toggleBookmark(2, 255);
    await prefs.toggleBookmark(1, 1);
    expect(prefs.bookmarks, ['1:1', '2:255']);
    await prefs.toggleBookmark(1, 1);
    expect(prefs.bookmarks, ['2:255']);
    expect(prefs.translations, ['bn_zakaria']);
    await prefs.setTranslations(['bn_zakaria', 'bn_rwwad', 'bn_hoque']);
    expect(prefs.translations.length, 2);
  });

  test('downloadable translations are listed with their source', () {
    final ids = Quran.translations.map((t) => t.id).toList();
    expect(ids, ['bn_zakaria', 'bn_rwwad', 'bn_muhiuddin', 'bn_hoque']);
    expect(Quran.info('bn_zakaria')!.bundled, isTrue);
    for (final id in ['bn_rwwad', 'bn_muhiuddin', 'bn_hoque']) {
      final t = Quran.info(id)!;
      expect(t.bundled, isFalse);
      expect(t.size, greaterThan(100000));
      expect(t.publisher, isNotEmpty);
    }
    expect(Quran.info('bn_muhiuddin')!.nonCommercial, isTrue);
    expect(Quran.info('bn_hoque')!.lastUpdate, isNotEmpty);
  });
}
