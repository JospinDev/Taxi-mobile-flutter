import 'package:flutter/material.dart';

import '../../../../app/theme/app_space.dart';
import '../../../shared/widgets/app_states.dart';

/// CLIENT — ride history.
///
/// Placeholder until the `rides` module (Module 3) exposes its endpoints;
/// designed as an empty state that will be replaced by a paginated list.
class ClientHistoryScreen extends StatelessWidget {
  const ClientHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Historique'),
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: AppSpace.xl,
      ),
      body: const EmptyView(
        icon: Icons.route_rounded,
        title: 'Aucune course pour le moment',
        message:
            'Vos trajets apparaîtront ici après votre première course en taxi.',
      ),
    );
  }
}
