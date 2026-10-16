import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../driver/data/models/document_type_model.dart';
import '../../../driver/data/models/vehicle_model.dart';
import '../../../driver/providers/vehicle_providers.dart';

class AdminVehicleDetailScreen extends ConsumerStatefulWidget {
  const AdminVehicleDetailScreen({super.key, required this.vehicleId});
  final int vehicleId;
  @override
  ConsumerState<AdminVehicleDetailScreen> createState() => _S();
}

class _S extends ConsumerState<AdminVehicleDetailScreen> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _val(String code, bool ok) async {
    try {
      await ref
          .read(vehiclesRepositoryProvider)
          .validateDocument(
            vehicleId: widget.vehicleId,
            docType: code,
            isValidated: ok,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      ref.invalidate(vehiclesProvider);
      if (mounted) {
        AppToast.success(context, ok ? 'Document valide' : 'Document refuse');
      }
    } catch (e) {
      if (mounted) {
        AppToast.apiError(context, e);
      }
    }
  }

  Future<void> _tog(Vehicle v) async {
    try {
      final r = ref.read(vehiclesRepositoryProvider);
      final u = v.isActive ? await r.deactivate(v.id) : await r.activate(v.id);
      ref.invalidate(vehicleDetailProvider(v.id));
      ref.invalidate(vehiclesProvider);
      if (mounted) {
        AppToast.success(
          context,
          u.isActive ? 'Vehicule active' : 'Vehicule desactive',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(vehicleDetailProvider(widget.vehicleId));
    final types = ref.watch(documentTypesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Verification')),
      body: a.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () =>
              ref.invalidate(vehicleDetailProvider(widget.vehicleId)),
        ),
        data: (v) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: AppRadius.rMd,
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.brandDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${v.brand} ${v.model} (${v.year})',
                          style: AppTypography.h3,
                        ),
                        Text(
                          '${v.plateNumber} · ${v.driverName ?? ''}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            gapMd,
            const SectionHeader(
              title: 'Note',
              subtitle: 'Ajoutee a la validation / au refus',
            ),
            AppTextField(
              label: 'Note (optionnel)',
              controller: _note,
              hint: 'Ex : conforme…',
              maxLines: 2,
            ),
            gapMd,
            const SectionHeader(
              title: 'Documents',
              subtitle: 'Valider ou refuser chaque piece',
            ),
            _docs(types, v, _val),
            gapMd,
            AppButton(
              label: v.isActive ? 'Desactiver' : 'Activer le vehicule',
              icon: v.isActive ? Icons.block_rounded : Icons.check_rounded,
              variant: v.isActive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.success,
              onPressed: () => _tog(v),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _docs(
  AsyncValue<List<DocumentType>> types,
  Vehicle v,
  Future<void> Function(String, bool) onVal,
) {
  return types.when(
    loading: () => const SkeletonBox(height: 90),
    error: (_, _) => Column(
      children: [
        for (final e in v.documents.entries)
          _Row(
            code: e.key,
            label: e.key,
            req: false,
            doc: e.value,
            onVal: onVal,
          ),
      ],
    ),
    data: (ts) => Column(
      children: [
        for (final t in ts)
          _Row(
            code: t.code,
            label: t.label,
            req: t.isRequired,
            exp: t.requiresExpiry,
            doc: v.documents[t.code],
            onVal: onVal,
          ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.code,
    required this.label,
    required this.req,
    required this.doc,
    required this.onVal,
    this.exp = false,
  });
  final String code;
  final String label;
  final bool req;
  final bool exp;
  final VehicleDocument? doc;
  final Future<void> Function(String, bool) onVal;
  @override
  Widget build(BuildContext context) {
    final tone = doc == null
        ? AppTone.neutral
        : doc!.isValidated
        ? AppTone.success
        : AppTone.warning;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (req)
                const Text(
                  '*',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(width: 8),
              StatusChip(
                label: doc == null
                    ? 'MANQUANT'
                    : doc!.isValidated
                    ? 'VALIDE'
                    : 'EN ATTENTE',
                tone: tone,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            doc == null
                ? (req ? 'Obligatoire' : 'Non fourni')
                : '${doc!.originalName ?? doc!.file} · ${Formatters.fileSize(doc!.sizeBytes)}',
            style: AppTypography.caption.copyWith(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (doc != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onVal(code, false),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onVal(code, true),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
