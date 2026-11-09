import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../data/models/pricing_rule_model.dart';
import '../../providers/pricing_providers.dart';

/// Read-only active grille tarifaire — used by CLIENT (transparency) and
/// DRIVER (earnings context). Only displays server-computed amounts.
class ClientPricingScreen extends ConsumerWidget {
  const ClientPricingScreen({super.key, this.forDriver = false});

  /// When true the copy is tailored to the driver.
  final bool forDriver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activePricingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(forDriver ? 'Ma grille tarifaire' : 'Nos tarifs'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(activePricingProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
      body: active.when(
        loading: () => const LoadingView(message: 'Chargement des tarifs…'),
        error: (e, _) => ErrorView(
          title: 'Grille tarifaire indisponible',
          message: 'Aucun tarif actif pour le moment. Réessayez plus tard.',
          icon: Icons.payments_outlined,
          onRetry: () => ref.invalidate(activePricingProvider),
        ),
        data: (rule) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(activePricingProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              _HeroCard(rule: rule, forDriver: forDriver),
              const SizedBox(height: AppSpace.lg),
              _LineItem(
                icon: Icons.flag_outlined,
                label: 'Prise en charge',
                hint: 'Montant de départ, dès la montée',
                value: Formatters.money(rule.base),
              ),
              _LineItem(
                icon: Icons.route_rounded,
                label: 'Prix par kilomètre',
                hint: 'Facturé sur la distance parcourue',
                value: Formatters.money(rule.perKm),
              ),
              _LineItem(
                icon: Icons.traffic_rounded,
                label: 'Prix par minute (embouteillage)',
                hint: 'Appliqué en circulation lente',
                value: Formatters.money(rule.perMin),
              ),
              _LineItem(
                icon: Icons.trending_up_rounded,
                label: 'Tarif minimum',
                hint: 'Le prix plancher d\'une course',
                value: Formatters.money(rule.minimum),
                highlight: true,
              ),
              const SizedBox(height: AppSpace.lg),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: AppRadius.rMd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Le prix final est calculé par le serveur au moment '
                        'de la course et peut varier selon le trajet réel et '
                        'les conditions de circulation.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.rule, required this.forDriver});

  final PricingRule rule;
  final bool forDriver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadow.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: AppTypography.h2.copyWith(color: Colors.white),
                ),
              ),
              StatusChip(
                label: 'ACTIF',
                icon: Icons.check_circle_rounded,
                tone: AppTone.ink,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            forDriver
                ? 'Tarifs appliqués aux courses que vous effectuez.'
                : 'Transparence totale : ce que vous payez au kilomètre.',
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: .75),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              _stat('Dès', Formatters.money(rule.base)),
              const SizedBox(width: 10),
              _stat('Au km', Formatters.money(rule.perKm)),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _stat(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: AppRadius.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontSize: 16,
              color: AppColors.brand,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: .7),
            ),
          ),
        ],
      ),
    ),
  );

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      color: highlight ? AppColors.brandSoft : AppColors.surface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highlight ? Colors.white : AppColors.surfaceAlt,
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(
              icon,
              size: 20,
              color: highlight ? AppColors.brandDeep : AppColors.inkSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hint,
                  style: AppTypography.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontSize: 16,
              color: highlight ? AppColors.brandDeep : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
