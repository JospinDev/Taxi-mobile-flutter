import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../data/models/ride_model.dart';

/// Coloured status pill with icon.
class RideStatusChip extends StatelessWidget {
  const RideStatusChip({super.key, required this.status, this.dense = false});

  final RideStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: .12),
        borderRadius: AppRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.isActive) ...[LiveDot(color: status.color, size: 6), const SizedBox(width: 5)]
          else ...[Icon(status.icon, size: dense ? 12 : 14, color: status.color), const SizedBox(width: 4)],
          Text(
            status.label,
            style: TextStyle(fontSize: dense ? 11 : 12, fontWeight: FontWeight.w800, color: status.color),
          ),
        ],
      ),
    );
  }
}

/// Vertical "A → B" summary with a dotted connector.
class RouteSummary extends StatelessWidget {
  const RouteSummary({super.key, required this.from, required this.to, this.dark = false, this.maxLines = 1});

  final String from;
  final String to;
  final bool dark;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.bodyLg.copyWith(
      color: dark ? Colors.white : AppColors.ink,
      fontWeight: FontWeight.w600,
      fontSize: 14.5,
    );
    Widget row(Color color, IconData icon, String label, String value) => Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.overline.copyWith(fontSize: 10, color: dark ? Colors.white54 : AppColors.faint)),
              Text(value, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: text),
            ],
          ),
        ),
      ],
    );
    return Column(
      children: [
        row(AppColors.emerald, Icons.trip_origin_rounded, 'DÉPART', from),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    width: 2,
                    height: 3,
                    color: dark ? Colors.white24 : AppColors.line,
                  ),
              ],
            ),
          ),
        ),
        row(dark ? AppColors.brand : AppColors.ink, Icons.flag_rounded, 'ARRIVÉE', to),
      ],
    );
  }
}

/// 4-step progress: Recherche → En route → Arrivé → En course.
class RideProgressSteps extends StatelessWidget {
  const RideProgressSteps({super.key, required this.status});

  final RideStatus status;

  static const _labels = ['Recherche', 'En route', 'Arrivé', 'En course'];

  @override
  Widget build(BuildContext context) {
    final step = status.step;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AppMotion.slow,
                  curve: AppMotion.curve,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= step ? status.color : AppColors.line,
                    borderRadius: AppRadius.rPill,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == step ? FontWeight.w800 : FontWeight.w600,
                    color: i <= step ? AppColors.ink : AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          if (i < _labels.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Initials avatar + name + rating + vehicle.
class PartyHeader extends StatelessWidget {
  const PartyHeader({super.key, required this.party, this.vehicle, this.subtitle, this.dark = false, this.trailing});

  final RideParty party;
  final RideVehicle? vehicle;
  final String? subtitle;
  final bool dark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final parts = party.name.trim().split(RegExp(r'\s+'));
    final initials = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
          child: Text(initials.isEmpty ? '?' : initials, style: AppTypography.h3.copyWith(color: AppColors.ink)),
        ).popIn(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                party.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.h3.copyWith(fontSize: 17, color: dark ? Colors.white : AppColors.ink),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (party.rating != null) ...[
                    const Icon(Icons.star_rounded, size: 15, color: AppColors.brandDeep),
                    const SizedBox(width: 2),
                    Text(
                      party.rating!.toStringAsFixed(1),
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800, color: dark ? Colors.white : AppColors.ink),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      subtitle ?? (vehicle == null ? (party.phone ?? '') : '${vehicle!.label} · ${vehicle!.color}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: dark ? Colors.white60 : AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (vehicle != null && trailing == null) PlateBadge(plate: vehicle!.plate),
        ?trailing,
      ],
    );
  }
}

/// Licence plate look-alike.
class PlateBadge extends StatelessWidget {
  const PlateBadge({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: AppRadius.rSm,
        border: Border.all(color: AppColors.ink, width: 1.4),
      ),
      child: Text(plate, style: AppTypography.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }
}

/// Phone number button: copies the number (no dialer dependency).
class PhoneButton extends StatelessWidget {
  const PhoneButton({super.key, required this.phone, this.dark = false});

  final String phone;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: phone,
      style: IconButton.styleFrom(
        backgroundColor: dark ? Colors.white12 : AppColors.emeraldSoft,
        foregroundColor: dark ? AppColors.emerald : AppColors.emeraldDeep,
      ),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: phone));
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numéro copié : $phone')));
      },
      icon: const Icon(Icons.call_rounded),
    );
  }
}

/// Compact metric (icon, value, label).
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.icon, required this.value, required this.label, this.color = AppColors.brandDeep, this.dark = false});

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: .06) : color.withValues(alpha: .08),
          borderRadius: AppRadius.rMd,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value, style: AppTypography.h3.copyWith(fontSize: 16, color: dark ? Colors.white : AppColors.ink)),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: dark ? Colors.white54 : AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Invoice breakdown (completed ride).
class FareBreakdown extends StatelessWidget {
  const FareBreakdown({super.key, required this.ride, this.showDriverShare = false});

  final Ride ride;

  /// Commission & net earning (driver/admin only).
  final bool showDriverShare;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, double? value, {bool strong = false, Color? color, String prefix = ''}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink)
                  : AppTypography.body,
            ),
          ),
          Text(
            value == null ? '—' : '$prefix${Formatters.money(value)}',
            style: (strong ? AppTypography.h3 : AppTypography.bodyLg).copyWith(
              color: color ?? AppColors.ink,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            MetricTile(
              icon: Icons.straighten_rounded,
              value: '${(ride.actualDistanceKm ?? ride.estimatedDistanceKm ?? 0).toStringAsFixed(1)} km',
              label: ride.distanceFallback ? 'Distance estimée' : 'Distance réelle',
              color: AppColors.info,
            ),
            const SizedBox(width: 8),
            MetricTile(
              icon: Icons.traffic_rounded,
              value: '${(ride.trafficMinutes ?? 0).toStringAsFixed(0)} min',
              label: 'Embouteillage',
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            MetricTile(
              icon: Icons.timer_outlined,
              value: ride.durationSeconds == null ? '—' : '${(ride.durationSeconds! / 60).ceil()} min',
              label: 'Durée',
              color: AppColors.emeraldDeep,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        line('Prise en charge', ride.fareBase),
        line('Kilomètres', ride.fareKm),
        line('Embouteillage', ride.fareTraffic),
        const Divider(height: 18),
        line('Total', ride.fareTotal, strong: true),
        if (showDriverShare && ride.commissionAmount != null) ...[
          line('Commission (${ride.commissionPercent?.toStringAsFixed(0)} %)', ride.commissionAmount, color: AppColors.danger, prefix: '− '),
          line('Gain chauffeur', ride.driverEarning, strong: true, color: AppColors.emeraldDeep),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(ride.paymentMethod.icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(ride.paymentMethod.label, style: AppTypography.caption),
            const Spacer(),
            _PaidChip(paid: ride.isPaid),
          ],
        ),
      ],
    );
  }
}

class _PaidChip extends StatelessWidget {
  const _PaidChip({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.emeraldDeep : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: AppRadius.rPill),
      child: Text(paid ? 'PAYÉ' : 'EN ATTENTE', style: AppTypography.overline.copyWith(color: color, fontSize: 10)),
    );
  }
}

/// Interactive 1–5 star rating.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 42});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            child: AnimatedScale(
              scale: i <= value ? 1.12 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i <= value ? AppColors.brand : AppColors.faint,
              ),
            ),
          ),
      ],
    );
  }
}

/// History card.
class RideListCard extends StatelessWidget {
  const RideListCard({super.key, required this.ride, required this.onTap, this.showEarning = false, this.showClient = false});

  final Ride ride;
  final VoidCallback onTap;
  final bool showEarning;
  final bool showClient;

  @override
  Widget build(BuildContext context) {
    final date = ride.completedAt ?? ride.cancelledAt ?? ride.requestedAt;
    final amount = showEarning ? ride.driverEarning : ride.fareTotal;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.rLg,
      child: InkWell(
        borderRadius: AppRadius.rLg,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: AppRadius.rLg, border: Border.all(color: AppColors.line)),
          child: Column(
            children: [
              Row(
                children: [
                  RideStatusChip(status: ride.status, dense: true),
                  const Spacer(),
                  Text(
                    date == null ? '' : DateFormat('d MMM · HH:mm', 'fr_FR').format(date),
                    style: AppTypography.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: RouteSummary(from: ride.pickupLabel, to: ride.dropoffLabel)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount == null ? (ride.estimatedFare == null ? '—' : '≈ ${Formatters.money(ride.estimatedFare!)}') : Formatters.money(amount),
                        style: AppTypography.h3.copyWith(fontSize: 16, color: showEarning ? AppColors.emeraldDeep : AppColors.ink),
                      ),
                      if (ride.actualDistanceKm != null)
                        Text('${ride.actualDistanceKm!.toStringAsFixed(1)} km', style: AppTypography.caption),
                    ],
                  ),
                ],
              ),
              if (showClient && ride.client != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ride.client!.name, style: AppTypography.caption)),
                    if (ride.driver != null) ...[
                      const Icon(Icons.local_taxi_outlined, size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text(ride.driver!.name, style: AppTypography.caption),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated success check (ride completed).
class SuccessBadge extends StatelessWidget {
  const SuccessBadge({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: AppColors.emeraldGradient, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, color: Colors.white, size: size * .55),
    ).animate().scale(begin: const Offset(.3, .3), curve: Curves.elasticOut, duration: 900.ms).fadeIn();
  }
}
