import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../data/models/vehicle_model.dart';
import '../../providers/vehicle_providers.dart';

/// DRIVER — "Mes véhicules": card list + "Ajouter" entry point.
class DriverVehiclesScreen extends ConsumerWidget {
  const DriverVehiclesScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Vehicle v) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ce véhicule ?',
      message: '${v.plateNumber} — ${v.name} sera définitivement supprimé.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(vehiclesProvider.notifier).remove(v.id);
      if (context.mounted) AppToast.success(context, 'Véhicule supprimé.');
    } catch (e) {
      if (context.mounted) AppToast.apiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes véhicules'),
        automaticallyImplyLeading: true,
        toolbarHeight: 72,
        titleSpacing: AppSpace.xl,
        actions: [
          IconButton(
            tooltip: 'Ajouter un véhicule',
            onPressed: () => context.push(Routes.vehicleNew),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.vehicleNew),
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.ink,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: vehicles.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppSpace.xl),
          itemCount: 4,
          separatorBuilder: (_, _) => gapMd,
          itemBuilder: (_, _) => const SkeletonBox(height: 118),
        ),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(vehiclesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              icon: Icons.directions_car_rounded,
              title: 'Aucun véhicule enregistré',
              message:
                  'Ajoutez votre véhicule pour commencer à travailler '
                  'après validation des documents.',
              action: AppButton(
                label: 'Ajouter un véhicule',
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: () => context.push(Routes.vehicleNew),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vehiclesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.sm,
                AppSpace.xl,
                96,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => gapMd,
              itemBuilder: (context, i) => _VehicleCard(
                vehicle: items[i],
                onTap: () => context.push(Routes.vehicleDetail(items[i].id)),
                onDelete: () => _delete(context, ref, items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final docs = vehicle.documents.values;
    final validated = docs.where((d) => d.isValidated).length;
    final total = docs.length;

    return Dismissible(
      key: ValueKey('vehicle-${vehicle.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // deletion is confirmed inside onDelete
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.xl),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: AppRadius.rLg,
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: AppRadius.rMd,
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.brandDeep,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: AppTypography.h3.copyWith(fontSize: 16.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${vehicle.year} · ${vehicle.color ?? '—'} · '
                        '${vehicle.seats} places',
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: vehicle.isActive ? 'ACTIF' : 'INACTIF',
                  tone: vehicle.isActive ? AppTone.success : AppTone.neutral,
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  vehicle.plateNumber,
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
                const Spacer(),
                StatusChip(
                  label: total == 0
                      ? 'DOCS À FOURNIR'
                      : 'DOCS $validated/$total',
                  icon: Icons.description_outlined,
                  tone: total > 0 && validated == total
                      ? AppTone.success
                      : AppTone.warning,
                  small: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
