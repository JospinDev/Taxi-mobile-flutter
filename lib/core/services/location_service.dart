import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';

/// Shared device-location service.
///
/// Wraps `geolocator` behind a small API so both the client (to show "my
/// position" and order a ride from the right place) and the driver (to push
/// their GPS position to the backend) share the same permission logic.
class LocationService {
  const LocationService();

  /// Whether the OS-level location service is enabled on the device.
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Requests the permission and reports whether it was granted.
  ///
  /// Returns `false` when the service is off or the user refuses — the caller
  /// decides whether to degrade gracefully or block the feature.
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// A single position fix — medium accuracy is enough to place the user.
  Future<GeoPoint?> currentPosition() async {
    try {
      final granted = await requestPermission();
      if (!granted) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('[LocationService] currentPosition failed: $e');
      return null;
    }
  }

  /// Streams position updates; the caller is responsible for cancelling.
  ///
  /// The backend wants a push every 5–10 s while a driver is online, so the
  /// stream is throttled with [minInterval] instead of pushing on every raw
  /// GPS fix (which can fire several times per second).
  Stream<GeoPoint> watchPosition({
    Duration minInterval = const Duration(seconds: 6),
  }) {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    DateTime? last;
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => GeoPoint(p.latitude, p.longitude))
        .where((point) {
          final now = DateTime.now();
          // `last` is captured (and mutated) by this closure, so it is never
          // promoted to a non-nullable `DateTime` — read it into a local.
          final previous = last;
          if (previous == null || now.difference(previous) >= minInterval) {
            last = now;
            return true;
          }
          return false;
        });
  }
}
