import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_bottom_bar.dart';

/// Bottom-tab shell for the CLIENT role: Home · Historique · Profil.
class ClientShell extends StatelessWidget {
  const ClientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomBar(
        items: const [
          (Icons.map_rounded, 'Accueil'),
          (Icons.receipt_long_rounded, 'Historique'),
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
