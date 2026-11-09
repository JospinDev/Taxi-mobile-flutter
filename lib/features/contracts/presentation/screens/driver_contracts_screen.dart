import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../data/models/contract_model.dart';
import '../../providers/contract_providers.dart';

/// DRIVER — "Mes contrats" (GET /contracts/, backend scopes to the driver).
///
/// Each card shows commission % + status; unsigned contracts invite the
/// driver to read & sign. A header tile links to the active grille tarifaire.
class DriverContractsScreen extends ConsumerWidget {
  const DriverContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contracts = ref.watch(driverContractsProvider);
    final hasUnsigned =
        contracts.asData?.value.any((c) => !c.isSigned) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes contrats'),
        automaticallyImplyLeading: true,
        toolbarHeight: 72,
        titleSpacing: AppSpace.xl,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(driverContractsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(driverContractsProvider),
        child: contracts.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: const [
              SkeletonBox(height: 96),
              SizedBox(height: AppSpace.sm),
              SkeletonBox(height: 96),
              SizedBox(height: AppSpace.sm),
              SkeletonBox(height: 96),
            ],
          ),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(driverContractsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyView(
                icon: Icons.description_outlined,
                title: 'Aucun contrat',
                message:
                    'La société n\'a pas encore émis de contrat pour vous. '
                    'Revenez plus tard.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.sm,
                AppSpace.xl,
                AppSpace.xl,
              ),
              children: [
                _PricingTile(onTap: () => context.push(Routes.driverPricing)),
                const SizedBox(height: AppSpace.sm),
                if (hasUnsigned) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: AppRadius.rMd,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.handshake_outlined,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Un contrat attend votre signature pour que vous '
                            'puissiez exercer.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
                for (final c in items) ...[
                  _ContractCard(contract: c),
                  const SizedBox(height: AppSpace.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PricingTile extends StatelessWidget {
  const _PricingTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.brandSoft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.rMd,
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.brandDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ma grille tarifaire',
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Voyez vos gains au km, à la course',
                  style: AppTypography.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({required this.contract});

  final Contract contract;

  ({String label, AppTone tone, IconData icon}) get _status =>
      switch (contract.status) {
        ContractStatus.active => (
          label: 'ACTIF',
          tone: AppTone.success,
          icon: Icons.verified_rounded,
        ),
        ContractStatus.awaitingSignature => (
          label: 'EN ATTENTE DE SIGNATURE',
          tone: AppTone.warning,
          icon: Icons.hourglass_top_rounded,
        ),
        ContractStatus.archived => (
          label: 'ARCHIVÉ',
          tone: AppTone.neutral,
          icon: Icons.inventory_2_outlined,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return AppCard(
      onTap: () => context.push(Routes.contractDetail(contract.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                icon: Icons.description_rounded,
                iconColor: AppColors.brandDeep,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contrat #${contract.id}',
                      style: AppTypography.h3.copyWith(fontSize: 16.5),
                    ),
                    Text(
                      'Commission société : '
                      '${contract.commission.toStringAsFixed(0)}%',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: s.label,
                icon: s.icon,
                tone: s.tone,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  contract.isSigned
                      ? 'Signé le $_signedLabel'
                      : 'Non signé — lisez les termes pour continuer.',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: contract.isSigned
                        ? AppColors.emeraldDeep
                        : AppColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _Tag(
                label: contract.isSigned ? 'Signé' : 'Lire et signer',
                highlight: !contract.isSigned,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _signedLabel {
    final raw = contract.signedAt;
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? AppColors.ink : AppColors.surfaceAlt,
        borderRadius: AppRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (highlight) ...[
            const Icon(Icons.draw_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.overline.copyWith(
              color: highlight ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
