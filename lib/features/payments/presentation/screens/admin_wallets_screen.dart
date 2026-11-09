import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../admin/presentation/screens/admin_shell.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../data/wallet_model.dart';
import '../../providers/payments_providers.dart';

/// ADMIN — driver wallets: who owes what, payouts and adjustments.
class AdminWalletsScreen extends ConsumerStatefulWidget {
  const AdminWalletsScreen({super.key});

  @override
  ConsumerState<AdminWalletsScreen> createState() => _AdminWalletsScreenState();
}

class _AdminWalletsScreenState extends ConsumerState<AdminWalletsScreen> {
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(adminWalletsProvider(_search));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Portefeuilles'),
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm),
            child: AppTextField(
              label: 'Rechercher un chauffeur',
              prefixIcon: Icons.search_rounded,
              kind: AppFieldKind.search,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _search = v.trim()));
              },
            ),
          ),
          Expanded(
            child: wallets.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(adminWalletsProvider(_search))),
              data: (list) {
                if (list.isEmpty) return const EmptyView(icon: Icons.account_balance_wallet_outlined, title: 'Aucun portefeuille');
                final debt = list.where((w) => w.inDebt).fold<double>(0, (s, w) => s + w.balance.abs());
                final owed = list.where((w) => !w.inDebt).fold<double>(0, (s, w) => s + w.balance);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminWalletsProvider(_search)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.xxl),
                    children: [
                      Row(
                        children: [
                          _Summary(label: 'À récupérer', value: debt, color: AppColors.danger, icon: Icons.call_received_rounded),
                          const SizedBox(width: 10),
                          _Summary(label: 'À verser', value: owed, color: AppColors.emeraldDeep, icon: Icons.call_made_rounded),
                        ],
                      ).entrance(),
                      const SizedBox(height: AppSpace.md),
                      for (var i = 0; i < list.length; i++)
                        _WalletTile(wallet: list[i], onTap: () => _openActions(list[i])).entrance(index: i + 1),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openActions(Wallet wallet) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WalletActionsSheet(wallet: wallet),
    );
    if (changed == true) ref.invalidate(adminWalletsProvider(_search));
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.rLg, boxShadow: AppShadow.card),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(child: Text(Formatters.money(value.round()), style: AppTypography.bodyLg.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800))),
                  Text(label, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.wallet, required this.onTap});

  final Wallet wallet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final debt = wallet.inDebt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.rLg,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
          leading: CircleAvatar(
            backgroundColor: AppColors.brandSoft,
            child: Text(wallet.driverName.isEmpty ? '?' : wallet.driverName[0].toUpperCase(), style: AppTypography.h3.copyWith(color: AppColors.brandDeep)),
          ),
          title: Text(wallet.driverName, style: AppTypography.bodyLg.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
          subtitle: Text('Gains ${Formatters.money(wallet.totalEarned.round())} · Versé ${Formatters.money(wallet.totalPaidOut.round())}', style: AppTypography.caption.copyWith(fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${debt ? '−' : ''}${Formatters.money(wallet.balance.abs().round())}',
                style: AppTypography.bodyLg.copyWith(color: debt ? AppColors.danger : AppColors.emeraldDeep, fontWeight: FontWeight.w800),
              ),
              Text(debt ? 'doit' : 'à verser', style: AppTypography.caption.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletActionsSheet extends ConsumerStatefulWidget {
  const _WalletActionsSheet({required this.wallet});

  final Wallet wallet;

  @override
  ConsumerState<_WalletActionsSheet> createState() => _WalletActionsSheetState();
}

class _WalletActionsSheetState extends ConsumerState<_WalletActionsSheet> {
  bool _payout = true;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (amount == null || amount == 0) return AppToast.error(context, 'Montant invalide.');
    if (!_payout && _description.text.trim().isEmpty) return AppToast.error(context, 'Indiquez un motif.');
    setState(() => _busy = true);
    try {
      final repo = ref.read(paymentsRepositoryProvider);
      if (_payout) {
        await repo.payout(widget.wallet.id, amount, reference: _reference.text.trim(), description: _description.text.trim());
      } else {
        await repo.adjust(widget.wallet.id, amount, description: _description.text.trim(), reference: _reference.text.trim());
      }
      if (!mounted) return;
      AppToast.success(context, _payout ? 'Versement enregistré.' : 'Ajustement enregistré.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, MediaQuery.of(context).viewInsets.bottom + AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w.driverName, style: AppTypography.h2),
          Text(
            w.inDebt ? 'Doit ${Formatters.money(w.balance.abs().round())} de commissions' : 'Solde : ${Formatters.money(w.balance.round())}',
            style: AppTypography.caption.copyWith(color: w.inDebt ? AppColors.danger : AppColors.emeraldDeep, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.md),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Versement'), icon: Icon(Icons.north_east_rounded)),
              ButtonSegment(value: false, label: Text('Ajustement'), icon: Icon(Icons.tune_rounded)),
            ],
            selected: {_payout},
            onSelectionChanged: (s) => setState(() => _payout = s.first),
          ),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            label: _payout ? 'Montant versé (FBu)' : 'Montant signé (+ crédit / − débit)',
            controller: _amount,
            prefixIcon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            helper: _payout ? null : 'Ex. +5000 quand le chauffeur rembourse sa dette de commission.',
          ),
          const SizedBox(height: AppSpace.sm),
          AppTextField(label: 'Référence (mobile money, reçu…)', controller: _reference, prefixIcon: Icons.tag_rounded),
          const SizedBox(height: AppSpace.sm),
          AppTextField(label: _payout ? 'Note (facultatif)' : 'Motif', controller: _description, prefixIcon: Icons.notes_rounded),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: _payout ? 'Enregistrer le versement' : 'Enregistrer l\'ajustement',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
