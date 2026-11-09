import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../rides/providers/rides_providers.dart';
import '../../../shared/widgets/app_bottom_bar.dart';

/// Bottom-tab shell for the CLIENT role: Accueil · Courses · Tarifs · Profil.
class ClientShell extends ConsumerWidget {
  const ClientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Follows the active ride app-wide (status pushes, polling, live socket).
    final ride = ref.watch(currentRideProvider).value;
    final live = ride != null && ride.status.isActive ? 1 : 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomBar(
        items: [
          const AppBarItem(Icons.map_outlined, Icons.map_rounded, 'Accueil'),
          AppBarItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Courses', badge: live),
          const AppBarItem(Icons.sell_outlined, Icons.sell_rounded, 'Tarifs'),
          const AppBarItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
        ],
        currentIndex: navigationShell.currentIndex,
        onSelect: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}
