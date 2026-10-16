import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/driver_profile_model.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../providers/admin_providers.dart';

/// ADMIN — "Fiche chauffeur": GET /accounts/drivers/{id}/ + approve/suspend.
class AdminDriverDetailScreen extends ConsumerWidget {
  const AdminDriverDetailScreen({super.key, required this.driverId});

  final int driverId;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminDriversProvider.notifier).approve(driverId);
      ref.invalidate(adminDriverDetailProvider(driverId));
      if (context.mounted) AppToast.success(context, 'Chauffeur approuvé ✓');
    } catch (e) {
      if (context.mounted) AppToast.apiError(context, e);
    }
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Suspendre ce chauffeur ?',
      message: 'Il repassera en attente et ne pourra plus accepter de courses.',
      confirmLabel: 'Suspendre',
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(adminDriversProvider.notifier).suspend(driverId);
      ref.invalidate(adminDriverDetailProvider(driverId));
      if (context.mounted) AppToast.success(context, 'Chauffeur suspendu.');
    } catch (e) {
      if (context.mounted) AppToast.apiError(context, e);
    }
  }

  String _formatLocation(DriverProfile d) {
    final c = d.coordinates;
    if (c == null) return 'Aucune position enregistrée';
    final ago = d.lastLocationAt != null
        ? ' · ${Formatters.timeAgo(d.lastLocationAt)}'
        : '';
    return '${c.lat.toStringAsFixed(4)}, ${c.lng.toStringAsFixed(4)}$ago';
  }

  Widget _stat(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 19, color: AppColors.brandDeep),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.h3.copyWith(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(label, style: AppTypography.caption.copyWith(fontSize: 11.5)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDriver = ref.watch(adminDriverDetailProvider(driverId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fiche chauffeur')),
      body: asyncDriver.when(
        loading: () => const LoadingView(message: 'Chargement du chauffeur…'),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(adminDriverDetailProvider(driverId)),
        ),
        data: (d) {
          final fullName = Formatters.fullName(
            d.user.firstName,
            d.user.lastName,
            fallback: d.user.username,
          );
          final pending = !d.isApproved;
          return ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppAvatar(
                          firstName: d.user.firstName,
                          lastName: d.user.lastName,
                          username: d.user.username,
                          size: 60,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: AppTypography.h2),
                              Text('@${d.user.username}',
                                  style: AppTypography.caption),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  StatusChip(
                                    label: d.isApproved
                                        ? 'APPROUVÉ'
                                        : 'EN ATTENTE',
                                    icon: d.isApproved
                                        ? Icons.verified_rounded
                                        : Icons.hourglass_top_rounded,
                                    tone: d.isApproved
                                        ? AppTone.success
                                        : AppTone.warning,
                                    small: true,
                                  ),
                                  StatusChip(
                                    label: d.status.label.toUpperCase(),
                                    tone:
                                        AppTone.forStatusKey(d.status.raw),
                                    small: true,
                                  ),
                                  if (d.user.isVerified)
                                    const StatusChip(
                                      label: 'VÉRIFIÉ',
                                      icon: Icons.verified_rounded,
                                      tone: AppTone.success,
                                      small: true,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        _stat(Icons.star_rounded,
                            Formatters.rating(d.rating), 'Note'),
                        _stat(Icons.route_rounded, '${d.totalRides}',
                            'Courses'),
                        _stat(Icons.event_rounded,
                            Formatters.date(d.createdAt), 'Membre'),
                      ],
                    ),
                  ],
                ),
              ),

              gapMd,
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Informations',
                      subtitle: 'GET /accounts/drivers/{id}/',
                    ),
                    InfoRow(
                      label: 'Email',
                      value: d.user.email ?? '—',
                      icon: Icons.mail_outline_rounded,
                    ),
                    InfoRow(
                      label: 'Téléphone',
                      value: d.user.phone ?? '—',
                      icon: Icons.phone_outlined,
                    ),
                    InfoRow(
                      label: 'WhatsApp',
                      value: d.user.whatsapp ?? '—',
                      icon: Icons.chat_outlined,
                    ),
                    InfoRow(
                      label: 'Permis',
                      value: (d.licenseNumber?.isNotEmpty ?? false)
                          ? d.licenseNumber!
                          : '—',
                      icon: Icons.badge_outlined,
                    ),
                    InfoRow(
                      label: 'Position',
                      value: _formatLocation(d),
                      icon: Icons.location_on_outlined,
                    ),
                    InfoRow(
                      label: 'Créé le',
                      value: Formatters.dateTime(d.createdAt),
                      icon: Icons.event_rounded,
                    ),
                    InfoRow(
                      label: 'Approuvé le',
                      value: d.approvedAt != null
                          ? Formatters.dateTime(d.approvedAt)
                          : '—',
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ),
              ),
              gapMd,
              if (pending)
                AppButton(
                  label: 'Approuver ce chauffeur',
                  icon: Icons.check_circle_outline_rounded,
                  variant: AppButtonVariant.success,
                  onPressed: () => _approve(context, ref),
                )
              else
                AppButton(
                  label: 'Suspendre ce chauffeur',
                  icon: Icons.block_rounded,
                  variant: AppButtonVariant.danger,
                  onPressed: () => _suspend(context, ref),
                ),
              gapSm,
              if (pending)
                AppButton(
                  label: 'Suspendre',
                  icon: Icons.block_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: () => _suspend(context, ref),
                )
              else
                AppButton(
                  label: 'Actualiser',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: () =>
                      ref.invalidate(adminDriverDetailProvider(driverId)),
                ),
            ],
          );
        },
      ),
    );
  }
}

