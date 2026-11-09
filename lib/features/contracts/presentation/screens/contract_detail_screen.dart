import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../providers/contract_providers.dart';

/// DRIVER — read a contract in full, accept the terms, sign electronically.
///
/// `POST /contracts/{id}/sign/` (empty body) seals the contract with a
/// security hash returned by the backend — surfaced on the success view.
class ContractDetailScreen extends ConsumerStatefulWidget {
  const ContractDetailScreen({super.key, required this.contractId});

  final int contractId;

  @override
  ConsumerState<ContractDetailScreen> createState() =>
      _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> {
  bool _agreed = false;
  bool _signing = false;

  /// Local mirror so the success view shows instantly after signing.
  String? _signedHash;
  bool _signed = false;

  Future<void> _sign(int id) async {
    if (!_agreed) {
      AppToast.error(
        context,
        'Cochez « J\'ai lu et j\'accepte » pour signer.',
      );
      return;
    }
    setState(() => _signing = true);
    try {
      final signed = await ref
          .read(driverContractsProvider.notifier)
          .sign(id);
      if (!mounted) return;
      setState(() {
        _signed = true;
        _signedHash = signed.signatureHash;
      });
      ref.invalidate(contractDetailProvider(id));
      AppToast.success(context, 'Contrat signé avec succès ✓');
    } catch (e) {
      if (!mounted) return;
      AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractDetailProvider(widget.contractId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Contrat #${widget.contractId}')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () =>
              ref.invalidate(contractDetailProvider(widget.contractId)),
        ),
        data: (contract) {
          final isSigned = _signed || contract.isSigned;
          final hash = _signedHash ?? contract.signatureHash;
          return isSigned
              ? _SignedView(
                  hash: hash,
                  signedAt: contract.signedAt,
                  commission: contract.commission,
                )
              : _SignableView(
                  content: contract.content,
                  commission: contract.commission,
                  agreed: _agreed,
                  signing: _signing,
                  onToggle: (v) => setState(() => _agreed = v),
                  onSign: () => _sign(contract.id),
                );
        },
      ),
    );
  }
}

class _SignableView extends StatelessWidget {
  const _SignableView({
    required this.content,
    required this.commission,
    required this.agreed,
    required this.signing,
    required this.onToggle,
    required this.onSign,
  });

  final String content;
  final double commission;
  final bool agreed;
  final bool signing;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.lg,
            ),
            children: [
              Container(
                padding: AppSpace.card,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: AppRadius.rXl,
                  boxShadow: AppShadow.brand,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_rounded,
                      color: AppColors.ink,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contrat de partenariat',
                            style: AppTypography.h3,
                          ),
                          Text(
                            'Commission : ${commission.toStringAsFixed(0)}%',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text('Conditions', style: AppTypography.overline),
              const SizedBox(height: AppSpace.xs),
              AppCard(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Text(
                  content.isEmpty
                      ? 'Aucun contenu pour ce contrat.'
                      : content,
                  style: AppTypography.body.copyWith(height: 1.65),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadius.rMd,
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: agreed,
                      onChanged: signing
                          ? null
                          : (v) => onToggle(v ?? false),
                      activeColor: AppColors.emerald,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: signing
                            ? null
                            : () => onToggle(!agreed),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'J\'ai lu et j\'accepte les termes du contrat.',
                            style: AppTypography.bodyLg.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.md,
            ),
            child: AppButton(
              label: signing
                  ? 'Signature en cours…'
                  : 'Signer électroniquement',
              icon: Icons.draw_rounded,
              loading: signing,
              onPressed: agreed ? onSign : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignedView extends StatelessWidget {
  const _SignedView({
    required this.hash,
    required this.signedAt,
    required this.commission,
  });

  final String? hash;
  final String? signedAt;
  final double commission;

  Future<void> _copy(BuildContext context) async {
    if (hash == null || hash!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: hash!));
    if (context.mounted) AppToast.success(context, 'Hash copié.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        const SizedBox(height: AppSpace.lg),
        Container(
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: const BoxDecoration(
            color: AppColors.emeraldSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_rounded,
            size: 54,
            color: AppColors.emeraldDeep,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'Contrat signé',
          textAlign: TextAlign.center,
          style: AppTypography.h1,
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Votre contrat est scellé et ne peut plus être modifié. '
          'Une copie reste consultable à tout moment.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: AppColors.emeraldDeep,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Signature électronique',
                    style: AppTypography.bodyLg.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              _info('Commission', '${commission.toStringAsFixed(0)}%'),
              _info('Signé le', _fmtDate(signedAt)),
              const SizedBox(height: AppSpace.sm),
              Text('Hash de sécurité', style: AppTypography.overline),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _copy(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        (hash == null || hash!.isEmpty)
                            ? '—'
                            : hash!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Appuyez pour copier',
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AppButton(
          label: 'J\'ai terminé',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: AppTypography.caption),
        ),
        Text(
          value,
          style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}
