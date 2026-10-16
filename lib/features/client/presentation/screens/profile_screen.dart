import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';

/// CLIENT profile — avatar, account info, edit & logout actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: AppSpace.xl,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.sm,
          AppSpace.xl,
          AppSpace.xl,
        ),
        children: [
          // ── Identity card ───────────────────────────────────────────
          AppCard(
            child: Column(
              children: [
                AppAvatar(
                  firstName: user.firstName,
                  lastName: user.lastName,
                  username: user.username,
                  size: 84,
                ),
                gapSm,
                Text(
                  Formatters.fullName(
                    user.firstName,
                    user.lastName,
                    fallback: user.username,
                  ),
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),
                gapXs,
                StatusChip(
                  label: user.role.label.toUpperCase(),
                  icon: Icons.person_rounded,
                  tone: user.role == UserRole.client
                      ? AppTone.brand
                      : AppTone.info,
                  small: true,
                ),
                if (user.email != null) ...[
                  gapSm,
                  Text(
                    user.email!,
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          gapMd,

          // ── Account details ─────────────────────────────────────────
          AppCard(
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'NOM D\'UTILISATEUR',
                  value: user.username,
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'TÉLÉPHONE',
                  value: user.phone ?? '—',
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'WHATSAPP',
                  value: user.whatsapp ?? '—',
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'INSCRIT LE',
                  value: Formatters.date(user.createdAt),
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.verified_outlined,
                  label: 'STATUT',
                  value: user.isActive ? 'Compte actif' : 'Compte désactivé',
                  trailing: StatusChip(
                    label: user.isActive ? 'ACTIF' : 'INACTIF',
                    tone: user.isActive ? AppTone.success : AppTone.danger,
                    small: true,
                  ),
                ),
              ],
            ),
          ),
          gapMd,

          AppButton(
            label: 'Modifier mes informations',
            icon: Icons.edit_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(Routes.editProfile),
          ),
          gapSm,
          AppButton(
            label: 'Se déconnecter',
            icon: Icons.logout_rounded,
            variant: AppButtonVariant.danger,
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Se déconnecter ?',
                message:
                    'Vous devrez vous reconnecter pour accéder à votre '
                    'compte.',
                confirmLabel: 'Déconnexion',
                destructive: true,
                icon: Icons.logout_rounded,
              );
              if (!ok || !context.mounted) return;
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
          gapLg,
          Center(
            child: Text(
              'Taxi Driving · v0.1.0',
              style: AppTypography.caption.copyWith(color: AppColors.faint),
            ),
          ),
        ],
      ),
    );
  }
}
