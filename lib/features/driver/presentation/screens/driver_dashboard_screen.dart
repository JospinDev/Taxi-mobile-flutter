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
import '../../../../core/config/app_config.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/driver_profile_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../payments/providers/payments_providers.dart';
import '../../../rides/data/models/ride_model.dart';
import '../../../rides/presentation/widgets/ride_widgets.dart';
import '../../../rides/providers/rides_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/map_markers.dart';
import '../../../shared/widgets/real_map_view.dart';

/// DRIVER dashboard — dark live map, earnings, online toggle and ride offers.
///
/// While online and idle, the GPS position is pushed to
/// `PATCH /accounts/drivers/me/location/` (dispatch uses it). During a ride
/// the [DriverRideTracker] takes over with batched `track/` calls.
class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  final _map = AppMapController();
  Timer? _gpsTimer;
  bool _toggling = false;
  bool _locationDenied = false;
  GeoPoint? _position;
  final Set<int> _accepting = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authControllerProvider.notifier).refreshDriverProfile();
      _syncGpsLoop();
      final p = await ref.read(deviceLocationProvider.future);
      if (p != null && mounted) {
        setState(() => _position = p);
        _map.moveTo(p, zoom: 16);
      }
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  bool get _online => ref.read(currentDriverProfileProvider)?.status == DriverStatus.available;

  Future<void> _toggleOnline() async {
    if (_toggling) return;
    final goingOnline = !_online;
    HapticFeedback.mediumImpact();

    if (goingOnline) {
      final granted = await ref.read(locationServiceProvider).requestPermission();
      if (!mounted) return;
      setState(() => _locationDenied = !granted);
      if (!granted) {
        final retry = await confirmDialog(
          context,
          title: 'Position indisponible',
          message: 'Sans localisation, aucune course ne peut vous être proposée. Activez le GPS puis réessayez.',
          confirmLabel: 'Réessayer',
          cancelLabel: 'Continuer quand même',
          icon: Icons.location_off_rounded,
        );
        if (retry) return _toggleOnline();
      }
    }

    setState(() => _toggling = true);
    try {
      final status = await ref.read(authRepositoryProvider).updateStatus(goingOnline ? 'available' : 'offline');
      await ref.read(authControllerProvider.notifier).refreshDriverProfile();
      if (!mounted) return;
      AppToast.success(context, status == 'available' ? 'Vous êtes en ligne 🟢 Les courses arrivent ici.' : 'Vous êtes hors ligne.');
      _syncGpsLoop();
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  void _syncGpsLoop() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    if (!_online) return;
    _pushLocation();
    _gpsTimer = Timer.periodic(AppConfig.locationPushInterval, (_) => _pushLocation());
  }

  Future<void> _pushLocation() async {
    // During a ride the tracker already sends positions.
    if (ref.read(currentRideProvider).value?.status.hasDriver ?? false) return;
    final p = await ref.read(locationServiceProvider).currentPosition();
    if (p == null) return;
    if (mounted) setState(() => _position = p);
    try {
      await ref.read(authRepositoryProvider).updateLocation(lat: p.lat, lng: p.lng);
    } catch (_) {}
  }

  Future<void> _accept(RideOffer offer) async {
    setState(() => _accepting.add(offer.rideId));
    try {
      await ref.read(driverOffersProvider.notifier).accept(offer);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      context.push(Routes.driverRide);
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _accepting.remove(offer.rideId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentDriverProfileProvider);
    final user = ref.watch(currentUserProvider);
    final online = profile?.status == DriverStatus.available;
    final busy = profile?.status == DriverStatus.busy;
    final offers = ref.watch(driverOffersProvider);
    final ride = ref.watch(currentRideProvider).value;
    final activeRide = ride != null && ride.status.isActive ? ride : null;
    final today = ref.watch(driverTodayStatsProvider).value;
    final top = MediaQuery.of(context).padding.top;
    final offer = offers.isEmpty ? null : offers.first;

    ref.listen(currentDriverProfileProvider, (prev, next) {
      if (prev?.status != next?.status) _syncGpsLoop();
    });
    ref.listen(driverOffersProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) {
        HapticFeedback.heavyImpact();
        final o = next.first;
        _map.fitPoints([?_position, o.pickup], padding: const EdgeInsets.fromLTRB(70, 160, 70, 420));
      }
    });

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            RealMapView(
              controller: _map,
              style: MapStyle.dark,
              initialCenter: _position ?? GeoPoint.cityCenter,
              markers: [
                if (_position != null)
                  MapMarkerData(point: _position!, size: 64, child: TaxiMarker(highlighted: online, size: 64)),
                if (offer != null) ...[
                  MapMarkerData(point: offer.pickup, width: 120, height: 70, alignment: Alignment.topCenter, child: const LocationPin.pickup(label: 'Client')),
                ],
              ],
              polylines: [
                if (offer != null && _position != null)
                  MapPolylineData(points: [_position!, offer.pickup], color: AppColors.brand, dashed: true, borderStrokeWidth: 0, strokeWidth: 4),
              ],
              circles: [
                if (online && _position != null && offer == null)
                  MapCircleData(
                    point: _position!,
                    radius: 2000,
                    useRadiusInMeter: true,
                    color: AppColors.emerald.withValues(alpha: .08),
                    borderColor: AppColors.emerald.withValues(alpha: .5),
                  ),
              ],
            ),

            // ── Header ─────────────────────────────────────────────────
            Positioned(
              top: top + 10,
              left: AppSpace.md,
              right: AppSpace.md,
              child: MapHeaderCard(
                dark: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salut, ${user?.firstName?.isNotEmpty == true ? user!.firstName : user?.username ?? ''} 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h3.copyWith(color: Colors.white),
                          ),
                          Row(
                            children: [
                              LiveDot(color: online ? AppColors.emerald : (busy ? AppColors.info : AppColors.faint), size: 7),
                              const SizedBox(width: 6),
                              Text(
                                busy ? 'En course' : (online ? 'En ligne · zone 2 km' : 'Hors ligne'),
                                style: AppTypography.caption.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const NotificationBell(route: Routes.driverNotifications, dark: true),
                  ],
                ),
              ).entrance(dy: -.3),
            ),

            Positioned(
              right: AppSpace.md,
              bottom: 300,
              child: MapFab(
                dark: true,
                icon: Icons.my_location_rounded,
                onTap: () async {
                  final p = await ref.read(deviceLocationProvider.notifier).refresh();
                  if (p != null) {
                    setState(() => _position = p);
                    _map.moveTo(p, zoom: 16);
                  }
                },
              ),
            ),

            // ── Bottom: offer / active ride / control panel ────────────
            Positioned(
              left: AppSpace.md,
              right: AppSpace.md,
              bottom: AppSpace.md,
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: activeRide != null
                    ? _ActiveRideBanner(key: const ValueKey('ride'), ride: activeRide, onOpen: () => context.push(Routes.driverRide))
                    : offer != null
                    ? _OfferCard(
                        key: ValueKey('offer-${offer.rideId}'),
                        offer: offer,
                        pending: offers.length,
                        accepting: _accepting.contains(offer.rideId),
                        onAccept: () => _accept(offer),
                        onReject: () => ref.read(driverOffersProvider.notifier).reject(offer),
                      )
                    : _ControlPanel(
                        key: const ValueKey('panel'),
                        online: online,
                        profile: profile,
                        today: today,
                        toggling: _toggling,
                        locationDenied: _locationDenied,
                        onToggle: _toggleOnline,
                        onWallet: () => context.go(Routes.driverWallet),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    super.key,
    required this.online,
    required this.profile,
    required this.today,
    required this.toggling,
    required this.locationDenied,
    required this.onToggle,
    required this.onWallet,
  });

  final bool online;
  final DriverProfile? profile;
  final ({double earnings, int rides, double km})? today;
  final bool toggling;
  final bool locationDenied;
  final VoidCallback onToggle;
  final VoidCallback onWallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: Colors.white10),
        boxShadow: AppShadow.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onWallet,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GAINS DU JOUR', style: AppTypography.overline.copyWith(color: Colors.white54)),
                    AnimatedNumber(
                      value: today?.earnings ?? 0,
                      format: (v) => Formatters.money(v.round()),
                      style: AppTypography.h1.copyWith(color: AppColors.brand, fontSize: 30),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              MetricTile(dark: true, icon: Icons.route_rounded, value: '${today?.rides ?? 0}', label: 'Courses du jour', color: AppColors.info),
              const SizedBox(width: 8),
              MetricTile(dark: true, icon: Icons.straighten_rounded, value: '${(today?.km ?? 0).toStringAsFixed(1)} km', label: 'Parcourus', color: AppColors.emerald),
              const SizedBox(width: 8),
              MetricTile(dark: true, icon: Icons.star_rounded, value: Formatters.rating(profile?.rating), label: 'Note', color: AppColors.brand),
            ],
          ),
          if (locationDenied) ...[
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: .15), borderRadius: AppRadius.rMd),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Position non partagée — activez la localisation.',
                      style: AppTypography.caption.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          _OnlineButton(online: online, toggling: toggling, onTap: onToggle),
        ],
      ),
    );
  }
}

/// Big go-online / go-offline button with a breathing glow when online.
class _OnlineButton extends StatelessWidget {
  const _OnlineButton({required this.online, required this.toggling, required this.onTap});

  final bool online;
  final bool toggling;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: toggling ? null : onTap,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.curve,
        height: 62,
        decoration: BoxDecoration(
          gradient: online ? null : AppColors.emeraldGradient,
          color: online ? Colors.white.withValues(alpha: .08) : null,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: online ? Colors.white24 : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (toggling)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            else
              Icon(online ? Icons.power_settings_new_rounded : Icons.bolt_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(
              toggling ? 'Mise à jour…' : (online ? 'Passer hors ligne' : 'Passer en ligne'),
              style: AppTypography.button.copyWith(color: Colors.white, fontSize: 17),
            ),
          ],
        ),
      ),
    );
    if (online || toggling) return button;
    return button
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .boxShadow(
          begin: const BoxShadow(color: Color(0x0010B981), blurRadius: 0),
          end: const BoxShadow(color: Color(0x6610B981), blurRadius: 26, spreadRadius: -2),
          borderRadius: AppRadius.rLg,
          duration: 1400.ms,
        );
  }
}

/// Incoming ride offer: fare, pickup distance, route, countdown, accept / reject.
class _OfferCard extends StatefulWidget {
  const _OfferCard({
    super.key,
    required this.offer,
    required this.pending,
    required this.accepting,
    required this.onAccept,
    required this.onReject,
  });

  final RideOffer offer;
  final int pending;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  late final Timer _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppColors.brand.withValues(alpha: .6), width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0x55F7C948), blurRadius: 30, spreadRadius: -8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CountdownRing(total: o.expiresIn, remaining: o.remaining),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOUVELLE COURSE${widget.pending > 1 ? ' · ${widget.pending} en attente' : ''}',
                      style: AppTypography.overline.copyWith(color: AppColors.brand),
                    ),
                    Text(
                      Formatters.money(o.estimatedFare.round()),
                      style: AppTypography.h1.copyWith(color: Colors.white, fontSize: 28),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(o.distanceToPickupM / 1000).toStringAsFixed(1)} km', style: AppTypography.h3.copyWith(color: Colors.white)),
                  Text('du client', style: AppTypography.caption.copyWith(color: Colors.white54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          RouteSummary(from: o.pickupAddress.isEmpty ? 'Position du client' : o.pickupAddress, to: o.dropoffAddress.isEmpty ? 'Destination' : o.dropoffAddress, dark: true),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 15, color: Colors.white.withValues(alpha: .6)),
              const SizedBox(width: 4),
              Text('Trajet ≈ ${o.estimatedDistanceKm.toStringAsFixed(1)} km', style: AppTypography.caption.copyWith(color: Colors.white60)),
              const Spacer(),
              Icon(o.paymentMethod.icon, size: 15, color: Colors.white.withValues(alpha: .6)),
              const SizedBox(width: 4),
              Text(o.paymentMethod.label, style: AppTypography.caption.copyWith(color: Colors.white60)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: widget.accepting ? null : widget.onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: widget.accepting ? null : widget.onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: widget.accepting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: const Text('Accepter'),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().shake(hz: 3, offset: const Offset(4, 0), duration: 450.ms);
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({super.key, required this.ride, required this.onOpen});

  final Ride ride;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: AppRadius.rXl, boxShadow: AppShadow.brand),
        child: Row(
          children: [
            PulseRings(color: AppColors.ink, size: 52, rings: 2, child: Icon(ride.status.icon, color: AppColors.ink)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.status.label, style: AppTypography.h3),
                  Text(
                    ride.status == RideStatus.inProgress ? ride.dropoffLabel : ride.pickupLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}
