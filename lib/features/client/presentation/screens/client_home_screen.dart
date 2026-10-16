import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/stylized_map.dart';

/// CLIENT home — full-bleed map, destination search bar on top,
/// prominent "Commander un taxi" action.
///
/// The rides endpoints are not part of Modules 1 & 2 yet, so the order flow
/// shows a "coming soon" feedback; the screen is ready to wire up.
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  final _destinationCtrl = TextEditingController();

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          const StylizedMap(label: 'Bujumbura · centre-ville'),
          Positioned(
            top: top + 12,
            left: AppSpace.md,
            right: AppSpace.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salut${user != null ? ', ${user.firstName ?? user.username}' : ''} 👋',
                            style: AppTypography.h2.copyWith(fontSize: 20),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Où allez-vous aujourd\'hui ?',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppShadow.soft,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 22,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                _SearchBar(
                  controller: _destinationCtrl,
                  onSubmitted: _orderTaxi,
                  onHistory: () => AppToast.info(
                    context,
                    'Vos destinations récentes apparaîtront ici.',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            bottom: AppSpace.md,
            child: _OrderCard(onOrder: _orderTaxi),
          ),
        ],
      ),
    );
  }

  void _orderTaxi() {
    HapticFeedback.lightImpact();
    AppToast.info(
      context,
      'La réservation de taxi arrive très vite — module courses à venir !',
    );
  }
}

/// Destination search field floating on the map.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onHistory,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rMd,
        boxShadow: AppShadow.floating,
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmitted(),
              style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Rechercher une destination…',
                isDense: true,
                filled: false,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Destination récente',
            onPressed: onHistory,
            icon: const Icon(
              Icons.history_rounded,
              size: 20,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom hero card: ETA badge, fare teaser, giant "Commander un taxi".
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.onOrder});

  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadow.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _miniStat(
                Icons.schedule_rounded,
                '~ 4 min',
                'Taxi le plus proche',
              ),
              const SizedBox(width: 10),
              _miniStat(Icons.payments_outlined, 'à partir de', 'Tarif estimé'),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOrder,
              icon: const Icon(Icons.local_taxi_rounded, size: 24),
              label: const Text('Commander un taxi'),
              style: ElevatedButton.styleFrom(
                textStyle: AppTypography.button.copyWith(fontSize: 17),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                shadowColor: const Color(0x80E8A400),
                elevation: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandDeep),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.faint),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
