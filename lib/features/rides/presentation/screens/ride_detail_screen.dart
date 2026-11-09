import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/geo_point.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/map_markers.dart';
import '../../../shared/widgets/real_map_view.dart';
import '../../data/models/ride_model.dart';
import '../../providers/rides_providers.dart';
import '../widgets/ride_widgets.dart';

/// Who is looking at the ride — decides which data & actions are shown.
enum RideViewer { client, driver, admin }

/// Ride details: real GPS trace (traffic segments in orange), invoice,
/// timeline, and admin actions (cancel, confirm mobile-money payment).
class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId, required this.viewer});

  final int rideId;
  final RideViewer viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rideDetailProvider(rideId));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(message: '$e', onRetry: () => ref.invalidate(rideDetailProvider(rideId)))),
        data: (ride) => _Body(ride: ride, viewer: viewer),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.ride, required this.viewer});

  final Ride ride;
  final RideViewer viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trace = ref.watch(rideRouteProvider(ride.id)).value ?? const <TrackPoint>[];
    final party = viewer == RideViewer.client ? ride.driver : ride.client;
    final fmt = DateFormat('d MMM yyyy · HH:mm', 'fr_FR');

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 300,
          backgroundColor: AppColors.surface,
          title: Text('Course #${ride.id}'),
          flexibleSpace: FlexibleSpaceBar(
            background: _TraceMap(ride: ride, trace: trace),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpace.md),
          sliver: SliverList.list(
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RideStatusChip(status: ride.status),
                        const Spacer(),
                        if (ride.requestedAt != null) Text(fmt.format(ride.requestedAt!), style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    RouteSummary(from: ride.pickupLabel, to: ride.dropoffLabel, maxLines: 2),
                  ],
                ),
              ).entrance(index: 0),
              gapMd,
              if (party != null)
                AppCard(
                  child: PartyHeader(
                    party: party,
                    vehicle: viewer == RideViewer.client ? ride.vehicle : null,
                    subtitle: viewer == RideViewer.client ? null : 'Client · ${party.phone ?? ''}',
                  ),
                ).entrance(index: 1),
              if (party != null) gapMd,
              if (ride.status == RideStatus.completed)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Facture'),
                      FareBreakdown(ride: ride, showDriverShare: viewer != RideViewer.client),
                    ],
                  ),
                ).entrance(index: 2)
              else
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: AppColors.muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Estimation', style: AppTypography.bodyLg)),
                      Text('${ride.estimatedFare?.round() ?? '—'} FBu', style: AppTypography.h3),
                    ],
                  ),
                ).entrance(index: 2),
              gapMd,
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Chronologie'),
                    _TimelineRow('Commandée', ride.requestedAt, Icons.add_circle_outline_rounded),
                    _TimelineRow('Acceptée', ride.acceptedAt, Icons.handshake_outlined),
                    _TimelineRow('Chauffeur arrivé', ride.arrivedAt, Icons.where_to_vote_outlined),
                    _TimelineRow('Départ', ride.startedAt, Icons.play_circle_outline_rounded),
                    _TimelineRow('Arrivée', ride.completedAt, Icons.flag_outlined),
                    if (ride.cancelledAt != null)
                      _TimelineRow(
                        'Annulée${ride.cancelledBy.isEmpty ? '' : ' (${_by(ride.cancelledBy)})'}',
                        ride.cancelledAt,
                        Icons.cancel_outlined,
                        color: AppColors.danger,
                      ),
                    if (ride.clientRating != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(i <= ride.clientRating! ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.brand),
                          const SizedBox(width: 8),
                          if (ride.clientComment.isNotEmpty) Expanded(child: Text('« ${ride.clientComment} »', style: AppTypography.caption)),
                        ],
                      ),
                    ],
                  ],
                ),
              ).entrance(index: 3),
              if (viewer == RideViewer.admin) ...[gapMd, _AdminActions(ride: ride).entrance(index: 4)],
              gapXl,
            ],
          ),
        ),
      ],
    );
  }

  static String _by(String raw) => switch (raw) {
    'client' => 'client',
    'driver' => 'chauffeur',
    'admin' => 'admin',
    _ => 'système',
  };
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.label, this.at, this.icon, {this.color});

  final String label;
  final DateTime? at;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final done = at != null;
    final c = color ?? (done ? AppColors.emeraldDeep : AppColors.faint);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTypography.body.copyWith(color: done ? AppColors.ink : AppColors.faint, fontWeight: FontWeight.w600))),
          Text(done ? DateFormat('HH:mm').format(at!) : '—', style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _TraceMap extends StatelessWidget {
  const _TraceMap({required this.ride, required this.trace});

  final Ride ride;
  final List<TrackPoint> trace;

  @override
  Widget build(BuildContext context) {
    // Split the trace into normal / traffic segments to colour them.
    final segments = <MapPolylineData>[];
    if (trace.length >= 2) {
      var current = <GeoPoint>[trace.first.point];
      var traffic = trace.first.isTraffic;
      for (final p in trace.skip(1)) {
        current.add(p.point);
        if (p.isTraffic != traffic) {
          segments.add(MapPolylineData(points: current, color: traffic ? AppColors.warning : AppColors.ink));
          current = [p.point];
          traffic = p.isTraffic;
        }
      }
      segments.add(MapPolylineData(points: current, color: traffic ? AppColors.warning : AppColors.ink));
    } else {
      segments.add(MapPolylineData(points: [ride.pickup, ride.dropoff], color: AppColors.muted, dashed: true));
    }
    final controller = AppMapController();
    final points = [ride.pickup, ride.dropoff, for (final t in trace) t.point];
    return RealMapView(
      key: ValueKey(trace.length),
      controller: controller,
      initialCenter: ride.pickup,
      interactive: false,
      showAttribution: false,
      onReady: () => controller.fitPoints(points, padding: const EdgeInsets.fromLTRB(40, 110, 40, 40)),
      polylines: segments,
      markers: [
        MapMarkerData(point: ride.pickup, width: 40, height: 50, alignment: Alignment.topCenter, child: const LocationPin.pickup()),
        MapMarkerData(point: ride.dropoff, width: 40, height: 50, alignment: Alignment.topCenter, child: const LocationPin.dropoff()),
      ],
    );
  }
}

class _AdminActions extends ConsumerStatefulWidget {
  const _AdminActions({required this.ride});

  final Ride ride;

  @override
  ConsumerState<_AdminActions> createState() => _AdminActionsState();
}

class _AdminActionsState extends ConsumerState<_AdminActions> {
  bool _busy = false;

  Future<void> _run(Future<Ride?> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(rideDetailProvider(widget.ride.id));
      ref.invalidate(rideListProvider);
      if (mounted) AppToast.success(context, success);
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPayment() async {
    final ref0 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le paiement'),
        content: TextField(controller: ref0, decoration: const InputDecoration(labelText: 'Référence mobile money')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref.read(ridesRepositoryProvider).confirmPayment(widget.ride.id, reference: ref0.text.trim()),
      'Paiement confirmé, gain crédité au chauffeur.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final canConfirm = ride.status == RideStatus.completed &&
        ride.paymentMethod == PaymentMethod.mobileMoney &&
        !ride.isPaid;
    if (!ride.status.isActive && !canConfirm) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Actions administrateur'),
          if (canConfirm)
            AppButton(
              label: 'Confirmer le paiement mobile money',
              icon: Icons.verified_rounded,
              variant: AppButtonVariant.success,
              loading: _busy,
              onPressed: _confirmPayment,
            ),
          if (ride.status.isActive)
            AppButton(
              label: 'Annuler la course',
              icon: Icons.cancel_rounded,
              variant: AppButtonVariant.danger,
              loading: _busy,
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Annuler la course #${ride.id} ?',
                  message: 'Le client et le chauffeur seront notifiés.',
                  destructive: true,
                  confirmLabel: 'Annuler la course',
                );
                if (ok) {
                  await _run(
                    () => ref.read(ridesRepositoryProvider).cancel(ride.id, reason: 'Annulée par l\'administration'),
                    'Course annulée.',
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
