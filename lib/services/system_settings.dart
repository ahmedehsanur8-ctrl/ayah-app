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

  static Future<bool> canUseFullScreenIntent() async =>
      await _call<bool>('canUseFullScreenIntent') ?? true;

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
