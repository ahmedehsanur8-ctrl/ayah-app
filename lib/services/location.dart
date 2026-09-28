import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'prayer.dart';
import 'settings.dart';

enum LocationResult { ok, denied, deniedForever, serviceOff, failed }

/// Finds the phone's location for prayer times and Qibla, with Android's own
/// location service (MainActivity.kt; no Google Play Services). The location
/// is only saved on the phone; it is never sent anywhere.
class LocationService {
  LocationService._();

  static const _channel = MethodChannel('ayah_reminder/location');

  static Future<T?> _call<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<({double lat, double lng})?> _position() async {
    final m = await _call<Map<Object?, Object?>>('get');
    if (m == null) return null;
    return (lat: (m['lat'] as num).toDouble(), lng: (m['lng'] as num).toDouble());
  }

  /// Asks for permission (if needed) and saves the current location.
  static Future<LocationResult> useCurrentLocation(AppSettings s) async {
    try {
      if (await _call<bool>('enabled') == false) return LocationResult.serviceOff;
      var status = await _call<String>('status');
      if (status != 'granted') status = await _call<String>('request');
      if (status == 'deniedForever') return LocationResult.deniedForever;
      if (status != 'granted') return LocationResult.denied;
      final pos = await _position();
      if (pos == null) return LocationResult.failed;
      await s.setLocation(pos.lat, pos.lng, nearbyName(pos.lat, pos.lng), 'gps');
      return LocationResult.ok;
    } catch (_) {
      return LocationResult.failed;
    }
  }

  /// On app start: when the phone's location is used and permission is still
  /// given, update it if the phone has moved more than 5 km.
  /// Returns true when the saved location changed.
  static Future<bool> refreshIfMoved(AppSettings s) async {
    if (s.locationSource != 'gps' || !s.hasLocation) return false;
    try {
      if (await _call<String>('status') != 'granted') return false;
      final pos = await _position();
      if (pos == null) return false;
      if (distanceMeters(s.latitude!, s.longitude!, pos.lat, pos.lng) < 5000) return false;
      await s.setLocation(pos.lat, pos.lng, nearbyName(pos.lat, pos.lng), 'gps');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAppSettings() => _call<bool>('openAppSettings');

  static Future<void> openLocationSettings() => _call<bool>('openLocationSettings');

  /// Great-circle distance in metres.
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }

  /// Name of the nearest listed city within 40 km, else "বর্তমান অবস্থান".
  static String nearbyName(double lat, double lng) {
    City? best;
    var bestD = double.infinity;
    for (final c in City.all) {
      final d = distanceMeters(lat, lng, c.lat, c.lng);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best != null && bestD < 40000 ? best.name : 'বর্তমান অবস্থান';
  }
}
