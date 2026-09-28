import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../models/story.dart';
import 'bangla_tts.dart';
import 'settings.dart';

enum AudioStatus { idle, loading, playing, paused, speaking }

enum AudioProblem { none, offline, noBanglaVoice }

/// What is being heard right now.
enum AudioPhase { none, arabic, bangla, story }

/// Plays one thing at a time: an ayah (Arabic recitation, then optionally the
/// Bangla meaning), a hadith (Bangla voice) or a Sahaba story.
class AudioController extends ChangeNotifier {
  AudioController._();

  static final instance = AudioController._();

  static const speeds = [0.75, 1.0, 1.25, 1.5];

  AudioPlayer? _player;
  AudioPlayer get _p => _player ??= AudioPlayer();

  String? _currentId;
  AudioStatus _status = AudioStatus.idle;
  AudioPhase phase = AudioPhase.none;
  AudioProblem problem = AudioProblem.none;

  /// Increases each time a new problem is reported (so the UI shows it once).
  int problemCount = 0;

  void _report(AudioProblem p) {
    problem = p;
    problemCount++;
    notifyListeners();
  }

  /// Increases on every start/stop, so an older playback knows it was replaced.
  int _session = 0;

  String? get currentId => _currentId;
  AudioStatus get status => _status;
  bool isActive(String id) => _currentId == id && _status != AudioStatus.idle;
  bool isPlaying(String id) =>
      _currentId == id &&
      (_status == AudioStatus.playing ||
          _status == AudioStatus.speaking ||
          _status == AudioStatus.loading);

  /// Position and length of the current recording (Arabic verse or story).
  Stream<Duration> get positionStream => _p.positionStream;
  Duration get position => _player?.position ?? Duration.zero;
  Duration? get duration => _player?.duration;

  /// Which verse of a multi-verse ayah item is playing (0-based) and how many.
  int get verseIndex => _player?.currentIndex ?? 0;
  int verseCount = 0;

  void _set(String? id, AudioStatus s) {
    _currentId = id;
    _status = s;
    notifyListeners();
  }

  /// EveryAyah.com URL of one verse, e.g. .../Alafasy_128kbps/039053.mp3
  static Uri ayahUrl(String reciterId, int surah, int ayah) => Uri.parse(
    'https://everyayah.com/data/$reciterId/'
    '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3',
  );

  Future<void> toggleItem(ContentItem item) => isActive(item.id) ? stop() : playItem(item);

  Future<void> toggleStory(Story story) => isActive(story.id) ? stop() : playStory(story);

  /// Plays [item]. Returns true when it played to the end (not stopped or
  /// replaced by something else).
  Future<bool> playItem(ContentItem item) async {
    final session = await _start(item.id);
    final settings = AppState.instance.settings;
    if (item.isAyah && item.surah > 0) {
      final reciter = Reciter.byId(settings.reciterId).id;
      final sources = [
        for (var a = item.ayahStart; a <= item.ayahEnd; a++)
          // Streams the verse and saves it, so it plays offline next time.
          // ignore: experimental_member_use
          LockCachingAudioSource(ayahUrl(reciter, item.surah, a)),
      ];
      verseCount = sources.length;
      phase = AudioPhase.arabic;
      final ok = await _playSources(session, sources, speed: settings.playbackSpeed);
      if (!ok && session == _session) _report(AudioProblem.offline);
      if (session != _session) return false;
      if (!settings.readBanglaAfterArabic) return _finish(session);
    }
    return _speak(session, item.bangla);
  }

  /// Plays a story, from where it stopped last time.
  Future<bool> playStory(Story story, {bool fromStart = false}) async {
    final session = await _start(story.id);
    phase = AudioPhase.story;
    final settings = AppState.instance.settings;
    if (story.hasAudio) {
      var start = fromStart ? Duration.zero : settings.storyPosition(story.id);
      final len = settings.storyLength(story.id);
      // Finished last time: start again from the beginning.
      if (len > Duration.zero && start >= len - const Duration(seconds: 3)) start = Duration.zero;
      var length = len;
      final sub = _p.positionStream.listen((pos) {
        if (session != _session) return;
        length = _p.duration ?? length;
        // Save about every 5 seconds.
        if ((pos.inSeconds - _lastSaved.inSeconds).abs() >= 5) {
          _lastSaved = pos;
          settings.saveStoryProgress(story.id, pos, _p.duration ?? Duration.zero);
        }
      });
      final ok = await _playSources(session, [AudioSource.asset(story.audioAsset)], start: start);
      await sub.cancel();
      if (ok && session == _session && length > Duration.zero) {
        // Played to the end: next time it starts from the beginning.
        await settings.saveStoryProgress(story.id, length, length);
      }
      if (ok || session != _session) return _finish(session);
    }
    return _speak(session, story.spokenText);
  }

  Duration _lastSaved = Duration.zero;

  Future<int> _start(String id) async {
    await stop();
    problem = AudioProblem.none;
    verseCount = 0;
    _lastSaved = Duration.zero;
    _set(id, AudioStatus.loading);
    return _session;
  }

  /// Plays the sources one after another. Returns false on a network error.
  Future<bool> _playSources(
    int session,
    List<AudioSource> sources, {
    Duration start = Duration.zero,
    double speed = 1.0,
  }) async {
    try {
      await _p.setAudioSources(sources, initialPosition: start);
      await _p.setSpeed(speed);
      if (session != _session) return true;
      _set(_currentId, AudioStatus.playing);
      final done = _p.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed || session != _session,
      );
      unawaited(_p.play());
      await done;
      await _p.stop();
      return true;
    } catch (e) {
      debugPrint('audio error: $e');
      return false;
    }
  }

  Future<bool> _speak(int session, String text) async {
    if (session != _session) return false;
    if (!await BanglaTts.init()) {
      _report(AudioProblem.noBanglaVoice);
      _finish(session);
      return false;
    }
    phase = phase == AudioPhase.story ? AudioPhase.story : AudioPhase.bangla;
    _set(_currentId, AudioStatus.speaking);
    await BanglaTts.speak(text, stillWanted: () => session == _session);
    return _finish(session);
  }

  bool _finish(int session) {
    final natural = session == _session;
    if (natural) {
      phase = AudioPhase.none;
      _set(_currentId, AudioStatus.idle);
    }
    return natural;
  }

  /// Pauses a recording. The phone's Bangla voice cannot pause, so it stops.
  Future<void> pause() async {
    if (_status == AudioStatus.playing) {
      await _p.pause();
      _set(_currentId, AudioStatus.paused);
    } else if (_status == AudioStatus.speaking) {
      await stop();
    }
  }

  Future<void> resume() async {
    if (_status == AudioStatus.paused) {
      _set(_currentId, AudioStatus.playing);
      unawaited(_p.play());
    }
  }

  Future<void> seek(Duration d) async {
    if (_player != null) await _p.seek(d);
  }

  Future<void> setSpeed(double v) async {
    await AppState.instance.settings.setPlaybackSpeed(v);
    if (_player != null && phase == AudioPhase.arabic) await _p.setSpeed(v);
    notifyListeners();
  }

  Future<void> stop() async {
    _session++;
    // Remember exactly where a story stopped.
    final p = _player;
    if (phase == AudioPhase.story &&
        _currentId != null &&
        p != null &&
        p.position > Duration.zero) {
      unawaited(
        AppState.instance.settings.saveStoryProgress(
          _currentId!,
          p.position,
          p.duration ?? Duration.zero,
        ),
      );
    }
    try {
      await _player?.stop();
    } catch (_) {}
    await BanglaTts.stop();
    phase = AudioPhase.none;
    if (_status != AudioStatus.idle) _set(_currentId, AudioStatus.idle);
  }
}
