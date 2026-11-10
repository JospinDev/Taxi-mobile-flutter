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
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/map_markers.dart';
import '../../../shared/widgets/real_map_view.dart';
import '../../data/models/ride_model.dart';
import '../../providers/rides_providers.dart';
import '../widgets/ride_widgets.dart';

/// CLIENT — live follow-up of the current ride, from search to invoice.
class ClientRideScreen extends ConsumerStatefulWidget {
  const ClientRideScreen({super.key});

  @override
  ConsumerState<ClientRideScreen> createState() => _ClientRideScreenState();
}

class _ClientRideScreenState extends ConsumerState<ClientRideScreen> {
  final _map = AppMapController();
  RoutePath? _route;
  String? _routeKey;
  bool _busy = false;

  /// Road route of the current leg: driver → pickup, then pickup → dropoff.
  Future<void> _ensureRoute(Ride ride) async {
    final from = ride.status == RideStatus.inProgress ? ride.pickup : (ride.driverLocation ?? ride.pickup);
    final to = ride.status == RideStatus.inProgress ? ride.dropoff : ride.pickup;
    if (ride.status == RideStatus.searching || ride.status == RideStatus.arrived) {
      // Searching / arrived: show the whole trip.
      return _loadRoute('${ride.id}-trip', ride.pickup, ride.dropoff, ride);
    }
    // Recompute the approach route only when the driver moved > 150 m.
    final key = '${ride.id}-${ride.status.raw}-${(from.lat * 700).round()}-${(from.lng * 700).round()}';
    return _loadRoute(key, from, to, ride);
  }

  Future<void> _loadRoute(String key, GeoPoint from, GeoPoint to, Ride ride) async {
    if (_routeKey == key) return;
    _routeKey = key;
    final route = await ref.read(geoServicesProvider).route(from, to);
    if (!mounted || _routeKey != key) return;
    setState(() => _route = route);
    _map.fitPoints(
      [from, to, ?ride.driverLocation],
      padding: const EdgeInsets.fromLTRB(60, 140, 60, 380),
    );
  }

  Future<void> _cancel(Ride ride) async {
    final ok = await confirmDialog(
      context,
      title: 'Annuler la course ?',
      message: ride.status == RideStatus.searching
          ? 'La recherche de chauffeur sera arrêtée.'
          : 'Votre chauffeur ${ride.driver?.name ?? ''} est déjà en route.',
      confirmLabel: 'Annuler la course',
      cancelLabel: 'Garder',
      destructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(currentRideProvider.notifier).cancel(reason: 'Annulée par le client');
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    ref.read(currentRideProvider.notifier).dismiss();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.clientHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(currentRideProvider);
    final ride = async.value;

    ref.listen(currentRideProvider, (prev, next) {
      final before = prev?.value?.status;
      final now = next.value?.status;
      if (before != now && now != null) HapticFeedback.mediumImpact();
    });

    if (ride == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const LoadingView(message: 'Chargement de votre course…')
            : EmptyView(
                icon: Icons.local_taxi_outlined,
                title: 'Aucune course en cours',
                message: 'Commandez un taxi depuis l\'accueil.',
                action: AppButton(label: 'Retour à l\'accueil', expanded: false, onPressed: () => context.go(Routes.clientHome)),
              ),
      );
    }

    if (ride.status.isActive) WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRoute(ride));
    final top = MediaQuery.of(context).padding.top;
    final finished = ride.status.isFinished;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && finished) ref.read(currentRideProvider.notifier).dismiss();
      },
      child: Scaffold(
        body: Stack(
          children: [
            _LiveMap(controller: _map, ride: ride, route: _route),
            Positioned(
              top: top + 10,
              left: AppSpace.md,
              child: MapFab(icon: Icons.arrow_back_rounded, onTap: () => finished ? _close() : context.pop()),
            ),
            if (ride.status.isActive)
              Positioned(
                top: top + 14,
                right: AppSpace.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.rPill, boxShadow: AppShadow.soft),
                  child: RideStatusChip(status: ride.status, dense: true),
                ),
              ),
            Positioned(
              left: AppSpace.md,
              right: AppSpace.md,
              bottom: AppSpace.md,
              child: AnimatedSwitcher(
                duration: AppMotion.slow,
                switchInCurve: AppMotion.curve,
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey(ride.status),
                  child: switch (ride.status) {
                    RideStatus.searching => _SearchingPanel(ride: ride, busy: _busy, onCancel: () => _cancel(ride)),
                    RideStatus.accepted || RideStatus.arrived || RideStatus.inProgress => _DriverPanel(
                      ride: ride,
                      route: _route,
                      busy: _busy,
                      onCancel: () => _cancel(ride),
                    ),
                    RideStatus.completed => _CompletedPanel(ride: ride, onDone: _close),
                    RideStatus.cancelled || RideStatus.noDriver => _EndedPanel(ride: ride, onDone: _close),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Map with radar (searching) or the moving taxi (assigned).
class _LiveMap extends StatelessWidget {
  const _LiveMap({required this.controller, required this.ride, required this.route});

  final AppMapController controller;
  final Ride ride;
  final RoutePath? route;

  @override
  Widget build(BuildContext context) {
    final driver = ride.driverLocation;
    return TweenAnimationBuilder<GeoPoint>(
      // Glides the taxi between two GPS fixes instead of jumping.
      tween: GeoPointTween(begin: driver ?? ride.pickup, end: driver ?? ride.pickup),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeInOut,
      builder: (context, animatedDriver, _) {
        final heading = driver == null ? 0.0 : animatedDriver.bearingTo(ride.status == RideStatus.inProgress ? ride.dropoff : ride.pickup);
        return RealMapView(
          controller: controller,
          initialCenter: ride.pickup,
          initialZoom: 15,
          onReady: () => controller.fitPoints(
            [ride.pickup, ride.dropoff, ?driver],
            padding: const EdgeInsets.fromLTRB(60, 140, 60, 380),
          ),
          polylines: [
            if (route != null)
              MapPolylineData(
                points: route!.points,
                color: ride.status == RideStatus.inProgress || ride.status == RideStatus.searching ? AppColors.ink : AppColors.info,
                dashed: ride.status == RideStatus.accepted,
              ),
          ],
          markers: [
            if (ride.status == RideStatus.searching)
              MapMarkerData(
                point: ride.pickup,
                size: 240,
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    PulseRings(color: AppColors.brand, size: 240),
                    RadarSweep(size: 200),
                  ],
                ),
              ),
            MapMarkerData(point: ride.pickup, width: 120, height: 70, alignment: Alignment.topCenter, child: const LocationPin.pickup(label: 'Départ')),
            MapMarkerData(point: ride.dropoff, width: 120, height: 70, alignment: Alignment.topCenter, child: const LocationPin.dropoff(label: 'Arrivée')),
            if (driver != null && ride.status.hasDriver)
              MapMarkerData(point: animatedDriver, size: 64, child: TaxiMarker(heading: heading, highlighted: true, size: 64)),
          ],
        );
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.rXl, boxShadow: AppShadow.floating),
    child: child,
  );
}

class _SearchingPanel extends StatefulWidget {
  const _SearchingPanel({required this.ride, required this.busy, required this.onCancel});

  final Ride ride;
  final bool busy;
  final VoidCallback onCancel;

  @override
  State<_SearchingPanel> createState() => _SearchingPanelState();
}

class _SearchingPanelState extends State<_SearchingPanel> {
  late final DateTime _startedAt = DateTime.now();
  late final Timer _tick;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final long = _elapsed.inSeconds >= 90;
    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PulseRings(color: long ? AppColors.warning : AppColors.brand, size: 56, rings: 2, child: Icon(Icons.local_taxi_rounded, color: long ? AppColors.warning : AppColors.brandDeep)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(long ? 'Toujours en recherche…' : 'Recherche d\'un chauffeur…', style: AppTypography.h3),
                    Text(
                      long
                          ? 'Peu de taxis disponibles en ce moment (${_elapsed.inMinutes}m ${_elapsed.inSeconds % 60}s)'
                          : 'Nous contactons les taxis les plus proches',
                      style: AppTypography.caption.copyWith(color: long ? AppColors.warning : null),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: LinearProgressIndicator(
              minHeight: 5,
              color: long ? AppColors.warning : AppColors.brand,
              backgroundColor: long ? AppColors.warning.withValues(alpha: .15) : AppColors.brandSoft,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          RouteSummary(from: widget.ride.pickupLabel, to: widget.ride.dropoffLabel),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Icon(widget.ride.paymentMethod.icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(widget.ride.paymentMethod.label, style: AppTypography.caption),
              const Spacer(),
              Text('≈ ${Formatters.money(widget.ride.estimatedFare ?? 0)}', style: AppTypography.h3.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(label: 'Annuler la recherche', variant: AppButtonVariant.outline, loading: widget.busy, onPressed: widget.onCancel),
        ],
      ),
    );
  }
}

class _DriverPanel extends StatelessWidget {
  const _DriverPanel({required this.ride, required this.route, required this.busy, required this.onCancel});

  final Ride ride;
  final RoutePath? route;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final driver = ride.driver;
    final headline = switch (ride.status) {
      RideStatus.accepted => route == null ? 'Votre chauffeur arrive' : 'Arrivée dans ${route!.etaMinutes} min',
      RideStatus.arrived => 'Votre chauffeur est là !',
      _ => 'En route vers votre destination',
    };
    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(headline, style: AppTypography.h2.copyWith(fontSize: 20))),
              if (ride.status == RideStatus.inProgress)
                Text('≈ ${Formatters.money(ride.estimatedFare ?? 0)}', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          RideProgressSteps(status: ride.status),
          const SizedBox(height: AppSpace.md),
          if (driver != null)
            PartyHeader(
              party: driver,
              vehicle: ride.vehicle,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ChatButton(),
                  if (driver.phone != null) ...[
                    const SizedBox(width: AppSpace.xxs),
                    PhoneButton(phone: driver.phone!),
                  ],
                ],
              ),
            ),
          if (ride.vehicle != null) ...[
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: AppRadius.rMd),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_filled_rounded, color: AppColors.inkSoft, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${ride.vehicle!.label} · ${ride.vehicle!.color}', style: AppTypography.body.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600))),
                  PlateBadge(plate: ride.vehicle!.plate),
                ],
              ),
            ),
          ],
          if (ride.status == RideStatus.inProgress) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                MetricTile(icon: Icons.straighten_rounded, value: '${ride.liveDistanceKm.toStringAsFixed(1)} km', label: 'Parcourus', color: AppColors.info),
                const SizedBox(width: 8),
                MetricTile(icon: Icons.traffic_rounded, value: '${ride.liveTrafficMinutes.toStringAsFixed(0)} min', label: 'Embouteillage', color: AppColors.warning),
                const SizedBox(width: 8),
                MetricTile(
                  icon: Icons.flag_rounded,
                  value: route == null ? '—' : '${route!.etaMinutes} min',
                  label: 'Restant',
                  color: AppColors.emeraldDeep,
                ),
              ],
            ),
          ],
          if (ride.status.clientCanCancel) ...[
            const SizedBox(height: AppSpace.sm),
            AppButton(label: 'Annuler la course', variant: AppButtonVariant.ghost, loading: busy, onPressed: onCancel),
          ],
        ],
      ),
    );
  }
}

class _CompletedPanel extends ConsumerStatefulWidget {
  const _CompletedPanel({required this.ride, required this.onDone});

  final Ride ride;
  final VoidCallback onDone;

  @override
  ConsumerState<_CompletedPanel> createState() => _CompletedPanelState();
}

class _CompletedPanelState extends ConsumerState<_CompletedPanel> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ref.read(currentRideProvider.notifier).rate(_rating, comment: _comment.text.trim());
      if (!mounted) return;
      AppToast.success(context, 'Merci pour votre avis !');
      widget.onDone();
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final rated = ride.clientRating != null;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .78),
      child: _Sheet(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessBadge(size: 64),
              const SizedBox(height: AppSpace.sm),
              Text('Vous êtes arrivé !', style: AppTypography.h2),
              const SizedBox(height: 4),
              AnimatedNumber(
                value: ride.fareTotal ?? 0,
                format: (v) => Formatters.money(v.round()),
                style: AppTypography.display.copyWith(fontSize: 30),
              ),
              const SizedBox(height: AppSpace.md),
              FareBreakdown(ride: ride).animate().fadeIn(delay: 200.ms),
              const Divider(height: 28),
              if (!rated) ...[
                Text('Comment s\'est passée la course avec ${ride.driver?.name ?? 'votre chauffeur'} ?', textAlign: TextAlign.center, style: AppTypography.bodyLg.copyWith(color: AppColors.ink)),
                const SizedBox(height: AppSpace.sm),
                StarRatingInput(value: _rating, onChanged: (v) => setState(() => _rating = v)),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _comment,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Un commentaire (facultatif)'),
                ),
                const SizedBox(height: AppSpace.md),
                AppButton(label: 'Envoyer mon avis', icon: Icons.send_rounded, loading: _sending, onPressed: _submit),
                TextButton(onPressed: widget.onDone, child: const Text('Plus tard')),
              ] else
                AppButton(label: 'Terminer', onPressed: widget.onDone),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndedPanel extends StatelessWidget {
  const _EndedPanel({required this.ride, required this.onDone});

  final Ride ride;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final noDriver = ride.status == RideStatus.noDriver;
    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: (noDriver ? AppColors.warning : AppColors.danger).withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(ride.status.icon, size: 34, color: noDriver ? AppColors.warning : AppColors.danger),
          ).popIn(),
          const SizedBox(height: AppSpace.sm),
          Text(noDriver ? 'Aucun chauffeur disponible' : 'Course annulée', style: AppTypography.h2),
          const SizedBox(height: 4),
          Text(
            noDriver
                ? 'Tous les taxis sont occupés pour le moment. Réessayez dans quelques minutes.'
                : (ride.cancelReason.isEmpty ? 'Cette course a été annulée.' : ride.cancelReason),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(label: noDriver ? 'Réessayer' : 'Retour à l\'accueil', onPressed: onDone),
        ],
      ),
    );
  }
}
