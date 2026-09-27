import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../models/story.dart';
import 'bangla_tts.dart';
import 'settings.dart';

enum AudioStatus { idle, loading, playing, speaking }

enum AudioProblem { none, offline, noBanglaVoice }

/// Plays one thing at a time: an ayah (Arabic recitation, then optionally the
/// Bangla meaning), a hadith (Bangla voice) or a Sahaba story.
class AudioController extends ChangeNotifier {
  AudioController._();

  static final instance = AudioController._();

  AudioPlayer? _player;
  AudioPlayer get _p => _player ??= AudioPlayer();

  String? _currentId;
  AudioStatus _status = AudioStatus.idle;
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

  Future<void> playItem(ContentItem item) async {
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
      final ok = await _playSources(session, sources);
      if (!ok && session == _session) _report(AudioProblem.offline);
      if (session != _session) return;
      if (!settings.readBanglaAfterArabic) return _finish(session);
    }
    await _speak(session, item.bangla);
  }

  Future<void> playStory(Story story) async {
    final session = await _start(story.id);
    if (story.hasAudio) {
      final ok = await _playSources(session, [AudioSource.asset(story.audioAsset)]);
      if (ok || session != _session) return _finish(session);
    }
    await _speak(session, story.spokenText);
  }

  Future<int> _start(String id) async {
    await stop();
    problem = AudioProblem.none;
    _set(id, AudioStatus.loading);
    return _session;
  }

  /// Plays the sources one after another. Returns false on a network error.
  Future<bool> _playSources(int session, List<AudioSource> sources) async {
    try {
      await _p.setAudioSources(sources);
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

  Future<void> _speak(int session, String text) async {
    if (session != _session) return;
    if (!await BanglaTts.init()) {
      _report(AudioProblem.noBanglaVoice);
      return _finish(session);
    }
    _set(_currentId, AudioStatus.speaking);
    await BanglaTts.speak(text, stillWanted: () => session == _session);
    _finish(session);
  }

  void _finish(int session) {
    if (session == _session) _set(_currentId, AudioStatus.idle);
  }

  Future<void> stop() async {
    _session++;
    try {
      await _player?.stop();
    } catch (_) {}
    await BanglaTts.stop();
    if (_status != AudioStatus.idle) _set(_currentId, AudioStatus.idle);
  }
}
