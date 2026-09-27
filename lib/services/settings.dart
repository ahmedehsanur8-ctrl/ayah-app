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
