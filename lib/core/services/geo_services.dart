import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/geo_point.dart';

/// A place returned by the address search (Nominatim / OpenStreetMap).
class Place {
  const Place({required this.title, required this.subtitle, required this.point});

  final String title;
  final String subtitle;
  final GeoPoint point;

  String get label => subtitle.isEmpty ? title : '$title, $subtitle';
}

/// A drivable route between two points (OSRM).
class RoutePath {
  const RoutePath({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isApproximation = false,
  });

  final List<GeoPoint> points;
  final double distanceMeters;
  final double durationSeconds;

  /// `true` when the routing service was unreachable and a straight line is drawn.
  final bool isApproximation;

  int get etaMinutes => (durationSeconds / 60).ceil().clamp(1, 999);
  double get distanceKm => distanceMeters / 1000;
}

/// Address search + reverse geocoding + road routing on free OSM services.
///
/// * Nominatim: max 1 request/s, a real User-Agent is mandatory.
/// * OSRM demo server: fine for development; use a self-hosted OSRM (or a paid
///   provider) in production.
/// All calls degrade gracefully: the app keeps working without them.
class GeoServices {
  GeoServices()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'User-Agent': AppConfig.osmUserAgent},
        ),
      );

  final Dio _dio;
  final Map<String, String> _reverseCache = {};

  static const _nominatim = 'https://nominatim.openstreetmap.org';
  static const _osrm = 'https://router.project-osrm.org';

  /// Searches places, biased around [near] (Burundi by default).
  Future<List<Place>> search(String query, {GeoPoint? near}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    try {
      final center = near ?? GeoPoint.cityCenter;
      final res = await _dio.get(
        '$_nominatim/search',
        queryParameters: {
          'q': q,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 8,
          'accept-language': 'fr',
          'countrycodes': 'bi',
          // ~25 km box around the user: results nearby first.
          'viewbox':
              '${center.lng - .25},${center.lat + .25},${center.lng + .25},${center.lat - .25}',
        },
      );
      return (res.data as List)
          .whereType<Map>()
          .map((e) => _placeFrom(e.cast<String, dynamic>()))
          .whereType<Place>()
          .toList();
    } catch (e) {
      debugPrint('[GeoServices] search failed: $e');
      return const [];
    }
  }

  /// Human-readable label of a point ("Avenue de l'Université, Rohero").
  Future<String?> reverse(GeoPoint point) async {
    final key = '${point.lat.toStringAsFixed(4)},${point.lng.toStringAsFixed(4)}';
    final cached = _reverseCache[key];
    if (cached != null) return cached;
    try {
      final res = await _dio.get(
        '$_nominatim/reverse',
        queryParameters: {
          'lat': point.lat,
          'lon': point.lng,
          'format': 'jsonv2',
          'zoom': 17,
          'accept-language': 'fr',
        },
      );
      final place = _placeFrom((res.data as Map).cast<String, dynamic>());
      if (place == null) return null;
      return _reverseCache[key] = place.label;
    } catch (e) {
      debugPrint('[GeoServices] reverse failed: $e');
      return null;
    }
  }

  /// Road route [from] → [to]. Falls back to a straight line when offline.
  Future<RoutePath> route(GeoPoint from, GeoPoint to) async {
    try {
      final res = await _dio.get(
        '$_osrm/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final routes = (res.data as Map)['routes'] as List;
      if (routes.isEmpty) throw StateError('no route');
      final route = (routes.first as Map).cast<String, dynamic>();
      final coords = ((route['geometry'] as Map)['coordinates'] as List)
          .map((c) => GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return RoutePath(
        points: coords,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('[GeoServices] route failed, straight line: $e');
      final meters = from.distanceTo(to) * 1.3;
      return RoutePath(
        points: [from, to],
        distanceMeters: meters,
        durationSeconds: GeoPoint.etaMinutesFor(meters) * 60.0,
        isApproximation: true,
      );
    }
  }

  static Place? _placeFrom(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lng = double.tryParse('${json['lon']}');
    if (lat == null || lng == null) return null;
    final address = (json['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = '${json['name'] ?? ''}'.trim();
    final road = address['road'] ?? address['pedestrian'] ?? address['street'];
    final area =
        address['suburb'] ??
        address['neighbourhood'] ??
        address['quarter'] ??
        address['city_district'];
    final city = address['city'] ?? address['town'] ?? address['village'];

    final title = name.isNotEmpty ? name : '${road ?? area ?? city ?? 'Lieu'}';
    final parts = <String>[
      if (name.isNotEmpty && road != null) '$road',
      if (area != null && '$area' != title) '$area',
      if (city != null && '$city' != title) '$city',
    ];
    return Place(title: title, subtitle: parts.join(', '), point: GeoPoint(lat, lng));
  }
}
