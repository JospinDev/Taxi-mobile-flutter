import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../rides/providers/rides_providers.dart';
import '../../../shared/widgets/app_bottom_bar.dart';

/// Bottom-tab shell for the DRIVER role: Accueil · Courses · Portefeuille · Profil.
/// Vehicles & contracts are reachable from the profile.
class DriverShell extends ConsumerWidget {
  const DriverShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the GPS tracker alive for the whole driver session: it streams
    // positions as long as a ride is assigned, whatever the visible tab.
    ref.watch(driverTrackerProvider);
    final offers = ref.watch(driverOffersProvider).length;
    final dark = navigationShell.currentIndex == 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomBar(
        dark: dark,
        items: [
          AppBarItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Accueil', badge: offers),
          const AppBarItem(Icons.route_outlined, Icons.route_rounded, 'Courses'),
          const AppBarItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Portefeuille'),
          const AppBarItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
        ],
        currentIndex: navigationShell.currentIndex,
        onSelect: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}
