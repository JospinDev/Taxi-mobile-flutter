import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../admin/presentation/screens/admin_shell.dart';
import '../../data/models/contract_model.dart';
import '../../providers/contract_providers.dart';

/// ADMIN — contracts management (GET/POST /contracts/, activate/deactivate).
class AdminContractsScreen extends ConsumerStatefulWidget {
  const AdminContractsScreen({super.key});

  @override
  ConsumerState<AdminContractsScreen> createState() =>
      _AdminContractsScreenState();
}

class _AdminContractsScreenState extends ConsumerState<AdminContractsScreen> {
  final _search = TextEditingController();
  bool? _active;
  bool _init = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    ref
        .read(adminContractsProvider.notifier)
        .setFilter(ContractsFilter(isActive: _active, search: _search.text));
  }

  Future<void> _activate(Contract c, bool on) async {
    final ok = await confirmDialog(
      context,
      title: on ? 'Activer ce contrat ?' : 'Désactiver ce contrat ?',
      message: on
          ? 'Les autres contrats de ce chauffeur seront automatiquement '
                'désactivés.'
          : 'Le chauffeur n\'aura plus de contrat actif.',
      confirmLabel: on ? 'Activer' : 'Désactiver',
      destructive: !on,
      icon: on ? Icons.check_circle_outline_rounded : Icons.block_rounded,
    );
    if (!ok || !mounted) return;
    try {
      if (on) {
        await ref.read(adminContractsProvider.notifier).activate(c.id);
      } else {
        await ref.read(adminContractsProvider.notifier).deactivate(c.id);
      }
      if (!mounted) return;
      AppToast.success(context, on ? 'Contrat activé.' : 'Contrat désactivé.');
    } catch (e) {
      if (!mounted) return;
      AppToast.apiError(context, e);
    }
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: AppRadius.rPill,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : AppColors.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final contracts = ref.watch(adminContractsProvider);
    final notifier = ref.read(adminContractsProvider.notifier);
    if (!_init) {
      _init = true;
      _active = notifier.filter.isActive;
      _search.text = notifier.filter.search;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Contrats'),
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(adminContractsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.adminContractNew),
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.xs,
              AppSpace.xl,
              AppSpace.sm,
            ),
            child: Column(
              children: [
                AppTextField(
                  label: 'Rechercher (chauffeur…)',
                  kind: AppFieldKind.search,
                  controller: _search,
                  prefixIcon: Icons.search_rounded,
                  onChanged: (_) => _apply(),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('Tous', _active == null, () {
                        setState(() => _active = null);
                        _apply();
                      }),
                      _chip('Actifs', _active == true, () {
                        setState(() => _active = _active == true ? null : true);
                        _apply();
                      }),
                      _chip('Inactifs', _active == false, () {
                        setState(
                          () => _active = _active == false ? null : false,
                        );
                        _apply();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: contracts.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(AppSpace.xl),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const SkeletonBox(height: 104),
              ),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(adminContractsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyView(
                    icon: Icons.description_outlined,
                    title: 'Aucun contrat',
                    message: 'Créez un contrat pour un chauffeur.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminContractsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl,
                      0,
                      AppSpace.xl,
                      AppSpace.xxl + 40,
                    ),
                    itemCount: items.length + (notifier.hasNext ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i >= items.length) {
                        return Center(
                          child: TextButton.icon(
                            onPressed: () => notifier.loadMore(),
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Charger plus'),
                          ),
                        );
                      }
                      final c = items[i];
                      return _ContractRow(
                        contract: c,
                        onActivate: () => _activate(c, true),
                        onDeactivate: () => _activate(c, false),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractRow extends StatelessWidget {
  const _ContractRow({
    required this.contract,
    required this.onActivate,
    required this.onDeactivate,
  });

  final Contract contract;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final c = contract;
    final signed = c.isSigned;
    final status = switch ((c.isActive, signed)) {
      (true, _) => ('ACTIF', AppTone.success, Icons.verified_rounded),
      (false, true) => ('SIGNÉ', AppTone.info, Icons.draw_rounded),
      _ => ('EN ATTENTE', AppTone.warning, Icons.hourglass_top_rounded),
    };

    return AppCard(
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
                      'Contrat #${c.id}',
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Chauffeur : ${c.driverName ?? '#${c.driverId}'} · '
                      'Commission ${c.commission.toStringAsFixed(0)}%',
                      style: AppTypography.caption.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: status.$1,
                icon: status.$3,
                tone: status.$2,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (c.isActive)
                _Action(
                  label: 'Désactiver',
                  icon: Icons.block_rounded,
                  color: AppColors.danger,
                  outlined: true,
                  onTap: onDeactivate,
                )
              else ...[
                if (!signed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: const StatusChip(
                      label: 'SIGNATURE REQUISE',
                      tone: AppTone.neutral,
                      small: true,
                    ),
                  ),
                _Action(
                  label: 'Activer',
                  icon: Icons.check_rounded,
                  color: AppColors.emerald,
                  onTap: onActivate,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: AppRadius.rPill,
          border: outlined ? Border.all(color: color, width: 1.3) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
