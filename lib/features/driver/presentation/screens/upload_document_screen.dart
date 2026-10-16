import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../data/models/document_type_model.dart';
import '../../providers/vehicle_providers.dart';
import '../../../shared/providers/repository_providers.dart';

/// DRIVER — upload a document on a vehicle.
///
/// Route: `/driver/vehicles/:id/documents/:docType/upload`
/// POST /vehicles/{id}/upload-document/ (multipart/form-data).
class UploadDocumentScreen extends ConsumerStatefulWidget {
  const UploadDocumentScreen({
    super.key,
    required this.vehicleId,
    required this.docTypeCode,
  });

  final int vehicleId;
  final String docTypeCode;

  @override
  ConsumerState<UploadDocumentScreen> createState() =>
      _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends ConsumerState<UploadDocumentScreen> {
  PlatformFile? _file;
  int? _fileSize;
  DateTime? _expiresAt;
  bool _uploading = false;
  double _progress = 0;

  bool _isSupported(PlatformFile f) {
    final name = f.name.toLowerCase();
    return name.endsWith('.pdf') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (picked == null) return; // user cancelled

      if (!_isSupported(picked)) {
        if (!mounted) return;
        AppToast.error(context, 'Format non supporté (PDF, JPG ou PNG).');
        return;
      }
      final fileSize = picked.lengthSync() ?? await picked.length();
      if (fileSize != null && fileSize > AppConfig.maxUploadSize) {
        if (!mounted) return;
        AppToast.error(
          context,
          'Fichier trop volumineux (${Formatters.fileSize(fileSize)} > 5 Mo).',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _file = picked;
        _fileSize = fileSize;
      });
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 10 * 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit(DocumentType type) async {
    final file = _file;
    if (file == null || file.path == null) {
      AppToast.error(context, 'Choisissez d\'abord un fichier.');
      return;
    }
    if (type.requiresExpiry && _expiresAt == null) {
      AppToast.error(context, 'La date d\'expiration est obligatoire.');
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      await ref
          .read(vehiclesRepositoryProvider)
          .uploadDocument(
            vehicleId: widget.vehicleId,
            docType: widget.docTypeCode,
            filePath: file.path!,
            expiresAt: _expiresAt?.toIso8601String().split('T').first,
            onSendProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => _progress = sent / total);
              }
            },
          );
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      ref.invalidate(vehiclesProvider);
      if (!mounted) return;
      AppToast.success(context, 'Document "${type.label}" envoyé ✓');
      context.pop();
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(documentTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Envoyer un document')),
      body: typesAsync.when(
        loading: () => const LoadingView(message: 'Chargement du type…'),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(documentTypesProvider),
        ),
        data: (types) {
          DocumentType? type;
          for (final t in types) {
            if (t.code == widget.docTypeCode) type = t;
          }
          if (type == null) {
            return const ErrorView(
              message: 'Ce type de document n\'existe plus.',
            );
          }
          return _buildForm(context, type);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, DocumentType type) {
    final file = _file;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.sm,
        AppSpace.xl,
        AppSpace.xl,
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          shadow: AppShadow.soft,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: AppRadius.rMd,
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: AppColors.brandDeep,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: AppTypography.h3),
                    if ((type.description ?? '').isNotEmpty)
                      Text(type.description!, style: AppTypography.caption),
                  ],
                ),
              ),
              if (type.isRequired)
                const Text(
                  'REQUIS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                    letterSpacing: .8,
                  ),
                ),
            ],
          ),
        ),
        gapMd,

        const FormSectionLabel('FICHIER'),
        GestureDetector(
          onTap: _uploading ? null : _pickFile,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.xl),
            decoration: BoxDecoration(
              color: file == null ? Colors.white : AppColors.emeraldSoft,
              borderRadius: AppRadius.rLg,
              border: Border.all(
                color: file == null ? AppColors.line : AppColors.emerald,
                width: 1.4,
              ),
              boxShadow: AppShadow.soft,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: file == null
                        ? AppColors.surfaceAlt
                        : AppColors.emerald,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    file == null
                        ? Icons.cloud_upload_outlined
                        : Icons.check_circle_rounded,
                    size: 30,
                    color: file == null ? AppColors.muted : Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  file == null ? 'Choisir un fichier' : file.name,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  file == null
                      ? 'PDF, JPG ou PNG · 5 Mo maximum'
                      : Formatters.fileSize(_fileSize),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ),

        // ── Expiry (only when the type requires it) ─────────────────
        if (type.requiresExpiry) ...[
          const FormSectionLabel('DATE D\'EXPIRATION'),
          GestureDetector(
            onTap: _uploading ? null : _pickExpiry,
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: 16,
              ),
              shadow: AppShadow.soft,
              child: Row(
                children: [
                  const Icon(
                    Icons.event_rounded,
                    size: 20,
                    color: AppColors.brandDeep,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _expiresAt == null
                          ? 'Sélectionner une date'
                          : 'Expire le '
                                '${Formatters.date(_expiresAt!.toIso8601String())}',
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: _expiresAt == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: _expiresAt == null
                            ? AppColors.muted
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.faint,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Obligatoire pour ce type de document.',
            style: AppTypography.caption.copyWith(color: AppColors.faint),
          ),
        ],

        gapXl,
        if (_uploading) ...[
          ClipRRect(
            borderRadius: AppRadius.rPill,
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 6,
              backgroundColor: AppColors.line,
              color: AppColors.emerald,
            ),
          ),
          gapMd,
        ],
        AppButton(
          label: _uploading ? 'Envoi en cours…' : 'Envoyer le document',
          icon: Icons.upload_rounded,
          loading: _uploading,
          onPressed: () => _submit(type),
        ),
        gapSm,
        Center(
          child: TextButton(
            onPressed: _uploading ? null : () => context.pop(),
            child: const Text('Annuler'),
          ),
        ),
      ],
    );
  }
}
