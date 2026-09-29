import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../models/content.dart';
import 'audio.dart';
import 'quran.dart';
import 'settings.dart';

/// Per-ayah recitation files (EveryAyah.com) kept on the phone, so a surah
/// plays offline after it was heard or downloaded once.
class QuranAudioFiles {
  QuranAudioFiles._();

  static Directory? _base;
  static final Map<String, Future<File?>> _inFlight = {};

  static Future<Directory> base() async {
    if (_base != null) return _base!;
    final d = await getApplicationSupportDirectory();
    return _base = Directory('${d.path}/quran_audio');
  }

  static String _pad(int n) => n.toString().padLeft(3, '0');

  static Future<Directory> surahDir(String reciter, int s) async =>
      Directory('${(await base()).path}/$reciter/${_pad(s)}');

  static Future<File> file(String reciter, int s, int a) async =>
      File('${(await surahDir(reciter, s)).path}/${_pad(a)}.mp3');

  /// The ayah's file, downloading it first if needed; null when offline.
  static Future<File?> ensure(String reciter, int s, int a) async {
    final f = await file(reciter, s, a);
    if (await f.exists()) return f;
    final key = f.path;
    return _inFlight[key] ??= _download(reciter, s, a, f).whenComplete(() => _inFlight.remove(key));
  }

  static Future<File?> _download(String reciter, int s, int a, File f) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    final tmp = File('${f.path}.part');
    try {
      await f.parent.create(recursive: true);
      final res = await (await client.getUrl(AudioController.ayahUrl(reciter, s, a))).close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final sink = tmp.openWrite();
      await res.pipe(sink);
      if (await tmp.length() < 1000) {
        await tmp.delete();
        return null;
      }
      return await tmp.rename(f.path);
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }

  /// How many ayahs of surah [s] are on the phone, and their size in bytes.
  static Future<({int files, int bytes})> stats(String reciter, int s) async {
    final d = await surahDir(reciter, s);
    if (!await d.exists()) return (files: 0, bytes: 0);
    var files = 0, bytes = 0;
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith('.mp3')) {
        files++;
        bytes += await e.length();
      }
    }
    return (files: files, bytes: bytes);
  }

  /// Every saved surah: reciter, surah, files, bytes.
  static Future<List<({String reciter, int surah, int files, int bytes})>> all() async {
    final b = await base();
    final out = <({String reciter, int surah, int files, int bytes})>[];
    if (!await b.exists()) return out;
    await for (final r in b.list()) {
      if (r is! Directory) continue;
      final reciter = r.path.split('/').last;
      await for (final sd in r.list()) {
        final s = int.tryParse(sd.path.split('/').last);
        if (sd is! Directory || s == null) continue;
        final st = await stats(reciter, s);
        if (st.files > 0) out.add((reciter: reciter, surah: s, files: st.files, bytes: st.bytes));
      }
    }
    out.sort((x, y) => x.surah != y.surah ? x.surah - y.surah : x.reciter.compareTo(y.reciter));
    return out;
  }

  static Future<void> deleteSurah(String reciter, int s) async {
    final d = await surahDir(reciter, s);
    if (await d.exists()) await d.delete(recursive: true);
  }
}

/// "১২.৪ MB".
String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${toBanglaDigits((bytes / 1024).round())} KB';
  return '${toBanglaDigits((bytes / 1024 / 1024).toStringAsFixed(1))} MB';
}

/// Downloads whole surahs for offline listening, one at a time.
class SurahDownloads extends ChangeNotifier {
  SurahDownloads._();

  static final instance = SurahDownloads._();

  /// "reciter/surah" → 0..1.
  final Map<String, double> progress = {};
  final Set<String> _cancelled = {};

  static String _key(String reciter, int s) => '$reciter/$s';

  bool isRunning(String reciter, int s) => progress.containsKey(_key(reciter, s));

  double? progressOf(String reciter, int s) => progress[_key(reciter, s)];

  /// Returns true when every ayah is on the phone.
  Future<bool> start(String reciter, int s) async {
    final key = _key(reciter, s);
    if (progress.containsKey(key)) return false;
    _cancelled.remove(key);
    final n = Quran.surah(s).ayahCount;
    progress[key] = 0;
    notifyListeners();
    var ok = true;
    for (var a = 1; a <= n; a++) {
      if (_cancelled.contains(key)) {
        ok = false;
        break;
      }
      if (await QuranAudioFiles.ensure(reciter, s, a) == null) {
        ok = false;
        break;
      }
      progress[key] = a / n;
      notifyListeners();
    }
    progress.remove(key);
    notifyListeners();
    return ok;
  }

  void cancel(String reciter, int s) {
    _cancelled.add(_key(reciter, s));
  }
}

enum QuranRepeat { off, ayah, range }

/// Recites a surah ayah by ayah (EveryAyah.com), optionally with the Bangla
/// meaning after each ayah, with repeat, speed and a sleep timer. Uses the
/// app's one player, so it keeps playing with the screen off and shows media
/// controls in the notification.
class QuranPlayer extends ChangeNotifier {
  QuranPlayer._() {
    _audio.addListener(notifyListeners);
  }

  static final instance = QuranPlayer._();

  static const id = 'quran';

  final _audio = AudioController.instance;
  int _session = -1;

  /// What is playing (or was last).
  int surah = 0;
  int ayah = 0;

  QuranRepeat repeat = QuranRepeat.off;

  /// How many times to repeat (0 = until stopped).
  int repeatCount = 3;
  int rangeFrom = 1;
  int rangeTo = 1;

  /// When the sleep timer stops playback.
  DateTime? sleepAt;
  Timer? _sleepTimer;

  bool get active =>
      _audio.currentId == id && _audio.alive(_session) && _audio.status != AudioStatus.idle;

  AudioStatus get status => active ? _audio.status : AudioStatus.idle;

  bool get isPlaying =>
      status == AudioStatus.playing ||
      status == AudioStatus.loading ||
      status == AudioStatus.speaking;

  bool isPlayingAyah(int s, int a) => active && surah == s && ayah == a;

  String get reciterId => Reciter.byId(AppState.instance.settings.reciterId).id;

  Future<void> toggle(int s, int a) async {
    if (active && surah == s) {
      if (status == AudioStatus.paused) return _audio.resume();
      return _audio.pause();
    }
    await play(s, a);
  }

  Future<void> stop() => _audio.stop();

  Future<void> next() async {
    if (surah == 0) return;
    if (ayah < Quran.surah(surah).ayahCount) await play(surah, ayah + 1);
  }

  Future<void> previous() async {
    if (surah == 0) return;
    await play(surah, ayah > 1 ? ayah - 1 : 1);
  }

  void setRepeat(QuranRepeat r, {int? count, int? from, int? to}) {
    repeat = r;
    if (count != null) repeatCount = count;
    if (from != null) rangeFrom = from;
    if (to != null) rangeTo = to;
    notifyListeners();
  }

  void setSleep(Duration? d) {
    _sleepTimer?.cancel();
    sleepAt = d == null ? null : DateTime.now().add(d);
    if (d != null) {
      _sleepTimer = Timer(d, () {
        sleepAt = null;
        if (active) _audio.stop();
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> setSpeed(double v) async {
    await _audio.setSpeed(v);
    try {
      if (active) await _audio.player.setSpeed(v);
    } catch (_) {}
  }

  /// Plays surah [s] from ayah [from] to its end (or as the repeat says), or
  /// only up to ayah [to] (a Quranic dua).
  Future<void> play(int s, int from, {int? to}) async {
    final session = await _audio.begin(id);
    _session = session;
    surah = s;
    ayah = from;
    if (repeat == QuranRepeat.range &&
        (rangeFrom > rangeTo ||
            rangeTo > Quran.surah(s).ayahCount ||
            from < rangeFrom ||
            from > rangeTo)) {
      repeat = QuranRepeat.off;
    }
    notifyListeners();
    await Quran.load();
    final prefs = AppState.instance.settings.quran;
    var passes = 0;
    var a = from;
    while (_audio.alive(session)) {
      ayah = a;
      notifyListeners();
      unawaited(prefs.setLastRead(s, a));
      final times = repeat == QuranRepeat.ayah ? repeatCount : 1;
      for (var r = 0; (times == 0 || r < times) && _audio.alive(session); r++) {
        final result = await _playAyah(session, s, a);
        if (result == _Result.error) {
          if (_audio.alive(session)) {
            _audio.report(AudioProblem.offline);
            await _audio.stop();
          }
          return;
        }
        if (result == _Result.stopped) {
          if (_audio.alive(session)) await _audio.stop();
          return;
        }
        if (prefs.banglaAfterAyah && _audio.alive(session)) {
          final t = Quran.loaded[prefs.translations.first] ?? Quran.loaded['bn_zakaria'];
          if (t != null) {
            final ok = await _audio.speakPart(session, t.text[Quran.indexOf(s, a)]);
            if (!ok) {
              if (_audio.alive(session)) await _audio.stop();
              return;
            }
          }
        }
      }
      if (!_audio.alive(session)) return;
      if (repeat == QuranRepeat.range && a >= rangeTo) {
        passes++;
        if (repeatCount == 0 || passes < repeatCount) {
          a = rangeFrom;
          continue;
        }
        break;
      }
      if (a >= Quran.surah(s).ayahCount || (to != null && a >= to)) break;
      a++;
    }
    if (_audio.alive(session)) {
      try {
        await _audio.player.stop();
      } catch (_) {}
      _audio.end(session);
    }
  }

  Future<_Result> _playAyah(int session, int s, int a) async {
    final reciter = reciterId;
    _audio.setStatus(session, AudioStatus.loading);
    final file = await QuranAudioFiles.ensure(reciter, s, a);
    if (!_audio.alive(session)) return _Result.stopped;
    if (file == null) return _Result.error;
    final surahInfo = Quran.surah(s);
    final tag = AudioController.mediaItem(
      'quran-$s-$a',
      'সূরা ${surahInfo.nameBn} · আয়াত ${toBanglaDigits(a)}',
      Reciter.byId(reciter).name,
    );
    try {
      final player = _audio.player;
      await player.setAudioSource(AudioSource.file(file.path, tag: tag));
      await player.setSpeed(AppState.instance.settings.playbackSpeed);
      if (!_audio.alive(session)) return _Result.stopped;
      _audio.setStatus(session, AudioStatus.playing);
      // Get the next ayahs ready while this one plays.
      for (var n = a + 1; n <= a + 2 && n <= surahInfo.ayahCount; n++) {
        unawaited(QuranAudioFiles.ensure(reciter, s, n));
      }
      final ended = await _audio.playToEnd(session);
      return ended ? _Result.ended : _Result.stopped;
    } catch (e) {
      debugPrint('quran audio: $e');
      return _Result.error;
    }
  }
}

enum _Result { ended, stopped, error }
