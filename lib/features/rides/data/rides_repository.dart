import '../../../core/constants/api_paths.dart';
import '../../../core/models/geo_point.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/api_client.dart';
import 'models/ride_model.dart';

/// Rides, dispatch & tracking API (backend modules 5 & 6).
class RidesRepository {
  RidesRepository(this._api);

  final ApiClient _api;

  Ride _ride(dynamic data) => Ride.fromJson((data as Map).cast<String, dynamic>());

  // ─────────────────────────────── client ────────────────────────────────────

  Future<List<NearbyTaxi>> nearbyTaxis(GeoPoint around) async {
    final data = await _api.get(
      ApiPaths.rideNearbyDrivers,
      query: {'lat': around.lat, 'lng': around.lng},
    );
    return (data as List)
        .whereType<Map>()
        .map((e) => NearbyTaxi.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<FareEstimate> estimate(GeoPoint pickup, GeoPoint dropoff) async {
    final data = await _api.post(
      ApiPaths.rideEstimate,
      data: {'pickup': pickup.toJson(), 'dropoff': dropoff.toJson()},
    );
    return FareEstimate.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Ride> create({
    required GeoPoint pickup,
    required GeoPoint dropoff,
    required String pickupAddress,
    required String dropoffAddress,
    required PaymentMethod paymentMethod,
  }) async {
    final data = await _api.post(
      ApiPaths.rides,
      data: {
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'payment_method': paymentMethod.raw,
      },
    );
    return _ride(data);
  }

  Future<Ride> rate(int rideId, int rating, {String comment = ''}) async =>
      _ride(await _api.post(ApiPaths.rideRate(rideId), data: {'rating': rating, 'comment': comment}));

  // ─────────────────────────────── shared ────────────────────────────────────

  /// The active ride of the current user, or `null` (HTTP 204).
  Future<Ride?> current() async {
    final data = await _api.get(ApiPaths.rideCurrent);
    if (data is Map && data.isNotEmpty) return _ride(data);
    return null;
  }

  Future<Ride> byId(int id) async => _ride(await _api.get(ApiPaths.rideById(id)));

  /// [statuses] is a comma-separated list, e.g. `completed,cancelled`.
  Future<Paginated<Ride>> list({int page = 1, String? statuses, int pageSize = 20}) async {
    final data = await _api.get(
      ApiPaths.rides,
      query: {
        'page': page,
        'page_size': pageSize,
        if (statuses != null && statuses.isNotEmpty) 'status__in': statuses,
      },
    );
    return Paginated.fromJson((data as Map).cast<String, dynamic>(), Ride.fromJson);
  }

  /// Returns the updated ride for the client/admin; `null` when a driver
  /// withdrew (the ride is no longer theirs).
  Future<Ride?> cancel(int rideId, {String reason = ''}) async {
    final data = await _api.post(ApiPaths.rideCancel(rideId), data: {'reason': reason});
    if (data is Map && data.containsKey('id')) return _ride(data);
    return null;
  }

  Future<List<TrackPoint>> route(int rideId) async {
    final data = await _api.get(ApiPaths.rideRoute(rideId), query: {'page_size': 100});
    final list = data is Map ? (data['results'] as List? ?? const []) : data as List;
    return list.whereType<Map>().map((e) => TrackPoint.fromJson(e.cast<String, dynamic>())).toList();
  }

  // ─────────────────────────────── driver ────────────────────────────────────

  Future<List<RideOffer>> offers() async {
    final data = await _api.get(ApiPaths.rideOffers);
    return (data as List)
        .whereType<Map>()
        .map((e) => RideOffer.fromApi(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Ride> accept(int rideId) async => _ride(await _api.post(ApiPaths.rideAccept(rideId)));

  Future<void> reject(int rideId) => _api.post(ApiPaths.rideReject(rideId));

  Future<Ride> arrived(int rideId) async => _ride(await _api.post(ApiPaths.rideArrived(rideId)));

  Future<Ride> start(int rideId) async => _ride(await _api.post(ApiPaths.rideStart(rideId)));

  Future<Ride> complete(int rideId) async => _ride(await _api.post(ApiPaths.rideComplete(rideId)));

  /// Sends a batch of GPS fixes; returns the live totals computed server-side.
  Future<({double distanceKm, double trafficMinutes})> track(
    int rideId,
    List<Map<String, dynamic>> points,
  ) async {
    final data = await _api.post(ApiPaths.rideTrack(rideId), data: {'points': points});
    final map = (data as Map).cast<String, dynamic>();
    return (
      distanceKm: double.tryParse('${map['distance_km']}') ?? 0,
      trafficMinutes: double.tryParse('${map['traffic_minutes']}') ?? 0,
    );
  }

  // ─────────────────────────────── admin ─────────────────────────────────────

  Future<Ride> confirmPayment(int rideId, {String reference = ''}) async =>
      _ride(await _api.post(ApiPaths.rideConfirmPayment(rideId), data: {'reference': reference}));
}
