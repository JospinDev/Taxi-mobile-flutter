import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/services/geo_services.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../rides/data/models/ride_model.dart';
import '../../../rides/presentation/widgets/place_search_sheet.dart';
import '../../../rides/presentation/widgets/ride_widgets.dart';
import '../../../rides/providers/rides_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/map_markers.dart';
import '../../../shared/widgets/real_map_view.dart';

/// Which point the user is currently placing by dragging the map.
enum _PickTarget { none, pickup, dropoff }

/// CLIENT home: real map with the taxis around, destination search, road
/// route + fare estimate, payment choice and order.
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  final _map = AppMapController();

  GeoPoint? _pickup;
  String _pickupLabel = 'Ma position';
  GeoPoint? _dropoff;
  String _dropoffLabel = '';

  RoutePath? _route;
  FareEstimate? _estimate;
  bool _estimating = false;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _ordering = false;

  _PickTarget _picking = _PickTarget.none;
  bool _mapMoving = false;
  GeoPoint? _pickCenter;
  String? _pickLabel;
  Timer? _reverseDebounce;

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    super.dispose();
  }

  GeoPoint get _origin => _pickup ?? ref.read(deviceLocationProvider).value ?? GeoPoint.cityCenter;

  // ─────────────────────────────── actions ──────────────────────────────────

  Future<void> _recenter() async {
    final p = await ref.read(deviceLocationProvider.notifier).refresh();
    if (p == null) {
      if (mounted) AppToast.info(context, 'Activez la localisation pour vous situer.');
      return;
    }
    _map.moveTo(p, zoom: 16);
  }

  Future<void> _searchDestination() async {
    final result = await showPlaceSearch(context, title: 'Où allez-vous ?', near: _origin);
    if (result == null || !mounted) return;
    if (result.pickOnMap) return _startPicking(_PickTarget.dropoff);
    _setDropoff(result.place!.point, result.place!.label);
  }

  Future<void> _changePickup() async {
    final result = await showPlaceSearch(context, title: 'Point de départ', near: _origin);
    if (result == null || !mounted) return;
    if (result.pickOnMap) return _startPicking(_PickTarget.pickup);
    setState(() {
      _pickup = result.place!.point;
      _pickupLabel = result.place!.label;
    });
    _computeRoute();
  }

  void _startPicking(_PickTarget target) {
    HapticFeedback.selectionClick();
    final start = target == _PickTarget.pickup ? _origin : (_dropoff ?? _origin);
    setState(() {
      _picking = target;
      _pickCenter = start;
      _pickLabel = null;
    });
    _map.moveTo(start, zoom: 17);
    _reverse(start);
  }

  void _onCameraIdle(GeoPoint center) {
    if (_picking == _PickTarget.none) return;
    setState(() {
      _mapMoving = false;
      _pickCenter = center;
    });
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 700), () => _reverse(center));
  }

  Future<void> _reverse(GeoPoint p) async {
    final label = await ref.read(geoServicesProvider).reverse(p);
    if (mounted && _pickCenter == p) setState(() => _pickLabel = label ?? 'Point sur la carte');
  }

  void _confirmPick() {
    final p = _pickCenter;
    if (p == null) return;
    final label = _pickLabel ?? 'Point sur la carte';
    if (_picking == _PickTarget.pickup) {
      setState(() {
        _pickup = p;
        _pickupLabel = label;
        _picking = _PickTarget.none;
      });
      _computeRoute();
    } else {
      setState(() => _picking = _PickTarget.none);
      _setDropoff(p, label);
    }
  }

  void _setDropoff(GeoPoint point, String label) {
    setState(() {
      _dropoff = point;
      _dropoffLabel = label;
    });
    _computeRoute();
  }

  Future<void> _computeRoute() async {
    final dropoff = _dropoff;
    if (dropoff == null) return;
    final pickup = _origin;
    setState(() {
      _estimating = true;
      _estimate = null;
    });
    // Label "Ma position" → real address for the driver & the invoice.
    if (_pickup == null) {
      ref.read(geoServicesProvider).reverse(pickup).then((l) {
        if (l != null && mounted && _pickup == null) setState(() => _pickupLabel = l);
      });
    }
    final results = await Future.wait([
      ref.read(geoServicesProvider).route(pickup, dropoff),
      ref.read(ridesRepositoryProvider).estimate(pickup, dropoff).then<Object?>((e) => e, onError: (Object e) => e),
    ]);
    if (!mounted) return;
    final route = results[0] as RoutePath;
    final estimate = results[1];
    setState(() {
      _route = route;
      _estimating = false;
      if (estimate is FareEstimate) _estimate = estimate;
    });
    if (estimate is! FareEstimate) AppToast.apiError(context, estimate!);
    _map.fitPoints(
      [pickup, dropoff, ...route.points],
      padding: const EdgeInsets.fromLTRB(60, 160, 60, 360),
    );
  }

  void _clearTrip() {
    HapticFeedback.selectionClick();
    setState(() {
      _dropoff = null;
      _dropoffLabel = '';
      _route = null;
      _estimate = null;
    });
    _map.moveTo(_origin, zoom: 15);
  }

  Future<void> _order() async {
    final dropoff = _dropoff;
    if (dropoff == null || _ordering) return;
    setState(() => _ordering = true);
    try {
      await ref.read(currentRideProvider.notifier).order(
        pickup: _origin,
        dropoff: dropoff,
        pickupAddress: _pickupLabel == 'Ma position' ? '' : _pickupLabel,
        dropoffAddress: _dropoffLabel,
        paymentMethod: _payment,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _dropoff = null;
        _route = null;
        _estimate = null;
      });
      context.push(Routes.clientRide);
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  // ─────────────────────────────── build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final device = ref.watch(deviceLocationProvider).value;
    final taxis = ref.watch(nearbyTaxisProvider).value ?? const <NearbyTaxi>[];
    final activeRide = ref.watch(currentRideProvider).value;
    final top = MediaQuery.of(context).padding.top;

    // First fix: centre the camera on the user.
    ref.listen(deviceLocationProvider, (prev, next) {
      final p = next.value;
      if (prev?.value == null && p != null && _dropoff == null) _map.moveTo(p, zoom: 16);
    });

    final pickup = _origin;
    final picking = _picking != _PickTarget.none;

    return Scaffold(
      body: Stack(
        children: [
          RealMapView(
            controller: _map,
            initialCenter: device ?? GeoPoint.cityCenter,
            userLocation: device,
            onCameraMoveStarted: picking ? () => setState(() => _mapMoving = true) : null,
            onCameraIdle: _onCameraIdle,
            markers: [
              if (!picking && _route == null)
                for (final t in taxis)
                  MapMarkerData(point: t.position, size: 44, child: TaxiMarker(heading: (t.id * 47) % 360.0)),
              if (!picking && _dropoff != null) ...[
                MapMarkerData(point: pickup, width: 120, height: 70, alignment: Alignment.topCenter, child: const LocationPin.pickup(label: 'Départ')),
                MapMarkerData(point: _dropoff!, width: 120, height: 70, alignment: Alignment.topCenter, child: const LocationPin.dropoff(label: 'Arrivée')),
              ],
            ],
            polylines: [
              if (!picking && _route != null) ...[
                MapPolylineData(points: _route!.points, color: AppColors.ink, strokeWidth: 6, borderStrokeWidth: 3),
              ],
            ],
          ),

          // Centre pin while choosing a point on the map.
          if (picking)
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 44),
                  child: CenterPin(
                    lifted: _mapMoving,
                    color: _picking == _PickTarget.pickup ? AppColors.emerald : AppColors.ink,
                  ),
                ),
              ),
            ),

          // ── Header ───────────────────────────────────────────────────
          Positioned(
            top: top + 10,
            left: AppSpace.md,
            right: AppSpace.md,
            child: picking
                ? _PickHeader(
                    target: _picking == _PickTarget.pickup ? 'le point de départ' : 'la destination',
                    onBack: () => setState(() => _picking = _PickTarget.none),
                  )
                : MapHeaderCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bonjour${user != null ? ', ${user.firstName?.isNotEmpty == true ? user.firstName : user.username}' : ''} 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.h3,
                              ),
                              Row(
                                children: [
                                  LiveDot(color: taxis.isEmpty ? AppColors.faint : AppColors.emerald, size: 7),
                                  const SizedBox(width: 6),
                                  Text(
                                    taxis.isEmpty ? 'Recherche de taxis autour de vous…' : '${taxis.length} taxi${taxis.length > 1 ? 's' : ''} disponible${taxis.length > 1 ? 's' : ''} autour',
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const NotificationBell(route: Routes.clientNotifications),
                      ],
                    ),
                  ).entrance(dy: -.3),
          ),

          // ── Map buttons ──────────────────────────────────────────────
          if (!picking)
            Positioned(
              right: AppSpace.md,
              bottom: _dropoff == null ? 250 : 390,
              child: MapFab(icon: Icons.my_location_rounded, tooltip: 'Me localiser', onTap: _recenter),
            ),

          // ── Bottom panel ─────────────────────────────────────────────
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            bottom: AppSpace.md,
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              switchInCurve: AppMotion.curve,
              transitionBuilder: (child, a) => SlideTransition(
                position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: switch ((activeRide, picking, _dropoff)) {
                (final Ride r, _, _) when r.status.isActive => _ActiveRideCard(
                  key: const ValueKey('active'),
                  ride: r,
                  onOpen: () => context.push(Routes.clientRide),
                ),
                (_, true, _) => _PickConfirmCard(
                  key: const ValueKey('pick'),
                  label: _pickLabel,
                  moving: _mapMoving,
                  onConfirm: _confirmPick,
                ),
                (_, _, null) => _WhereToCard(
                  key: const ValueKey('where'),
                  taxis: taxis,
                  pickupLabel: _pickupLabel,
                  onSearch: _searchDestination,
                  onPickOnMap: () => _startPicking(_PickTarget.dropoff),
                ),
                _ => _ConfirmCard(
                  key: const ValueKey('confirm'),
                  pickupLabel: _pickupLabel,
                  dropoffLabel: _dropoffLabel,
                  route: _route,
                  estimate: _estimate,
                  estimating: _estimating,
                  payment: _payment,
                  ordering: _ordering,
                  nearestEta: taxis.isEmpty ? null : taxis.first.etaMinutes,
                  onPayment: (m) => setState(() => _payment = m),
                  onChangePickup: _changePickup,
                  onChangeDropoff: _searchDestination,
                  onClear: _clearTrip,
                  onOrder: _order,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── panels ──────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.rXl, boxShadow: AppShadow.floating),
    child: child,
  );
}

class _WhereToCard extends StatelessWidget {
  const _WhereToCard({super.key, required this.taxis, required this.pickupLabel, required this.onSearch, required this.onPickOnMap});

  final List<NearbyTaxi> taxis;
  final String pickupLabel;
  final VoidCallback onSearch;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    final eta = taxis.isEmpty ? null : taxis.first.etaMinutes;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Où allez-vous ?', style: AppTypography.h2),
          const SizedBox(height: AppSpace.sm),
          Material(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadius.rMd,
            child: InkWell(
              borderRadius: AppRadius.rMd,
              onTap: onSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.brandDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rechercher une destination',
                        style: AppTypography.bodyLg.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Choisir sur la carte',
                      onPressed: onPickOnMap,
                      icon: const Icon(Icons.pin_drop_outlined, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              MetricTile(
                icon: Icons.local_taxi_rounded,
                value: '${taxis.length}',
                label: 'Taxis autour',
              ),
              const SizedBox(width: 8),
              MetricTile(
                icon: Icons.schedule_rounded,
                value: eta == null ? '—' : '$eta min',
                label: 'Plus proche',
                color: AppColors.emeraldDeep,
              ),
              const SizedBox(width: 8),
              const MetricTile(
                icon: Icons.verified_user_rounded,
                value: '100 %',
                label: 'Chauffeurs vérifiés',
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    super.key,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.route,
    required this.estimate,
    required this.estimating,
    required this.payment,
    required this.ordering,
    required this.nearestEta,
    required this.onPayment,
    required this.onChangePickup,
    required this.onChangeDropoff,
    required this.onClear,
    required this.onOrder,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final RoutePath? route;
  final FareEstimate? estimate;
  final bool estimating;
  final PaymentMethod payment;
  final bool ordering;
  final int? nearestEta;
  final ValueChanged<PaymentMethod> onPayment;
  final VoidCallback onChangePickup;
  final VoidCallback onChangeDropoff;
  final VoidCallback onClear;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onChangePickup,
                  behavior: HitTestBehavior.opaque,
                  child: RouteSummary(from: pickupLabel, to: dropoffLabel),
                ),
              ),
              IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded), tooltip: 'Annuler'),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: AppColors.darkGradient, borderRadius: AppRadius.rLg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.brand, borderRadius: AppRadius.rMd),
                  child: const Icon(Icons.local_taxi_rounded, color: AppColors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Taxi Standard', style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text(
                        [
                          if (route != null) '${route!.distanceKm.toStringAsFixed(1)} km',
                          if (route != null) '${route!.etaMinutes} min de trajet',
                          if (nearestEta != null) 'taxi à $nearestEta min',
                        ].join(' · '),
                        style: AppTypography.caption.copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                if (estimating)
                  const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.brand))
                else if (estimate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedNumber(
                        value: estimate!.fare,
                        format: (v) => Formatters.money(v.round()),
                        style: AppTypography.h3.copyWith(color: AppColors.brand, fontSize: 19),
                      ),
                      Text('estimation', style: AppTypography.caption.copyWith(color: Colors.white54, fontSize: 11)),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Prix', style: AppTypography.caption.copyWith(color: Colors.white54, fontSize: 11)),
                      Text('—', style: AppTypography.h3.copyWith(color: Colors.white38, fontSize: 19)),
                    ],
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              for (final m in PaymentMethod.values) ...[
                Expanded(
                  child: _PaymentChoice(method: m, selected: m == payment, onTap: () => onPayment(m)),
                ),
                if (m != PaymentMethod.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: 'Commander le taxi',
            icon: Icons.local_taxi_rounded,
            loading: ordering,
            onPressed: onOrder,
          ),
        ],
      ),
    );
  }
}

class _PaymentChoice extends StatelessWidget {
  const _PaymentChoice({required this.method, required this.selected, required this.onTap});

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: selected ? AppColors.brandDeep : AppColors.line, width: selected ? 1.6 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(method.icon, size: 18, color: selected ? AppColors.brandDeep : AppColors.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                method.label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: AppColors.ink, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickHeader extends StatelessWidget {
  const _PickHeader({required this.target, required this.onBack});

  final String target;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return MapHeaderCard(
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: Text('Déplacez la carte pour placer $target', style: AppTypography.bodyLg.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _PickConfirmCard extends StatelessWidget {
  const _PickConfirmCard({super.key, required this.label, required this.moving, required this.onConfirm});

  final String? label;
  final bool moving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, color: AppColors.brandDeep),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Text(
                    moving ? 'Déplacement…' : (label ?? 'Recherche de l\'adresse…'),
                    key: ValueKey('$moving$label'),
                    maxLines: 2,
                    style: AppTypography.bodyLg.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(label: 'Confirmer ce point', icon: Icons.check_rounded, onPressed: moving ? null : onConfirm),
        ],
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({super.key, required this.ride, required this.onOpen});

  final Ride ride;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(gradient: AppColors.darkGradient, borderRadius: AppRadius.rXl, boxShadow: AppShadow.floating),
        child: Row(
          children: [
            PulseRings(
              color: ride.status.color,
              size: 54,
              rings: 2,
              child: Icon(ride.status.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.status.label, style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text(ride.dropoffLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: Colors.white60)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.brand, borderRadius: AppRadius.rPill),
              child: Text('Suivre', style: AppTypography.button.copyWith(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
