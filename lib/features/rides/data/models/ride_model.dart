import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/geo_point.dart';

/// Ride lifecycle, mirrors `Ride.Status` on the backend.
enum RideStatus {
  searching('searching', 'Recherche d\'un chauffeur', Icons.radar_rounded),
  accepted('accepted', 'Chauffeur en route', Icons.directions_car_rounded),
  arrived('arrived', 'Chauffeur arrivé', Icons.where_to_vote_rounded),
  inProgress('in_progress', 'Course en cours', Icons.route_rounded),
  completed('completed', 'Terminée', Icons.check_circle_rounded),
  cancelled('cancelled', 'Annulée', Icons.cancel_rounded),
  noDriver('no_driver', 'Aucun chauffeur', Icons.search_off_rounded);

  const RideStatus(this.raw, this.label, this.icon);

  final String raw;
  final String label;
  final IconData icon;

  static RideStatus parse(Object? value) =>
      values.firstWhere((s) => s.raw == '$value', orElse: () => RideStatus.searching);

  bool get isActive => this == searching || this == accepted || this == arrived || this == inProgress;
  bool get hasDriver => this == accepted || this == arrived || this == inProgress;
  bool get isFinished => !isActive;

  /// Client may cancel before the trip starts.
  bool get clientCanCancel => this == searching || this == accepted || this == arrived;

  /// Driver may withdraw (the ride goes back to dispatch) before the trip starts.
  bool get driverCanCancel => this == accepted || this == arrived;

  Color get color => switch (this) {
    searching => AppColors.brandDeep,
    accepted || arrived => AppColors.info,
    inProgress => AppColors.emerald,
    completed => AppColors.emeraldDeep,
    cancelled || noDriver => AppColors.danger,
  };

  /// Index in the 4-step progress timeline.
  int get step => switch (this) {
    searching => 0,
    accepted => 1,
    arrived => 2,
    inProgress => 3,
    _ => 4,
  };
}

enum PaymentMethod {
  cash('cash', 'Espèces', Icons.payments_rounded),
  mobileMoney('mobile_money', 'Mobile money', Icons.phone_android_rounded);

  const PaymentMethod(this.raw, this.label, this.icon);

  final String raw;
  final String label;
  final IconData icon;

  static PaymentMethod parse(Object? v) =>
      values.firstWhere((m) => m.raw == '$v', orElse: () => PaymentMethod.cash);
}

double? _d(Object? v) => v == null ? null : double.tryParse('$v');
int? _i(Object? v) => v == null ? null : int.tryParse('$v');

GeoPoint? _point(Object? raw) {
  if (raw is Map) {
    final lat = _d(raw['lat']);
    final lng = _d(raw['lng']);
    if (lat != null && lng != null) return GeoPoint(lat, lng);
  }
  if (raw is String) return GeoPoint.fromPostgis(raw);
  return null;
}

class RideParty {
  const RideParty({required this.id, required this.name, this.phone, this.rating, this.location});

  final int id;
  final String name;
  final String? phone;
  final double? rating;
  final GeoPoint? location;

  factory RideParty.fromJson(Map<String, dynamic> j) => RideParty(
    id: _i(j['id']) ?? 0,
    name: '${j['name'] ?? ''}',
    phone: j['phone'] as String?,
    rating: _d(j['rating']),
    location: _point(j['location']),
  );

  RideParty withLocation(GeoPoint? location) =>
      RideParty(id: id, name: name, phone: phone, rating: rating, location: location ?? this.location);
}

class RideVehicle {
  const RideVehicle({
    required this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.color,
  });

  final int id;
  final String plate;
  final String brand;
  final String model;
  final String color;

  String get label => '$brand $model'.trim();

  factory RideVehicle.fromJson(Map<String, dynamic> j) => RideVehicle(
    id: _i(j['id']) ?? 0,
    plate: '${j['plate_number'] ?? ''}',
    brand: '${j['brand'] ?? ''}',
    model: '${j['model'] ?? ''}',
    color: '${j['color'] ?? ''}',
  );
}

/// A ride, as serialized by `RideSerializer`.
class Ride {
  const Ride({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.client,
    this.driver,
    this.vehicle,
    this.estimatedDistanceKm,
    this.estimatedFare,
    this.liveDistanceKm = 0,
    this.liveTrafficMinutes = 0,
    this.actualDistanceKm,
    this.trafficMinutes,
    this.distanceFallback = false,
    this.durationSeconds,
    this.fareBase,
    this.fareKm,
    this.fareTraffic,
    this.fareTotal,
    this.commissionPercent,
    this.commissionAmount,
    this.driverEarning,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = 'pending',
    this.clientRating,
    this.clientComment = '',
    this.cancelledBy = '',
    this.cancelReason = '',
    this.requestedAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final int id;
  final RideStatus status;
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final String pickupAddress;
  final String dropoffAddress;
  final RideParty? client;
  final RideParty? driver;
  final RideVehicle? vehicle;

  final double? estimatedDistanceKm;
  final double? estimatedFare;
  final double liveDistanceKm;
  final double liveTrafficMinutes;

  final double? actualDistanceKm;
  final double? trafficMinutes;
  final bool distanceFallback;
  final int? durationSeconds;
  final double? fareBase;
  final double? fareKm;
  final double? fareTraffic;
  final double? fareTotal;
  final double? commissionPercent;
  final double? commissionAmount;
  final double? driverEarning;

  final PaymentMethod paymentMethod;
  final String paymentStatus;
  final int? clientRating;
  final String clientComment;
  final String cancelledBy;
  final String cancelReason;

  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  bool get isPaid => paymentStatus == 'paid';
  GeoPoint? get driverLocation => driver?.location;

  /// Amount to show: final fare once completed, otherwise the estimate.
  double get displayFare => fareTotal ?? estimatedFare ?? 0;

  String get pickupLabel => pickupAddress.isEmpty ? 'Point de départ' : pickupAddress;
  String get dropoffLabel => dropoffAddress.isEmpty ? 'Destination' : dropoffAddress;

  factory Ride.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? m(Object? v) => v is Map ? v.cast<String, dynamic>() : null;
    DateTime? t(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    final client = m(j['client']);
    final driver = m(j['driver']);
    final vehicle = m(j['vehicle']);
    return Ride(
      id: _i(j['id']) ?? 0,
      status: RideStatus.parse(j['status']),
      pickup: _point(j['pickup']) ?? GeoPoint.cityCenter,
      dropoff: _point(j['dropoff']) ?? GeoPoint.cityCenter,
      pickupAddress: '${j['pickup_address'] ?? ''}',
      dropoffAddress: '${j['dropoff_address'] ?? ''}',
      client: client == null ? null : RideParty.fromJson(client),
      driver: driver == null ? null : RideParty.fromJson(driver),
      vehicle: vehicle == null ? null : RideVehicle.fromJson(vehicle),
      estimatedDistanceKm: _d(j['estimated_distance_km']),
      estimatedFare: _d(j['estimated_fare']),
      liveDistanceKm: _d(j['live_distance_km']) ?? 0,
      liveTrafficMinutes: _d(j['live_traffic_minutes']) ?? 0,
      actualDistanceKm: _d(j['actual_distance_km']),
      trafficMinutes: _d(j['traffic_minutes']),
      distanceFallback: j['distance_fallback'] == true,
      durationSeconds: _i(j['duration_seconds']),
      fareBase: _d(j['fare_base']),
      fareKm: _d(j['fare_km']),
      fareTraffic: _d(j['fare_traffic']),
      fareTotal: _d(j['fare_total']),
      commissionPercent: _d(j['commission_percent']),
      commissionAmount: _d(j['commission_amount']),
      driverEarning: _d(j['driver_earning']),
      paymentMethod: PaymentMethod.parse(j['payment_method']),
      paymentStatus: '${j['payment_status'] ?? 'pending'}',
      clientRating: _i(j['client_rating']),
      clientComment: '${j['client_comment'] ?? ''}',
      cancelledBy: '${j['cancelled_by'] ?? ''}',
      cancelReason: '${j['cancel_reason'] ?? ''}',
      requestedAt: t(j['requested_at']),
      acceptedAt: t(j['accepted_at']),
      arrivedAt: t(j['arrived_at']),
      startedAt: t(j['started_at']),
      completedAt: t(j['completed_at']),
      cancelledAt: t(j['cancelled_at']),
    );
  }

  /// Applies a live `ride.location` WebSocket payload.
  Ride withLive({GeoPoint? driverLocation, double? distanceKm, double? trafficMinutes}) => Ride(
    id: id,
    status: status,
    pickup: pickup,
    dropoff: dropoff,
    pickupAddress: pickupAddress,
    dropoffAddress: dropoffAddress,
    client: client,
    driver: driver?.withLocation(driverLocation),
    vehicle: vehicle,
    estimatedDistanceKm: estimatedDistanceKm,
    estimatedFare: estimatedFare,
    liveDistanceKm: distanceKm ?? liveDistanceKm,
    liveTrafficMinutes: trafficMinutes ?? liveTrafficMinutes,
    actualDistanceKm: actualDistanceKm,
    trafficMinutes: this.trafficMinutes,
    distanceFallback: distanceFallback,
    durationSeconds: durationSeconds,
    fareBase: fareBase,
    fareKm: fareKm,
    fareTraffic: fareTraffic,
    fareTotal: fareTotal,
    commissionPercent: commissionPercent,
    commissionAmount: commissionAmount,
    driverEarning: driverEarning,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    clientRating: clientRating,
    clientComment: clientComment,
    cancelledBy: cancelledBy,
    cancelReason: cancelReason,
    requestedAt: requestedAt,
    acceptedAt: acceptedAt,
    arrivedAt: arrivedAt,
    startedAt: startedAt,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
  );
}

/// A ride proposed to the driver (`GET rides/offers/` or WS `ride.offer`).
class RideOffer {
  const RideOffer({
    required this.rideId,
    required this.pickup,
    required this.dropoff,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.estimatedFare,
    required this.estimatedDistanceKm,
    required this.distanceToPickupM,
    required this.receivedAt,
    this.expiresIn = const Duration(seconds: 20),
    this.paymentMethod = PaymentMethod.cash,
  });

  final int rideId;
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final String pickupAddress;
  final String dropoffAddress;
  final double estimatedFare;
  final double estimatedDistanceKm;
  final double distanceToPickupM;
  final DateTime receivedAt;
  final Duration expiresIn;
  final PaymentMethod paymentMethod;

  DateTime get expiresAt => receivedAt.add(expiresIn);

  Duration get remaining {
    final r = expiresAt.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  bool get isExpired => remaining == Duration.zero;

  /// From the REST list (`RideOfferSerializer`). The offer stays acceptable
  /// while the ride is searching, so a late-discovered offer gets a fresh
  /// countdown instead of appearing already expired.
  factory RideOffer.fromApi(Map<String, dynamic> j) => RideOffer(
    rideId: _i(j['ride']) ?? 0,
    pickup: _point(j['pickup']) ?? GeoPoint.cityCenter,
    dropoff: _point(j['dropoff']) ?? GeoPoint.cityCenter,
    pickupAddress: '${j['pickup_address'] ?? ''}',
    dropoffAddress: '${j['dropoff_address'] ?? ''}',
    estimatedFare: _d(j['estimated_fare']) ?? 0,
    estimatedDistanceKm: _d(j['estimated_distance_km']) ?? 0,
    distanceToPickupM: _d(j['distance_m']) ?? 0,
    receivedAt: DateTime.now(),
    paymentMethod: PaymentMethod.parse(j['payment_method']),
  );

  /// From the WebSocket `ride.offer` event.
  factory RideOffer.fromEvent(Map<String, dynamic> j) => RideOffer(
    rideId: _i(j['ride_id']) ?? 0,
    pickup: _point(j['pickup']) ?? GeoPoint.cityCenter,
    dropoff: _point(j['dropoff']) ?? GeoPoint.cityCenter,
    pickupAddress: '${j['pickup_address'] ?? ''}',
    dropoffAddress: '${j['dropoff_address'] ?? ''}',
    estimatedFare: _d(j['estimated_fare']) ?? 0,
    estimatedDistanceKm: _d(j['estimated_distance_km']) ?? 0,
    distanceToPickupM: _d(j['distance_to_pickup_m']) ?? 0,
    receivedAt: DateTime.now(),
    expiresIn: Duration(seconds: _i(j['expires_in_s']) ?? 20),
  );
}

class FareEstimate {
  const FareEstimate({required this.distanceKm, required this.fare, required this.currency});

  final double distanceKm;
  final double fare;
  final String currency;

  factory FareEstimate.fromJson(Map<String, dynamic> j) => FareEstimate(
    distanceKm: _d(j['distance_km']) ?? 0,
    fare: _d(j['fare']) ?? 0,
    currency: '${j['currency'] ?? 'BIF'}',
  );
}

/// An available taxi around the client (anonymous).
class NearbyTaxi {
  const NearbyTaxi({required this.id, required this.position, required this.distanceM});

  final int id;
  final GeoPoint position;
  final double distanceM;

  int get etaMinutes => GeoPoint.etaMinutesFor(distanceM * 1.3);

  factory NearbyTaxi.fromJson(Map<String, dynamic> j) => NearbyTaxi(
    id: _i(j['id']) ?? 0,
    position: GeoPoint(_d(j['lat']) ?? 0, _d(j['lng']) ?? 0),
    distanceM: _d(j['distance_m']) ?? 0,
  );
}

class TrackPoint {
  const TrackPoint({required this.point, required this.speedKmh, required this.isTraffic});

  final GeoPoint point;
  final double speedKmh;
  final bool isTraffic;

  factory TrackPoint.fromJson(Map<String, dynamic> j) => TrackPoint(
    point: GeoPoint(_d(j['lat']) ?? 0, _d(j['lng']) ?? 0),
    speedKmh: _d(j['speed_kmh']) ?? 0,
    isTraffic: j['is_traffic'] == true,
  );
}
