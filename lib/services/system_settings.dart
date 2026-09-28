import 'package:flutter/services.dart';

/// Talks to the Android code in MainActivity.kt for phone settings that the
/// notification plugin does not cover.
class SystemSettings {
  static const _channel = MethodChannel('ayah_reminder/system');

  static Future<bool> isIgnoringBatteryOptimizations() async =>
      await _call<bool>('isIgnoringBatteryOptimizations') ?? false;

  static Future<void> requestIgnoreBatteryOptimizations() =>
      _call<bool>('requestIgnoreBatteryOptimizations');

  /// Returns true if the phone maker's autostart page was opened.
  static Future<bool> openAutostartSettings() async =>
      await _call<bool>('openAutostartSettings') ?? false;

  /// Opens the phone's text-to-speech settings.
  static Future<void> openTtsSettings() => _call<bool>('openTtsSettings');

  static Future<bool> canUseFullScreenIntent() async =>
      await _call<bool>('canUseFullScreenIntent') ?? true;

  static Future<void> openFullScreenSettings() => _call<bool>('openFullScreenSettings');

  static Future<bool> notificationsEnabled() async =>
      await _call<bool>('notificationsEnabled') ?? true;

  static Future<void> openNotificationSettings() => _call<bool>('openNotificationSettings');

  static Future<bool> canScheduleExactAlarms() async =>
      await _call<bool>('canScheduleExactAlarms') ?? true;

  static Future<void> openExactAlarmSettings() => _call<bool>('openExactAlarmSettings');

  /// "Display over other apps".
  static Future<bool> canDrawOverlays() async => await _call<bool>('canDrawOverlays') ?? true;

  static Future<void> openOverlaySettings() => _call<bool>('openOverlaySettings');

  /// The app's own "App info" page.
  static Future<void> openAppDetails() => _call<bool>('openAppDetails');

  /// Xiaomi "Other permissions" (lock screen, pop-up windows).
  static Future<void> openMiuiPermissions() => _call<bool>('openMiuiPermissions');

  /// The list of apps and their battery optimisation.
  static Future<void> openBatterySettings() => _call<bool>('openBatterySettings');

  /// Samsung Device care → Battery (sleeping apps).
  static Future<void> openSamsungBattery() => _call<bool>('openSamsungBattery');

  /// e.g. "OPPO", "Xiaomi", "samsung".
  static Future<String> manufacturer() async => await _call<String>('manufacturer') ?? '';

  static Future<T?> _call<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
