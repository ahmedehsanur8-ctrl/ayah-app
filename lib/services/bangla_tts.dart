import 'package:flutter_tts/flutter_tts.dart';

/// Reads Bangla text aloud with the phone's built-in text-to-speech.
class BanglaTts {
  BanglaTts._();

  static final _tts = FlutterTts();
  static bool? _ready;

  /// Slightly slower than normal (Android's normal rate is 0.5).
  static const rate = 0.42;

  /// Sets up Bangla; returns false if the phone has no Bangla voice.
  static Future<bool> init() async {
    if (_ready != null) return _ready!;
    try {
      String? lang;
      for (final l in ['bn-BD', 'bn-IN', 'bn']) {
        if (await _tts.isLanguageAvailable(l) == true) {
          lang = l;
          break;
        }
      }
      if (lang == null) return _ready = false;
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(0.95);
      await _tts.awaitSpeakCompletion(true);
      await _pickMaleVoice();
      return _ready = true;
    } catch (_) {
      return _ready = false;
    }
  }

  /// Android does not report a voice's gender, so this uses the voice name:
  /// names that say "male", or Google voice codes ending in "m" (for example
  /// "bn-in-x-bnm-local"). If none is found, the phone's default voice is kept.
  static Future<void> _pickMaleVoice() async {
    final voices = await _tts.getVoices;
    if (voices is! List) return;
    final bangla = voices
        .whereType<Map>()
        .map((v) => v.map((k, val) => MapEntry('$k', '$val')))
        .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('bn'))
        .toList();
    Map<String, String>? pick;
    for (final v in bangla) {
      final name = (v['name'] ?? '').toLowerCase();
      if (name.contains('male') && !name.contains('female')) pick ??= v;
    }
    for (final v in bangla) {
      final code = RegExp(r'-x-([a-z]+)-').firstMatch((v['name'] ?? '').toLowerCase());
      if (code != null && code[1]!.endsWith('m')) pick ??= v;
    }
    if (pick != null) {
      await _tts.setVoice({'name': pick['name']!, 'locale': pick['locale']!});
    }
  }

  /// Removes footnote markers like [১] that should not be read aloud.
  static String clean(String text) =>
      text.replaceAll(RegExp(r'\[[০-৯0-9]+\]'), '').replaceAll(RegExp(r'-{2,}'), ', ');

  /// Speaks [text] paragraph by paragraph. Returns when finished or stopped.
  static Future<void> speak(String text, {bool Function()? stillWanted}) async {
    for (final part in clean(text).split(RegExp(r'\n\s*\n'))) {
      if (stillWanted != null && !stillWanted()) return;
      if (part.trim().isEmpty) continue;
      await _tts.speak(part.trim());
    }
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
