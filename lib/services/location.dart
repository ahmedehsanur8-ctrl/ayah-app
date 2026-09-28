import 'package:geolocator/geolocator.dart';

import 'prayer.dart';
import 'settings.dart';

enum LocationResult { ok, denied, deniedForever, serviceOff, failed }

/// Finds the phone's location for prayer times and Qibla. The location is
/// only saved on the phone; it is never sent anywhere.
class LocationService {
  LocationService._();

  /// Asks for permission (if needed) and saves the current location.
  static Future<LocationResult> useCurrentLocation(AppSettings s) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationResult.serviceOff;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return LocationResult.deniedForever;
      if (perm == LocationPermission.denied) return LocationResult.denied;
      final pos = await _position();
      if (pos == null) return LocationResult.failed;
      await s.setLocation(
        pos.latitude,
        pos.longitude,
        nearbyName(pos.latitude, pos.longitude),
        'gps',
      );
      return LocationResult.ok;
    } catch (_) {
      return LocationResult.failed;
    }
  }

  static Future<Position?> _position() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 20),
          forceLocationManager: true,
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
    }
  }

  /// On app start: when the phone's location is used and permission is still
  /// given, update it if the phone has moved more than 5 km.
  /// Returns true when the saved location changed.
  static Future<bool> refreshIfMoved(AppSettings s) async {
    if (s.locationSource != 'gps' || !s.hasLocation) return false;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return false;
      final pos = await _position();
      if (pos == null) return false;
      final moved = Geolocator.distanceBetween(
        s.latitude!,
        s.longitude!,
        pos.latitude,
        pos.longitude,
      );
      if (moved < 5000) return false;
      await s.setLocation(
        pos.latitude,
        pos.longitude,
        nearbyName(pos.latitude, pos.longitude),
        'gps',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAppSettings() => Geolocator.openAppSettings();

  static Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Name of the nearest listed city within 40 km, else "বর্তমান অবস্থান".
  static String nearbyName(double lat, double lng) {
    City? best;
    var bestD = double.infinity;
    for (final c in City.all) {
      final d = Geolocator.distanceBetween(lat, lng, c.lat, c.lng);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best != null && bestD < 40000 ? best.name : 'বর্তমান অবস্থান';
  }
}
