import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_feedback.dart';

/// ADMIN shell — drawer navigation instead of bottom tabs.
///
/// Sections: Tableau de bord · Chauffeurs · Utilisateurs · Véhicules ·
/// Types de documents · Contrats.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.navigationShell});

  /// Global key so nested admin screens (which own their Scaffold) can open
  /// this shell's drawer from their AppBar menu button.
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  final StatefulNavigationShell navigationShell;

  static const _sections = [
    (
      Routes.adminHome,
      Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded,
      'Tableau de bord',
      'Vue d\u2019ensemble',
    ),
    (
      Routes.adminDrivers,
      Icons.groups_outlined,
      Icons.groups_rounded,
      'Chauffeurs',
      'Approbation & statut',
    ),
    (
      Routes.adminUsers,
      Icons.manage_accounts_outlined,
      Icons.manage_accounts_rounded,
      'Utilisateurs',
      'Comptes de la plateforme',
    ),
    (
      Routes.adminVehicles,
      Icons.directions_car_outlined,
      Icons.directions_car_rounded,
      'Véhicules',
      'Documents & activation',
    ),
    (
      Routes.adminDocTypes,
      Icons.folder_copy_outlined,
      Icons.folder_copy_rounded,
      'Types de documents',
      'Configuration',
    ),
    (
      Routes.adminContracts,
      Icons.description_outlined,
      Icons.description_rounded,
      'Contrats',
      'Création & activation',
    ),
    (
      Routes.adminRides,
      Icons.local_taxi_outlined,
      Icons.local_taxi_rounded,
      'Courses',
      'Suivi & paiements',
    ),
    (
      Routes.adminWallets,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Portefeuilles',
      'Commissions & versements',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final current = _sections[navigationShell.currentIndex.clamp(0, _sections.length - 1)].$1;

    return Scaffold(
      key: AdminShell.scaffoldKey,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.xl),
                decoration: const BoxDecoration(
                  gradient: AppColors.darkGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppAvatar(
                          firstName: user?.firstName,
                          lastName: user?.lastName,
                          username: user?.username,
                          size: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Formatters.fullName(
                                  user?.firstName,
                                  user?.lastName,
                                  fallback: user?.username ?? '',
                                ),
                                style: AppTypography.h3.copyWith(
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user?.role.label ?? 'Admin',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: AppRadius.rPill,
                      ),
                      child: Text(
                        'Console d\'administration',
                        style: AppTypography.overline.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.md,
                  ),
                  children: [
                    for (var i = 0; i < _sections.length; i++)
                      _DrawerTile(
                        icon: _sections[i].$2,
                        selectedIcon: _sections[i].$3,
                        title: _sections[i].$4,
                        subtitle: _sections[i].$5,
                        selected: current == _sections[i].$1,
                        onTap: () {
                          navigationShell.goBranch(
                            i,
                            initialLocation: i == navigationShell.currentIndex,
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Se déconnecter',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final ok = await confirmDialog(
                      context,
                      title: 'Se déconnecter ?',
                      message: 'Vous devrez vous reconnecter pour accéder à la console.',
                      confirmLabel: 'Déconnexion',
                      destructive: true,
                      icon: Icons.logout_rounded,
                    );
                    if (!ok || !context.mounted) return;
                    await ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: navigationShell,
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: AppColors.brandSoft,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        leading: Icon(
          selected ? selectedIcon : icon,
          color: selected ? AppColors.brandDeep : AppColors.muted,
        ),
        title: Text(
          title,
          style: AppTypography.bodyLg.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5)),
        trailing: selected
            ? Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.brandDeep,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
      ),
    );
  }
}
