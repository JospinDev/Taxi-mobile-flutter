import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../data/wallet_model.dart';
import '../../providers/payments_providers.dart';

/// DRIVER — wallet: balance, lifetime totals, ledger.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(myWalletProvider);
    final txs = ref.watch(walletTransactionsProvider(null));
    final today = ref.watch(driverTodayStatsProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Portefeuille'), automaticallyImplyLeading: false, toolbarHeight: 64),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myWalletProvider);
          ref.invalidate(walletTransactionsProvider(null));
          ref.invalidate(driverTodayStatsProvider);
          await ref.read(myWalletProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.xxl),
          children: [
            wallet.when(
              loading: () => const SkeletonBox(height: 210, radius: AppRadius.xl),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(myWalletProvider)),
              data: (w) => _BalanceCard(wallet: w, todayEarnings: today?.earnings ?? 0).entrance(),
            ),
            gapMd,
            if (wallet.value case final w?) ...[
              Row(
                children: [
                  _Stat(label: 'Gains totaux', value: w.totalEarned, color: AppColors.emeraldDeep, icon: Icons.trending_up_rounded),
                  const SizedBox(width: 10),
                  _Stat(label: 'Commissions', value: w.totalCommission, color: AppColors.warning, icon: Icons.percent_rounded),
                  const SizedBox(width: 10),
                  _Stat(label: 'Versé', value: w.totalPaidOut, color: AppColors.info, icon: Icons.north_east_rounded),
                ],
              ).entrance(index: 1),
              gapLg,
            ],
            const SectionHeader(title: 'Mouvements', subtitle: 'Commissions, gains crédités et versements'),
            txs.when(
              loading: () => Column(children: [for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonBox(height: 64))]),
              error: (e, _) => ErrorView(message: '$e'),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: AppSpace.xl),
                      child: EmptyView(icon: Icons.receipt_long_outlined, title: 'Aucun mouvement', message: 'Vos gains apparaîtront ici après vos premières courses.'),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          _TxTile(
                            tx: list[i],
                            onTap: list[i].rideId == null ? null : () => context.push(Routes.driverRideDetail(list[i].rideId!)),
                          ).entrance(index: i + 2),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.todayEarnings});

  final Wallet wallet;
  final double todayEarnings;

  @override
  Widget build(BuildContext context) {
    final debt = wallet.inDebt;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        gradient: debt
            ? const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFF450A0A)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : AppColors.darkGradient,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadow.floating,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.brand.withValues(alpha: .08)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: AppColors.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(debt ? 'COMMISSIONS À REVERSER' : 'SOLDE DISPONIBLE', style: AppTypography.overline.copyWith(color: Colors.white60)),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              AnimatedNumber(
                value: wallet.balance.abs(),
                format: (v) => Formatters.money(v.round()),
                style: AppTypography.display.copyWith(color: debt ? const Color(0xFFFCA5A5) : Colors.white, fontSize: 36),
              ),
              const SizedBox(height: 4),
              Text(
                debt
                    ? 'Courses payées en espèces : reversez cette commission à la société.'
                    : 'Montant que la société vous doit (courses payées par mobile money).',
                style: AppTypography.caption.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: AppSpace.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: AppRadius.rPill),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.today_rounded, size: 16, color: AppColors.emerald),
                    const SizedBox(width: 6),
                    Text(
                      'Aujourd\'hui : ${Formatters.money(todayEarnings.round())}',
                      style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.rLg, boxShadow: AppShadow.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            FittedBox(child: Text(Formatters.money(value.round()), style: AppTypography.bodyLg.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800))),
            Text(label, style: AppTypography.caption.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, this.onTap});

  final WalletTransaction tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final credit = tx.isCredit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.rLg,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: tx.type.color.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(tx.type.icon, color: tx.type.color, size: 20),
          ),
          title: Text(tx.description.isEmpty ? tx.type.label : tx.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              if (tx.createdAt != null) DateFormat('d MMM · HH:mm', 'fr_FR').format(tx.createdAt!),
              if (tx.reference.isNotEmpty) 'Réf. ${tx.reference}',
            ].join(' · '),
            style: AppTypography.caption.copyWith(fontSize: 12),
          ),
          trailing: Text(
            '${credit ? '+' : '−'} ${Formatters.money(tx.amount.abs().round())}',
            style: AppTypography.bodyLg.copyWith(color: credit ? AppColors.emeraldDeep : AppColors.danger, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
