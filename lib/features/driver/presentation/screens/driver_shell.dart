import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_bottom_bar.dart';

/// Bottom-tab shell for the DRIVER role: Dashboard · Véhicules · Profil.
class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomBar(
        items: const [
          (Icons.dashboard_rounded, 'Dashboard'),
          (Icons.directions_car_rounded, 'Véhicules'),
          (Icons.person_rounded, 'Profil'),
        ],
        currentIndex: navigationShell.currentIndex,
        onSelect: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
