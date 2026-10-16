import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../providers/admin_providers.dart';

class AdminUserDetailScreen extends ConsumerWidget {
  const AdminUserDetailScreen({super.key, required this.userId});
  final int userId;
  Future<void> _toggle(BuildContext c, WidgetRef r, bool cur) async {
    try {
      final u = await r.read(adminUsersProvider.notifier).toggleActive(userId);
      r.invalidate(adminUserDetailProvider(userId));
      if (c.mounted) {
        AppToast.success(
          c,
          u.isActive ? 'Compte reactive' : 'Compte desactive',
        );
      }
    } catch (e) {
      if (c.mounted) AppToast.apiError(c, e);
    }
  }

  Future<void> _del(BuildContext c, WidgetRef r) async {
    final ok = await confirmDialog(
      c,
      title: 'Supprimer cet utilisateur?',
      message: 'Action irreversible.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !c.mounted) return;
    try {
      await r.read(adminUsersProvider.notifier).remove(userId);
      if (c.mounted) {
        AppToast.success(c, 'Utilisateur supprime');
        c.pop();
      }
    } catch (e) {
      if (c.mounted) AppToast.apiError(c, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(adminUserDetailProvider(userId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fiche utilisateur')),
      body: a.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(adminUserDetailProvider(userId)),
        ),
        data: (u) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppCard(
              child: Row(
                children: [
                  AppAvatar(
                    firstName: u.firstName,
                    lastName: u.lastName,
                    username: u.username,
                    size: 60,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.fullName(
                            u.firstName,
                            u.lastName,
                            fallback: u.username,
                          ),
                          style: AppTypography.h2,
                        ),
                        Text('@${u.username}', style: AppTypography.caption),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusChip(
                              label: u.role.label.toUpperCase(),
                              tone: AppTone.info,
                              small: true,
                            ),
                            StatusChip(
                              label: u.isActive ? 'ACTIF' : 'DESACTIVE',
                              tone: u.isActive
                                  ? AppTone.success
                                  : AppTone.danger,
                              small: true,
                            ),
                            if (u.isVerified)
                              const StatusChip(
                                label: 'VERIFIE',
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
            ),
            gapMd,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Informations',
                    subtitle: 'PATCH /accounts/users/{id}/',
                  ),
                  InfoRow(
                    label: 'Email',
                    value: u.email ?? '—',
                    icon: Icons.mail_outline_rounded,
                  ),
                  InfoRow(
                    label: 'Telephone',
                    value: u.phone ?? '—',
                    icon: Icons.phone_outlined,
                  ),
                  InfoRow(
                    label: 'WhatsApp',
                    value: u.whatsapp ?? '—',
                    icon: Icons.chat_outlined,
                  ),
                  InfoRow(
                    label: 'Cree le',
                    value: Formatters.dateTime(u.createdAt),
                    icon: Icons.event_rounded,
                  ),
                ],
              ),
            ),
            gapMd,
            AppButton(
              label: u.isActive
                  ? 'Desactiver le compte'
                  : 'Reactiver le compte',
              icon: u.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
              variant: u.isActive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.success,
              onPressed: () => _toggle(context, ref, u.isActive),
            ),
            gapSm,
            AppButton(
              label: 'Supprimer',
              icon: Icons.delete_outline_rounded,
              variant: AppButtonVariant.outline,
              onPressed: () => _del(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
