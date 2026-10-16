import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../data/models/document_type_model.dart';
import '../../data/models/vehicle_model.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../providers/vehicle_providers.dart';

import 'package:go_router/go_router.dart';

/// DRIVER — vehicle detail + document grid.
///
/// The document slots are generated from `GET /vehicles/document-types/`
/// (fully dynamic: new types appear without any app update).
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final int vehicleId;

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    DocumentType type,
    VehicleDocument doc,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer "${type.label}" ?',
      message: doc.originalName != null
          ? 'Fichier : ${doc.originalName}'
          : 'Le document sera retiré du véhicule.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(vehiclesRepositoryProvider)
          .deleteDocument(vehicleId: vehicleId, docType: type.code);
      ref.invalidate(vehicleDetailProvider(vehicleId));
      ref.invalidate(vehiclesProvider);
      if (context.mounted) AppToast.success(context, 'Document supprimé.');
    } catch (e) {
      if (context.mounted) AppToast.apiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    final typesAsync = ref.watch(documentTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Détail du véhicule')),
      body: vehicleAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(vehicleDetailProvider(vehicleId)),
        ),
        data: (vehicle) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vehicleDetailProvider(vehicleId));
            ref.invalidate(vehiclesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.xl,
            ),
            children: [
              _HeaderCard(vehicle: vehicle),
              gapMd,
              SectionHeader(
                title: 'Documents',
                subtitle: typesAsync.when(
                  loading: () => 'Chargement…',
                  error: (_, _) => 'Types de documents indisponibles',
                  data: (types) =>
                      '${types.where((t) => t.isRequired).length} '
                      'obligatoire(s) · ${types.length} type(s) au total',
                ),
              ),
              typesAsync.when(
                loading: () => const SkeletonBox(height: 220),
                error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(documentTypesProvider),
                ),
                data: (types) => Column(
                  children: [
                    for (final type in types)
                      _DocumentSlot(
                        type: type,
                        document: vehicle.documents[type.code],
                        onUpload: () => context.push(
                          '/driver/vehicles/$vehicleId/documents/${type.code}/upload',
                        ),
                        onDelete: () {
                          final doc = vehicle.documents[type.code];
                          if (doc != null) {
                            _deleteDocument(context, ref, type, doc);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vehicle summary card (plate, specs, activation status, owner for admin).
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: AppRadius.rMd,
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.ink,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: AppTypography.h3),
                    Text(
                      vehicle.plateNumber,
                      style: AppTypography.caption.copyWith(
                        letterSpacing: .6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: vehicle.isActive ? 'ACTIF' : 'INACTIF',
                icon: vehicle.isActive
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_rounded,
                tone: vehicle.isActive ? AppTone.success : AppTone.neutral,
              ),
            ],
          ),
          gapSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(Icons.calendar_today_outlined, '${vehicle.year}'),
              _tag(Icons.palette_outlined, vehicle.color ?? '—'),
              _tag(Icons.event_seat_outlined, '${vehicle.seats} places'),
              _tag(
                Icons.verified_outlined,
                vehicle.requiredDocsValidated
                    ? 'Docs validés'
                    : 'Docs à valider',
              ),
            ],
          ),
          if (vehicle.driverName != null) ...[
            const Divider(height: 22),
            Row(
              children: [
                AppAvatar(username: vehicle.driverName, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chauffeur : ${vehicle.driverName}',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.rPill,
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.caption.copyWith(fontSize: 12.5)),
      ],
    ),
  );
}

/// One document slot: status icon + label + expiry + upload/delete action.
class _DocumentSlot extends StatelessWidget {
  const _DocumentSlot({
    required this.type,
    required this.document,
    required this.onUpload,
    required this.onDelete,
  });

  final DocumentType type;
  final VehicleDocument? document;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  ({String label, AppTone tone, IconData icon}) get _state {
    final doc = document;
    if (doc == null) {
      return (
        label: 'MANQUANT',
        tone: AppTone.warning,
        icon: Icons.error_outline_rounded,
      );
    }
    if (doc.isValidated) {
      return (
        label: 'VALIDÉ',
        tone: AppTone.success,
        icon: Icons.verified_rounded,
      );
    }
    return (
      label: 'EN ATTENTE',
      tone: AppTone.info,
      icon: Icons.hourglass_top_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final s = _state;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(14),
      shadow: AppShadow.soft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: s.tone.background,
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(s.icon, size: 20, color: s.tone.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type.label,
                        style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (type.isRequired)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          '*',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  doc == null
                      ? (type.isRequired
                            ? 'Obligatoire pour activer le véhicule'
                            : 'Non fourni')
                      : '${Formatters.fileSize(doc.sizeBytes)} · '
                            '${Formatters.timeAgo(doc.uploadedAt)}'
                            '${type.requiresExpiry && doc.expiresAt != null ? ' · expire le ${Formatters.date(doc.expiresAt)}' : ''}',
                  style: AppTypography.caption.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label: s.label, tone: s.tone, small: true),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
            onSelected: (v) {
              if (v == 'upload') {
                onUpload();
              } else {
                onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(doc == null ? 'Envoyer' : 'Remplacer'),
                  ],
                ),
              ),
              if (doc != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Supprimer',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
