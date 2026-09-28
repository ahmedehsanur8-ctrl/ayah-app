import 'package:flutter/services.dart';

/// Compass heading from the phone's rotation sensor (MainActivity.kt).
class CompassReading {
  const CompassReading(this.heading, this.accuracy);

  /// Degrees from true north, clockwise (0–360). (The Android side corrects
  /// magnetic north with the local declination when a location is given.)
  final double heading;

  /// Android sensor accuracy: 0 unreliable, 1 low, 2 medium, 3 high.
  final int accuracy;

  bool get needsCalibration => accuracy <= 1;
}

class Compass {
  Compass._();

  static const _channel = EventChannel('ayah_reminder/compass');

  /// Readings about 20 times a second. Emits an error when the phone has no compass.
  static Stream<CompassReading> readings({double? lat, double? lng}) =>
      _channel.receiveBroadcastStream({'lat': lat, 'lng': lng}).map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return CompassReading((m['heading'] as num).toDouble(), (m['accuracy'] as num).toInt());
      });
}
