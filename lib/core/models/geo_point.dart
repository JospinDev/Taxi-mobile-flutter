import 'dart:math' as math;

/// A WGS-84 geographic coordinate (the format used by OSM, GPS and the API).
///
/// The backend stores driver positions as PostGIS points
/// (`SRID=4326;POINT (lng lat)`); [fromPostgis] parses that string form and
/// [toPostgis] produces it again.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Default centre of the map when the device position is unknown
  /// (Bujumbura, Burundi).
  static const GeoPoint cityCenter = GeoPoint(-3.3614, 29.3599);

  /// Parses `SRID=4326;POINT (29.3644 -3.3821)` → a [GeoPoint].
  static GeoPoint? fromPostgis(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return null;
    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lng == null || lat == null) return null;
    return GeoPoint(lat, lng);
  }

  /// Serializes to the PostGIS WKT representation used by the API.
  String toPostgis() => 'SRID=4326;POINT ($lng $lat)';

  /// Great-circle distance to [other], in metres.
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.lat - lat);
    final dLng = _rad(other.lng - lng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(other.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Initial bearing towards [other], in degrees (0 = north, clockwise).
  double bearingTo(GeoPoint other) {
    final dLng = _rad(other.lng - lng);
    final y = math.sin(dLng) * math.cos(_rad(other.lat));
    final x =
        math.cos(_rad(lat)) * math.sin(_rad(other.lat)) -
        math.sin(_rad(lat)) * math.cos(_rad(other.lat)) * math.cos(dLng);
    return (_radToDeg(math.atan2(y, x)) + 360) % 360;
  }

  /// Straight-line interpolation towards [other] by [ratio] (0 → this, 1 → other).
  GeoPoint lerp(GeoPoint other, double ratio) => GeoPoint(
    lat + (other.lat - lat) * ratio,
    lng + (other.lng - lng) * ratio,
  );

  /// A point [meters] away from this one, along [bearing] degrees.
  GeoPoint offset(double meters, double bearing) {
    const earthRadius = 6371000.0;
    final angular = meters / earthRadius;
    final theta = _rad(bearing);
    final phi1 = _rad(lat);
    final lambda1 = _rad(lng);
    final phi2 = math.asin(
      math.sin(phi1) * math.cos(angular) +
          math.cos(phi1) * math.sin(angular) * math.cos(theta),
    );
    final lambda2 =
        lambda1 +
        math.atan2(
          math.sin(theta) * math.sin(angular) * math.cos(phi1),
          math.cos(angular) - math.sin(phi1) * math.sin(phi2),
        );
    return GeoPoint(_radToDeg(phi2), _radToDeg(lambda2));
  }

  /// Rough ETA in minutes for a trip of [meters], at ~22 km/h average speed.
  static int etaMinutesFor(double meters) {
    final minutes = (meters / 1000 / 22 * 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  /// Rough ETA in minutes to reach [other] from this point.
  int etaMinutesTo(GeoPoint other) => GeoPoint.etaMinutesFor(distanceTo(other));

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';

  static double _rad(double deg) => deg * math.pi / 180;
  static double _radToDeg(double rad) => rad * 180 / math.pi;
}
