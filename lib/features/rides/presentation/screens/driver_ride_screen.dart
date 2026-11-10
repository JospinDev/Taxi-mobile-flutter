import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../payments/providers/payments_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/map_markers.dart';
import '../../../shared/widgets/real_map_view.dart';
import '../../../shared/widgets/slide_to_confirm.dart';
import '../../data/models/ride_model.dart';
import '../../providers/rides_providers.dart';
import '../widgets/ride_widgets.dart';

/// DRIVER — the ride in progress: navigation map, client, live meter and
/// the step actions (arrived → start → finish).
class DriverRideScreen extends ConsumerStatefulWidget {
  const DriverRideScreen({super.key});

  @override
  ConsumerState<DriverRideScreen> createState() => _DriverRideScreenState();
}

class _DriverRideScreenState extends ConsumerState<DriverRideScreen> {
  final _map = AppMapController();
  RoutePath? _route;
  String? _routeKey;
  bool _busy = false;
  bool _follow = true;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the trip timer ticking.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _ensureRoute(Ride ride, GeoPoint? me) async {
    final toPickup = ride.status == RideStatus.accepted;
    final from = toPickup ? (me ?? ride.driverLocation ?? ride.pickup) : ride.pickup;
    final to = toPickup ? ride.pickup : ride.dropoff;
    final key = '${ride.id}-${ride.status.raw}-${toPickup ? '${(from.lat * 500).round()}${(from.lng * 500).round()}' : ''}';
    if (key == _routeKey) return;
    _routeKey = key;
    final route = await ref.read(geoServicesProvider).route(from, to);
    if (!mounted || _routeKey != key) return;
    setState(() => _route = route);
    if (_follow) _map.fitPoints([from, to], padding: const EdgeInsets.fromLTRB(60, 140, 60, 400));
  }

  Future<void> _step(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        HapticFeedback.mediumImpact();
        AppToast.success(context, done);
      }
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    final ok = await confirmDialog(
      context,
      title: 'Se désister ?',
      message: 'La course sera proposée à un autre chauffeur. Les désistements répétés pénalisent votre compte.',
      confirmLabel: 'Me désister',
      destructive: true,
      icon: Icons.undo_rounded,
    );
    if (!ok) return;
    await _step(() => ref.read(currentRideProvider.notifier).cancel(reason: 'Désistement du chauffeur'), 'Course relâchée.');
    await ref.read(authControllerProvider.notifier).refreshDriverProfile();
    if (mounted) context.go(Routes.driverHome);
  }

  void _finish() {
    ref.read(currentRideProvider.notifier).dismiss();
    ref.invalidate(driverTodayStatsProvider);
    ref.read(authControllerProvider.notifier).refreshDriverProfile();
    context.go(Routes.driverHome);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(currentRideProvider);
    final ride = async.value;
    final tracker = ref.watch(driverTrackerProvider);
    final top = MediaQuery.of(context).padding.top;

    if (ride == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const LoadingView()
            : EmptyView(
                icon: Icons.local_taxi_outlined,
                title: 'Aucune course en cours',
                message: 'Passez en ligne pour recevoir des courses.',
                action: AppButton(label: 'Tableau de bord', expanded: false, onPressed: () => context.go(Routes.driverHome)),
              ),
      );
    }

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            ValueListenableBuilder<GeoPoint?>(
              valueListenable: tracker.position,
              builder: (context, me, _) {
                final position = me ?? ride.driverLocation;
                if (ride.status.hasDriver) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRoute(ride, position));
                }
                return ValueListenableBuilder<double>(
                  valueListenable: tracker.heading,
                  builder: (context, heading, _) => RealMapView(
                    controller: _map,
                    style: MapStyle.dark,
                    initialCenter: position ?? ride.pickup,
                    initialZoom: 16,
                    onCameraMoveStarted: () => _follow = false,
                    polylines: [
                      if (_route != null)
                        MapPolylineData(
                          points: _route!.points,
                          color: ride.status == RideStatus.accepted ? AppColors.info : AppColors.brand,
                          borderColor: AppColors.ink,
                          strokeWidth: 6,
                        ),
                    ],
                    markers: [
                      if (ride.status != RideStatus.inProgress)
                        MapMarkerData(point: ride.pickup, width: 120, height: 70, alignment: Alignment.topCenter, child: const LocationPin.pickup(label: 'Client')),
                      MapMarkerData(point: ride.dropoff, width: 120, height: 70, alignment: Alignment.topCenter, child: const LocationPin.dropoff(label: 'Arrivée')),
                      if (position != null)
                        MapMarkerData(point: position, size: 60, child: TaxiMarker(heading: heading, highlighted: true, size: 60)),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: top + 10,
              left: AppSpace.md,
              child: MapFab(dark: true, icon: Icons.arrow_back_rounded, onTap: () => ride.status.isActive ? context.pop() : _finish()),
            ),
            if (ride.status.isActive)
              Positioned(
                top: top + 10,
                right: AppSpace.md,
                child: MapFab(
                  dark: true,
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: 'Recentrer',
                  onTap: () {
                    _follow = true;
                    final p = tracker.position.value ?? ride.driverLocation ?? ride.pickup;
                    _map.moveTo(p, zoom: 17);
                  },
                ),
              ),
            Positioned(
              left: AppSpace.md,
              right: AppSpace.md,
              bottom: AppSpace.md,
              child: AnimatedSwitcher(
                duration: AppMotion.slow,
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey(ride.status),
                  child: ride.status == RideStatus.completed
                      ? _SummaryPanel(ride: ride, onDone: _finish)
                      : ride.status.isActive
                      ? _StepPanel(
                          ride: ride,
                          route: _route,
                          tracker: tracker,
                          busy: _busy,
                          onArrived: () => _step(() => ref.read(currentRideProvider.notifier).markArrived(), 'Client prévenu de votre arrivée.'),
                          onStart: () => _step(() => ref.read(currentRideProvider.notifier).start(), 'Course démarrée. Bonne route !'),
                          onComplete: () => _step(() => ref.read(currentRideProvider.notifier).complete(), 'Course terminée.'),
                          onWithdraw: _withdraw,
                        )
                      : _CancelledPanel(ride: ride, onDone: _finish),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkSheet extends StatelessWidget {
  const _DarkSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceDark,
      borderRadius: AppRadius.rXl,
      border: Border.all(color: Colors.white10),
      boxShadow: AppShadow.floating,
    ),
    child: child,
  );
}

class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.ride,
    required this.route,
    required this.tracker,
    required this.busy,
    required this.onArrived,
    required this.onStart,
    required this.onComplete,
    required this.onWithdraw,
  });

  final Ride ride;
  final RoutePath? route;
  final DriverRideTracker tracker;
  final bool busy;
  final Future<void> Function() onArrived;
  final Future<void> Function() onStart;
  final Future<void> Function() onComplete;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final headline = switch (ride.status) {
      RideStatus.accepted => route == null ? 'Rejoignez le client' : 'Client à ${route!.etaMinutes} min · ${route!.distanceKm.toStringAsFixed(1)} km',
      RideStatus.arrived => 'Le client a été prévenu',
      _ => route == null ? 'En route vers la destination' : 'Destination à ${route!.etaMinutes} min',
    };
    final elapsed = ride.startedAt == null ? Duration.zero : DateTime.now().difference(ride.startedAt!);

    return _DarkSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(headline, style: AppTypography.h3.copyWith(color: Colors.white))),
              Text(
                '≈ ${Formatters.money((ride.estimatedFare ?? 0).round())}',
                style: AppTypography.bodyLg.copyWith(color: AppColors.brand, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          if (ride.client != null)
            PartyHeader(
              party: ride.client!,
              dark: true,
              subtitle: ride.paymentMethod.label,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ChatButton(dark: true),
                  if (ride.client!.phone != null) ...[
                    const SizedBox(width: AppSpace.xxs),
                    PhoneButton(phone: ride.client!.phone!, dark: true),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpace.sm),
          RouteSummary(from: ride.pickupLabel, to: ride.dropoffLabel, dark: true),
          if (ride.status == RideStatus.inProgress) ...[
            const SizedBox(height: AppSpace.sm),
            ValueListenableBuilder(
              valueListenable: tracker.live,
              builder: (context, live, _) => Row(
                children: [
                  MetricTile(dark: true, icon: Icons.straighten_rounded, value: '${live.km.toStringAsFixed(2)} km', label: 'Compteur', color: AppColors.brand),
                  const SizedBox(width: 8),
                  MetricTile(dark: true, icon: Icons.traffic_rounded, value: '${live.trafficMin.toStringAsFixed(0)} min', label: 'Embouteillage', color: AppColors.warning),
                  const SizedBox(width: 8),
                  MetricTile(
                    dark: true,
                    icon: Icons.timer_outlined,
                    value: '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                    label: 'Durée',
                    color: AppColors.emerald,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          switch (ride.status) {
            RideStatus.accepted => SlideToConfirm(label: 'Je suis arrivé', icon: Icons.where_to_vote_rounded, loading: busy, onConfirmed: onArrived),
            RideStatus.arrived => SlideToConfirm(
              label: 'Démarrer la course',
              icon: Icons.play_arrow_rounded,
              color: AppColors.emerald,
              foreground: Colors.white,
              loading: busy,
              onConfirmed: onStart,
            ),
            _ => SlideToConfirm(
              label: 'Terminer la course',
              icon: Icons.flag_rounded,
              color: AppColors.danger,
              foreground: Colors.white,
              loading: busy,
              onConfirmed: onComplete,
            ),
          },
          if (ride.status.driverCanCancel)
            TextButton(
              onPressed: busy ? null : onWithdraw,
              child: Text('Je ne peux pas assurer cette course', style: AppTypography.caption.copyWith(color: Colors.white54)),
            ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.ride, required this.onDone});

  final Ride ride;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final cash = ride.paymentMethod == PaymentMethod.cash;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.rXl, boxShadow: AppShadow.floating),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessBadge(size: 60),
              const SizedBox(height: AppSpace.sm),
              Text('Course terminée', style: AppTypography.h2),
              const SizedBox(height: AppSpace.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: AppColors.darkGradient, borderRadius: AppRadius.rLg),
                child: Column(
                  children: [
                    Text(cash ? 'À ENCAISSER EN ESPÈCES' : 'PAYÉ PAR MOBILE MONEY', style: AppTypography.overline.copyWith(color: Colors.white54)),
                    AnimatedNumber(
                      value: ride.fareTotal ?? 0,
                      format: (v) => Formatters.money(v.round()),
                      style: AppTypography.display.copyWith(color: AppColors.brand, fontSize: 32),
                    ),
                    Text(
                      'Votre gain net : ${Formatters.money((ride.driverEarning ?? 0).round())}',
                      style: AppTypography.caption.copyWith(color: AppColors.emerald, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ).popIn(),
              const SizedBox(height: AppSpace.md),
              FareBreakdown(ride: ride, showDriverShare: true),
              if (cash) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  'La commission de ${Formatters.money((ride.commissionAmount ?? 0).round())} est déduite de votre portefeuille.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption,
                ),
              ],
              const SizedBox(height: AppSpace.md),
              AppButton(label: 'Retour au tableau de bord', onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelledPanel extends StatelessWidget {
  const _CancelledPanel({required this.ride, required this.onDone});

  final Ride ride;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _DarkSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 48).popIn(),
          const SizedBox(height: AppSpace.sm),
          Text('Course annulée', style: AppTypography.h2.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            ride.cancelReason.isEmpty ? 'Le client a annulé la course.' : ride.cancelReason,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(label: 'Retour au tableau de bord', onPressed: onDone),
        ],
      ),
    );
  }
}
