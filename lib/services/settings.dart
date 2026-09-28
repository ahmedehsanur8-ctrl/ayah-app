import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings, saved on the phone.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async => AppSettings._(await SharedPreferences.getInstance());

  TimeOfDay get morningTime => TimeOfDay(
    hour: _prefs.getInt('morningHour') ?? 9,
    minute: _prefs.getInt('morningMinute') ?? 0,
  );

  TimeOfDay get nightTime =>
      TimeOfDay(hour: _prefs.getInt('nightHour') ?? 21, minute: _prefs.getInt('nightMinute') ?? 0);

  bool get hadithAtNight => _prefs.getBool('hadithAtNight') ?? true;
  bool get remindersOn => _prefs.getBool('remindersOn') ?? true;
  double get textScale => _prefs.getDouble('textScale') ?? 1.0;
  bool get setupDone => _prefs.getBool('setupDone') ?? false;

  /// Dates (yyyy-mm-dd + slot) on which the user pressed "আমি পড়েছি".
  Set<String> get readMarks => (_prefs.getStringList('readMarks') ?? []).toSet();

  /// EveryAyah.com reciter folder (see [Reciter.all]).
  String get reciterId => _prefs.getString('reciter') ?? Reciter.all.first.id;

  /// true = after the Arabic recitation, read the Bangla meaning aloud.
  bool get readBanglaAfterArabic => _prefs.getBool('readBangla') ?? true;

  Future<void> setReciter(String id) async {
    await _prefs.setString('reciter', id);
    notifyListeners();
  }

  Future<void> setReadBanglaAfterArabic(bool v) async {
    await _prefs.setBool('readBangla', v);
    notifyListeners();
  }

  /// Saved (favourite) item ids, newest first.
  List<String> get favorites => _prefs.getStringList('favorites') ?? [];

  bool isFavorite(String id) => favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    final list = favorites;
    list.contains(id) ? list.remove(id) : list.insert(0, id);
    await _prefs.setStringList('favorites', list);
    notifyListeners();
  }

  Future<void> setMorningTime(TimeOfDay t) async {
    await _prefs.setInt('morningHour', t.hour);
    await _prefs.setInt('morningMinute', t.minute);
    notifyListeners();
  }

  Future<void> setNightTime(TimeOfDay t) async {
    await _prefs.setInt('nightHour', t.hour);
    await _prefs.setInt('nightMinute', t.minute);
    notifyListeners();
  }

  Future<void> setHadithAtNight(bool v) async {
    await _prefs.setBool('hadithAtNight', v);
    notifyListeners();
  }

  Future<void> setRemindersOn(bool v) async {
    await _prefs.setBool('remindersOn', v);
    notifyListeners();
  }

  Future<void> setTextScale(double v) async {
    await _prefs.setDouble('textScale', v);
    notifyListeners();
  }

  Future<void> setSetupDone() async {
    await _prefs.setBool('setupDone', true);
    notifyListeners();
  }

  /// Phone-maker steps (autostart, pop-up windows …) the user marked as done.
  /// Android can't tell the app whether these are on.
  Set<String> get brandStepsDone => (_prefs.getStringList('brandStepsDone') ?? []).toSet();

  Future<void> setBrandStepDone(String id, bool done) async {
    final v = brandStepsDone;
    done ? v.add(id) : v.remove(id);
    await _prefs.setStringList('brandStepsDone', v.toList());
    notifyListeners();
  }

  // ------------------------------------------------------------ reminder sound

  /// 'chime', 'bell', 'phone', 'tilawat' (start of the recitation) or 'off'.
  String get reminderSound => _prefs.getString('reminderSound') ?? 'chime';

  Future<void> setReminderSound(String v) async {
    await _prefs.setString('reminderSound', v);
    notifyListeners();
  }

  bool get reminderVibrate => _prefs.getBool('reminderVibrate') ?? true;

  Future<void> setReminderVibrate(bool v) async {
    await _prefs.setBool('reminderVibrate', v);
    notifyListeners();
  }

  /// Master switch for the azan and prayer notifications (pause all).
  bool get azanEnabled => _prefs.getBool('azanEnabled') ?? true;

  Future<void> setAzanEnabled(bool v) async {
    await _prefs.setBool('azanEnabled', v);
    notifyListeners();
  }

  // ------------------------------------------------------------ appearance

  /// 'system', 'light' or 'dark'.
  String get themeModeName => _prefs.getString('themeMode') ?? 'system';

  ThemeMode get themeMode => switch (themeModeName) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(String v) async {
    await _prefs.setString('themeMode', v);
    notifyListeners();
  }

  /// Playback speed of the Arabic recitation (1.0 = normal).
  double get playbackSpeed => _prefs.getDouble('speed') ?? 1.0;

  Future<void> setPlaybackSpeed(double v) async {
    await _prefs.setDouble('speed', v);
    notifyListeners();
  }

  // ------------------------------------------------------------ prayer times

  /// Saved place for prayer times and Qibla (stays on the phone).
  double? get latitude => _prefs.getDouble('lat');
  double? get longitude => _prefs.getDouble('lng');
  bool get hasLocation => latitude != null && longitude != null;

  /// Name shown in the location pill (city name, or "বর্তমান অবস্থান").
  String get placeName => _prefs.getString('placeName') ?? '';

  /// 'gps' (phone location) or 'city' (picked by hand).
  String get locationSource => _prefs.getString('locationSource') ?? '';

  Future<void> setLocation(double lat, double lng, String name, String source) async {
    await _prefs.setDouble('lat', lat);
    await _prefs.setDouble('lng', lng);
    await _prefs.setString('placeName', name);
    await _prefs.setString('locationSource', source);
    notifyListeners();
  }

  /// adhan CalculationMethod name. Karachi is the usual choice in Bangladesh.
  String get calcMethod => _prefs.getString('calcMethod') ?? 'karachi';

  /// 'hanafi' or 'shafi' (Asr time).
  String get asrMethod => _prefs.getString('asrMethod') ?? 'hanafi';

  Future<void> setCalcMethod(String v) async {
    await _prefs.setString('calcMethod', v);
    notifyListeners();
  }

  Future<void> setAsrMethod(String v) async {
    await _prefs.setString('asrMethod', v);
    notifyListeners();
  }

  /// Per prayer ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha'):
  /// 'azan' (full azan), 'notify' (notification only) or 'off'.
  String azanMode(String prayer) {
    final v = _prefs.getString('azanMode_$prayer');
    if (v != null) return v;
    // Older versions stored an on/off bell.
    return (_prefs.getBool('azan_$prayer') ?? true) ? 'azan' : 'off';
  }

  Future<void> setAzanMode(String prayer, String mode) async {
    await _prefs.setString('azanMode_$prayer', mode);
    notifyListeners();
  }

  /// Play the azan on the alarm stream, so it is heard in silent mode too.
  bool get azanInSilent => _prefs.getBool('azanInSilent') ?? true;

  Future<void> setAzanInSilent(bool v) async {
    await _prefs.setBool('azanInSilent', v);
    notifyListeners();
  }

  /// Show the full-screen azan page (over the lock screen) while it plays.
  bool get azanFullScreen => _prefs.getBool('azanFullScreen') ?? true;

  Future<void> setAzanFullScreen(bool v) async {
    await _prefs.setBool('azanFullScreen', v);
    notifyListeners();
  }

  // ------------------------------------------------------------ stories

  /// The story that was playing last.
  String get lastStoryId => _prefs.getString('lastStory') ?? '';

  /// Where playback of story [id] stopped, and the story's length.
  Duration storyPosition(String id) => Duration(milliseconds: _prefs.getInt('storyPos_$id') ?? 0);
  Duration storyLength(String id) => Duration(milliseconds: _prefs.getInt('storyLen_$id') ?? 0);

  Future<void> saveStoryProgress(String id, Duration pos, Duration length) async {
    await _prefs.setString('lastStory', id);
    await _prefs.setInt('storyPos_$id', pos.inMilliseconds);
    if (length > Duration.zero) await _prefs.setInt('storyLen_$id', length.inMilliseconds);
    notifyListeners();
  }

  Future<void> markRead(String key) async {
    final marks = readMarks..add(key);
    // Keep the list small: only the latest 120 entries.
    final list = marks.toList()..sort();
    await _prefs.setStringList(
      'readMarks',
      list.length > 120 ? list.sublist(list.length - 120) : list,
    );
    notifyListeners();
  }
}

/// A Quran reciter whose per-ayah MP3s are on EveryAyah.com.
class Reciter {
  const Reciter(this.id, this.name);

  /// Folder name on everyayah.com/data/.
  final String id;

  /// Bangla display name.
  final String name;

  static const all = [
    Reciter('Alafasy_128kbps', 'মিশারি রাশিদ আলাফাসি'),
    Reciter('Abdul_Basit_Murattal_192kbps', 'আব্দুল বাসিত আব্দুস সামাদ'),
    Reciter('Husary_128kbps', 'মাহমুদ খলিল আল-হুসারি'),
  ];

  static Reciter byId(String id) => all.firstWhere((r) => r.id == id, orElse: () => all.first);
}
