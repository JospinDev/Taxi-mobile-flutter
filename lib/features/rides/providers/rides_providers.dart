import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/api_paths.dart';
import '../../../core/models/geo_point.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/services/location_service.dart';
import '../../auth/data/models/driver_profile_model.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/providers/auth_controller.dart';
import '../../shared/providers/realtime_providers.dart';
import '../../shared/providers/repository_providers.dart';
import '../data/models/ride_model.dart';
import '../data/rides_repository.dart';

// ─────────────────────────────── device position ─────────────────────────────

final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());

/// One-shot device position (null when refused) — falls back to the city centre in UI.
class DeviceLocationNotifier extends AsyncNotifier<GeoPoint?> {
  @override
  Future<GeoPoint?> build() => ref.read(locationServiceProvider).currentPosition();

  Future<GeoPoint?> refresh() async {
    final p = await ref.read(locationServiceProvider).currentPosition();
    if (p != null) state = AsyncData(p);
    return p;
  }
}

final deviceLocationProvider = AsyncNotifierProvider<DeviceLocationNotifier, GeoPoint?>(
  DeviceLocationNotifier.new,
);

// ─────────────────────────────── nearby taxis ────────────────────────────────

/// Available taxis around the client, refreshed every 10 s while visible.
class NearbyTaxisNotifier extends AsyncNotifier<List<NearbyTaxi>> {
  Timer? _timer;

  @override
  Future<List<NearbyTaxi>> build() async {
    final center = ref.watch(deviceLocationProvider).value ?? GeoPoint.cityCenter;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _poll(center));
    ref.onDispose(() => _timer?.cancel());
    return _fetch(center);
  }

  Future<List<NearbyTaxi>> _fetch(GeoPoint center) async {
    try {
      return await ref.read(ridesRepositoryProvider).nearbyTaxis(center);
    } catch (e) {
      debugPrint('[NearbyTaxis] $e');
      return const [];
    }
  }

  Future<void> _poll(GeoPoint center) async => state = AsyncData(await _fetch(center));
}

final nearbyTaxisProvider = AsyncNotifierProvider.autoDispose<NearbyTaxisNotifier, List<NearbyTaxi>>(
  NearbyTaxisNotifier.new,
);

// ─────────────────────────────── followed ride ───────────────────────────────

/// The ride the user is following right now (client or driver).
///
/// Sources of truth, from fastest to safest:
/// 1. `ws/rides/<id>/` → live driver position (`ride.location`),
/// 2. `ws/notifications/` → status changes (`ride.status`, `ride.completed`),
/// 3. REST polling every few seconds as a fallback when sockets drop.
///
/// When the ride ends, the finished ride is kept in state (invoice, rating,
/// "no driver" message) until the UI calls [dismiss].
class CurrentRideNotifier extends AsyncNotifier<Ride?> {
  Timer? _poll;
  RealtimeClient? _rideSocket;
  StreamSubscription<RealtimeEvent>? _rideSub;
  int? _socketRideId;

  @override
  Future<Ride?> build() async {
    // Only identity changes matter: profile refreshes must not reset the ride.
    final (authenticated, role) = ref.watch(
      authControllerProvider.select((s) => (s.isAuthenticated, s.role)),
    );
    ref.onDispose(_closeRideSocket);
    ref.onDispose(() => _poll?.cancel());
    if (!authenticated || role == UserRole.admin) return null;

    final sub = ref.watch(realtimeClientProvider).events.listen((e) {
      final followed = state.value;
      final relevant = e.event == 'ride.status' ||
          e.event == 'ride.completed' ||
          (e.event == 'notification' && e.rideId != null);
      if (!relevant) return;
      if (followed == null || e.rideId == null || e.rideId == followed.id) {
        refresh();
      }
    });
    ref.onDispose(sub.cancel);

    final ride = await ref.read(ridesRepositoryProvider).current();
    _sync(ride);
    return ride;
  }

  /// Starts/stops polling and the per-ride socket according to [ride].
  void _sync(Ride? ride) {
    _poll?.cancel();
    if (ride != null && ride.status.isActive) {
      _poll = Timer.periodic(AppConfig.ridePollInterval, (_) => refresh());
    }
    if (ride != null && ride.status.hasDriver) {
      _openRideSocket(ride.id);
    } else {
      _closeRideSocket();
    }
  }

  void _openRideSocket(int rideId) {
    if (_socketRideId == rideId) return;
    _closeRideSocket();
    _socketRideId = rideId;
    final socket = RealtimeClient(
      path: ApiPaths.wsRide(rideId),
      storage: ref.read(tokenStorageProvider),
      onAuthExpired: () => ref.read(apiClientProvider).get(ApiPaths.notificationsUnread),
    );
    _rideSocket = socket;
    _rideSub = socket.events.listen((e) {
      final current = state.value;
      if (current == null || current.id != rideId) return;
      if (e.event == 'ride.location') {
        final lat = (e.data['lat'] as num?)?.toDouble();
        final lng = (e.data['lng'] as num?)?.toDouble();
        state = AsyncData(
          current.withLive(
            driverLocation: lat != null && lng != null ? GeoPoint(lat, lng) : null,
            distanceKm: (e.data['distance_km'] as num?)?.toDouble(),
            trafficMinutes: (e.data['traffic_minutes'] as num?)?.toDouble(),
          ),
        );
      } else if (e.event == 'ride.status' || e.event == 'ride.completed') {
        refresh();
      }
    });
    socket.connect();
  }

  void _closeRideSocket() {
    _rideSub?.cancel();
    _rideSub = null;
    _rideSocket?.dispose();
    _rideSocket = null;
    _socketRideId = null;
  }

  RidesRepository get _rides => ref.read(ridesRepositoryProvider);

  void _set(Ride? ride) {
    state = AsyncData(ride);
    _sync(ride);
  }

  /// Re-reads the ride. If it just ended, keeps the final version on screen.
  Future<void> refresh() async {
    final previous = state.value;
    try {
      var ride = await _rides.current();
      if (ride == null && previous != null && previous.status.isActive) {
        try {
          ride = await _rides.byId(previous.id);
        } catch (_) {
          ride = null; // e.g. the driver withdrew: the ride is not theirs anymore
        }
      }
      if (ride == null && previous != null && previous.status.isFinished) return;
      // Keep the live position until the server catches up.
      if (ride != null && previous != null && ride.id == previous.id && ride.driverLocation == null) {
        ride = ride.withLive(driverLocation: previous.driverLocation);
      }
      _set(ride);
    } catch (e) {
      debugPrint('[CurrentRide] refresh failed: $e');
    }
  }

  // ── client ────────────────────────────────────────────────────────────────

  Future<Ride> order({
    required GeoPoint pickup,
    required GeoPoint dropoff,
    required String pickupAddress,
    required String dropoffAddress,
    required PaymentMethod paymentMethod,
  }) async {
    final ride = await _rides.create(
      pickup: pickup,
      dropoff: dropoff,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      paymentMethod: paymentMethod,
    );
    _set(ride);
    return ride;
  }

  Future<void> cancel({String reason = ''}) async {
    final ride = state.value;
    if (ride == null) return;
    final updated = await _rides.cancel(ride.id, reason: reason);
    _set(updated); // null when a driver withdrew
  }

  Future<void> rate(int rating, {String comment = ''}) async {
    final ride = state.value;
    if (ride == null) return;
    _set(await _rides.rate(ride.id, rating, comment: comment));
  }

  // ── driver ────────────────────────────────────────────────────────────────

  void adopt(Ride ride) => _set(ride);

  Future<void> markArrived() async => _set(await _rides.arrived(state.value!.id));

  Future<void> start() async => _set(await _rides.start(state.value!.id));

  Future<void> complete() async {
    final id = state.value!.id;
    await ref.read(driverTrackerProvider).flush();
    _set(await _rides.complete(id));
  }

  /// Clears a finished ride from the screen.
  void dismiss() => _set(null);
}

final currentRideProvider = AsyncNotifierProvider<CurrentRideNotifier, Ride?>(
  CurrentRideNotifier.new,
);

// ─────────────────────────────── driver offers ───────────────────────────────

/// Pending offers for the driver: pushed by `ride.offer`, removed by
/// `ride.offer_closed`, and polled while online as a safety net.
class DriverOffersNotifier extends Notifier<List<RideOffer>> {
  Timer? _poll;
  Timer? _prune;

  @override
  List<RideOffer> build() {
    final (role, status) = ref.watch(
      authControllerProvider.select((s) => (s.role, s.driverProfile?.status)),
    );
    ref.onDispose(() {
      _poll?.cancel();
      _prune?.cancel();
    });
    if (role != UserRole.driver || status != DriverStatus.available) return const [];

    final sub = ref.watch(realtimeClientProvider).events.listen((e) {
      if (e.event == 'ride.offer') {
        final offer = RideOffer.fromEvent(e.data);
        state = [offer, ...state.where((o) => o.rideId != offer.rideId)];
      } else if (e.event == 'ride.offer_closed') {
        remove(e.rideId);
      }
    });
    ref.onDispose(sub.cancel);

    _poll = Timer.periodic(AppConfig.offersPollInterval, (_) => _fetch());
    _prune = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.any((o) => o.isExpired)) state = state.where((o) => !o.isExpired).toList();
    });
    Future.microtask(_fetch);
    return const [];
  }

  Future<void> _fetch() async {
    if (ref.read(currentRideProvider).value?.status.isActive ?? false) {
      if (state.isNotEmpty) state = const [];
      return;
    }
    try {
      final fresh = await ref.read(ridesRepositoryProvider).offers();
      final known = {for (final o in state) o.rideId: o};
      // Keep the countdown of offers we already display.
      state = [for (final o in fresh) known[o.rideId] ?? o];
    } catch (_) {}
  }

  void remove(int? rideId) => state = state.where((o) => o.rideId != rideId).toList();

  Future<Ride> accept(RideOffer offer) async {
    try {
      final ride = await ref.read(ridesRepositoryProvider).accept(offer.rideId);
      state = const [];
      ref.read(currentRideProvider.notifier).adopt(ride);
      await ref.read(authControllerProvider.notifier).refreshDriverProfile();
      return ride;
    } catch (e) {
      remove(offer.rideId); // taken by someone else / expired
      rethrow;
    }
  }

  Future<void> reject(RideOffer offer) async {
    remove(offer.rideId);
    try {
      await ref.read(ridesRepositoryProvider).reject(offer.rideId);
    } catch (_) {}
  }
}

final driverOffersProvider = NotifierProvider<DriverOffersNotifier, List<RideOffer>>(
  DriverOffersNotifier.new,
);

// ─────────────────────────────── driver GPS tracker ──────────────────────────

/// Streams the driver's GPS during an assigned ride and sends it in batches
/// to `rides/{id}/track/` (driver position for the client + real km/traffic).
///
/// Lives as long as the driver has an active ride, even if they leave the
/// ride screen. Failed batches are kept and retried (offline tolerant).
class DriverRideTracker {
  DriverRideTracker(this._ref);

  final Ref _ref;
  StreamSubscription<Position>? _gps;
  Timer? _flushTimer;
  int? _rideId;
  final List<Map<String, dynamic>> _buffer = [];
  bool _sending = false;

  final ValueNotifier<GeoPoint?> position = ValueNotifier(null);
  final ValueNotifier<double> heading = ValueNotifier(0);
  final ValueNotifier<({double km, double trafficMin})> live = ValueNotifier((km: 0, trafficMin: 0));

  bool get isRunning => _rideId != null;

  Future<void> start(int rideId) async {
    if (_rideId == rideId) return;
    await stop();
    _rideId = rideId;
    live.value = (km: 0, trafficMin: 0);
    if (!await _ref.read(locationServiceProvider).requestPermission()) return;

    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
    ).listen((p) {
      final point = GeoPoint(p.latitude, p.longitude);
      position.value = point;
      if (p.heading > 0) heading.value = p.heading;
      _buffer.add({
        'lat': p.latitude,
        'lng': p.longitude,
        'recorded_at': p.timestamp.toUtc().toIso8601String(),
        if (p.accuracy > 0) 'accuracy': p.accuracy,
        if (p.heading >= 0 && p.heading <= 360) 'heading': p.heading,
      });
      if (_buffer.length > 500) _buffer.removeRange(0, _buffer.length - 500);
    }, onError: (Object e) => debugPrint('[Tracker] GPS error: $e'));

    _flushTimer = Timer.periodic(AppConfig.rideTrackInterval, (_) => flush());
  }

  /// Sends the buffered points now (also called just before "complete").
  Future<void> flush() async {
    final rideId = _rideId;
    if (rideId == null || _buffer.isEmpty || _sending) return;
    _sending = true;
    final batch = _buffer.take(100).toList();
    try {
      final totals = await _ref.read(ridesRepositoryProvider).track(rideId, batch);
      _buffer.removeRange(0, batch.length);
      live.value = (km: totals.distanceKm, trafficMin: totals.trafficMinutes);
    } catch (e) {
      debugPrint('[Tracker] batch kept for retry: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> stop() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _gps?.cancel();
    _gps = null;
    _rideId = null;
    _buffer.clear();
  }
}

/// Starts/stops the tracker from the driver's current ride.
final driverTrackerProvider = Provider<DriverRideTracker>((ref) {
  final tracker = DriverRideTracker(ref);
  ref.listen<AsyncValue<Ride?>>(currentRideProvider, (_, next) {
    final isDriver = ref.read(authControllerProvider).role == UserRole.driver;
    final ride = next.value;
    if (isDriver && ride != null && ride.status.hasDriver) {
      tracker.start(ride.id);
    } else if (tracker.isRunning) {
      tracker.stop();
    }
  }, fireImmediately: true);
  ref.onDispose(tracker.stop);
  return tracker;
});

// ─────────────────────────────── history ─────────────────────────────────────

class RideListState {
  const RideListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.filter,
  });

  final List<Ride> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  /// Comma-separated statuses, null = all.
  final String? filter;

  RideListState copyWith({List<Ride>? items, int? page, bool? hasMore, bool? loadingMore}) => RideListState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    filter: filter,
  );
}

/// Ride list with filter + infinite scroll (client & driver history, admin).
class RideListNotifier extends AsyncNotifier<RideListState> {
  String? _filter;

  @override
  Future<RideListState> build() async {
    final page = await ref.read(ridesRepositoryProvider).list(statuses: _filter);
    return RideListState(items: page.results, page: 1, hasMore: page.hasNext, filter: _filter);
  }

  Future<void> setFilter(String? statuses) async {
    _filter = statuses;
    state = const AsyncLoading<RideListState>();
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final next = await ref.read(ridesRepositoryProvider).list(page: s.page + 1, statuses: _filter);
      state = AsyncData(
        s.copyWith(items: [...s.items, ...next.results], page: s.page + 1, hasMore: next.hasNext, loadingMore: false),
      );
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
    }
  }

  /// Replaces one ride after an admin action.
  void replace(Ride ride) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(items: [for (final r in s.items) r.id == ride.id ? ride : r]));
  }
}

final rideListProvider = AsyncNotifierProvider.autoDispose<RideListNotifier, RideListState>(
  RideListNotifier.new,
);

/// One ride (detail screen).
final rideDetailProvider = FutureProvider.autoDispose.family<Ride, int>(
  (ref, id) => ref.read(ridesRepositoryProvider).byId(id),
);

/// GPS trace of a ride (detail map).
final rideRouteProvider = FutureProvider.autoDispose.family<List<TrackPoint>, int>(
  (ref, id) => ref.read(ridesRepositoryProvider).route(id),
);
