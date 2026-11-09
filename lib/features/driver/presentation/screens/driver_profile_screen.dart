import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/driver_profile_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../notifications/providers/notifications_providers.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';

/// DRIVER — "Mon profil chauffeur" (GET /accounts/drivers/me/).
class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final profile = auth.driverProfile;
    final unread = ref.watch(unreadCountProvider);

    if (user == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: AppSpace.xl,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authControllerProvider.notifier).refreshMe(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.sm,
            AppSpace.xl,
            AppSpace.xl,
          ),
          children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusChip(
                        label: (profile?.status ?? DriverStatus.offline).label
                            .toUpperCase(),
                        icon: Icons.circle,
                        tone: profile?.status == DriverStatus.available
                            ? AppTone.success
                            : AppTone.neutral,
                        small: true,
                      ),
                      gapSm,
                      StatusChip(
                        label: profile?.isApproved ?? false
                            ? 'APPROUVÉ'
                            : 'EN ATTENTE',
                        icon: Icons.verified_user_outlined,
                        tone: (profile?.isApproved ?? false)
                            ? AppTone.success
                            : AppTone.warning,
                        small: true,
                      ),
                    ],
                  ),
                  gapMd,
                  Row(
                    children: [
                      _heroStat(
                        Icons.star_rounded,
                        Formatters.rating(profile?.rating),
                        'Note',
                      ),
                      Container(width: 1, height: 34, color: AppColors.line),
                      _heroStat(
                        Icons.route_rounded,
                        '${profile?.totalRides ?? 0}',
                        'Courses',
                      ),
                      Container(width: 1, height: 34, color: AppColors.line),
                      _heroStat(
                        Icons.badge_outlined,
                        profile?.licenseNumber ?? '—',
                        'Permis',
                      ),
                    ],
                  ),
                ],
              ),
            ).entrance(index: 0),
            gapMd,

            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  MenuTile(
                    icon: Icons.directions_car_rounded,
                    title: 'Mes véhicules',
                    subtitle: 'Documents & activation',
                    onTap: () => context.push(Routes.driverVehicles),
                  ),
                  MenuTile(
                    icon: Icons.description_rounded,
                    title: 'Contrats & tarifs',
                    subtitle: 'Commission et grille tarifaire',
                    color: AppColors.info,
                    onTap: () => context.push(Routes.driverPricing),
                  ),
                  MenuTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    color: AppColors.emeraldDeep,
                    badge: unread,
                    onTap: () => context.push(Routes.driverNotifications),
                  ),
                ],
              ),
            ).entrance(index: 1),
            gapMd,

            AppCard(
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'NOM D\'UTILISATEUR',
                    value: user.username,
                  ),
                  const Divider(),
                  InfoRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'EMAIL',
                    value: user.email ?? '—',
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
                    icon: Icons.verified_user_outlined,
                    label: 'APPROBATION',
                    value: (profile?.approvedAt ?? '').isEmpty
                        ? 'En attente d\'approbation'
                        : 'Approuvé le ${Formatters.date(profile!.approvedAt)}',
                  ),
                  const Divider(),
                  InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'INSCRIT LE',
                    value: Formatters.date(user.createdAt),
                  ),
                ],
              ),
            ).entrance(index: 2),
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
                  message: 'Vous perdrez votre session sur cet appareil.',
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
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 20, color: AppColors.brandDeep),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.h3.copyWith(fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        Text(label, style: AppTypography.caption.copyWith(fontSize: 11.5)),
      ],
    ),
  );
}
