import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/driver_profile_model.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../providers/admin_providers.dart';
import 'admin_shell.dart';

/// ADMIN — drivers list (GET /accounts/drivers/) with approve/suspend.
class AdminDriversScreen extends ConsumerStatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  ConsumerState<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends ConsumerState<AdminDriversScreen> {
  final _searchCtrl = TextEditingController();
  String? _status;
  bool? _approved;
  bool _initialized = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref
        .read(adminDriversProvider.notifier)
        .setFilter(
          DriversFilter(
            status: _status,
            isApproved: _approved,
            search: _searchCtrl.text,
          ),
        );
  }

  Future<void> _approve(DriverProfile d) async {
    final ok = await confirmDialog(
      context,
      title: 'Approuver ce chauffeur ?',
      message:
          '${Formatters.fullName(d.user.firstName, d.user.lastName, fallback: d.user.username)} '
          'pourra alors accepter des courses.',
      confirmLabel: 'Approuver',
      icon: Icons.verified_user_outlined,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(adminDriversProvider.notifier).approve(d.id);
      if (!mounted) return;
      AppToast.success(context, 'Chauffeur approuvé ✓');
    } catch (e) {
      if (!mounted) return;
      AppToast.apiError(context, e);
    }
  }

  Future<void> _suspend(DriverProfile d) async {
    final ok = await confirmDialog(
      context,
      title: 'Suspendre ce chauffeur ?',
      message:
          'Son compte repassera en attente et il ne pourra plus '
          'accepter de courses.',
      confirmLabel: 'Suspendre',
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(adminDriversProvider.notifier).suspend(d.id);
      if (!mounted) return;
      AppToast.success(context, 'Chauffeur suspendu.');
    } catch (e) {
      if (!mounted) return;
      AppToast.apiError(context, e);
    }
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: AppRadius.rPill,
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    final drivers = ref.watch(adminDriversProvider);
    final notifier = ref.read(adminDriversProvider.notifier);

    // One-shot initial filter sync (avoid loops on rebuilds).
    if (!_initialized) {
      _initialized = true;
      _status = notifier.filter.status;
      _approved = notifier.filter.isApproved;
      _searchCtrl.text = notifier.filter.search;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chauffeurs'),
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(adminDriversProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
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
                  label: 'Rechercher (nom, téléphone, plaque…)',
                  kind: AppFieldKind.search,
                  controller: _searchCtrl,
                  prefixIcon: Icons.search_rounded,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => _applyFilters(),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        'Tous',
                        _status == null && _approved == null,
                        () {
                          setState(() {
                            _status = null;
                            _approved = null;
                          });
                          _applyFilters();
                        },
                      ),
                      _filterChip('En attente', _status == 'pending', () {
                        setState(() {
                          _status = _status == 'pending' ? null : 'pending';
                          _approved = null;
                        });
                        _applyFilters();
                      }),
                      _filterChip('Disponibles', _status == 'available', () {
                        setState(() {
                          _status = _status == 'available' ? null : 'available';
                          _approved = null;
                        });
                        _applyFilters();
                      }),
                      _filterChip('Approuvés', _approved == true, () {
                        setState(() {
                          _approved = _approved == true ? null : true;
                          _status = null;
                        });
                        _applyFilters();
                      }),
                      _filterChip('Non approuvés', _approved == false, () {
                        setState(() {
                          _approved = _approved == false ? null : false;
                          _status = null;
                        });
                        _applyFilters();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: drivers.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(AppSpace.xl),
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const SkeletonBox(height: 96),
              ),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(adminDriversProvider),
              ),
              data: (items) {
                final approved = items.where((d) => d.isApproved).length;
                final online = items.where((d) => d.status.raw == 'available').length;
                final pending = items.where((d) => !d.isApproved).length;
                if (items.isEmpty) {
                  return const EmptyView(
                    icon: Icons.groups_outlined,
                    title: 'Aucun chauffeur trouvé',
                    message: 'Aucun résultat pour ces filtres.',
                  );
                }
                return Column(
                  children: [
                    _AdminStatsBar(stats: [
                      (value: '${items.length}', label: 'Total', color: AppColors.info),
                      (value: '$approved', label: 'Approuvés', color: AppColors.emerald),
                      (value: '$online', label: 'En ligne', color: AppColors.brand),
                      (value: '$pending', label: 'En attente', color: AppColors.warning),
                    ]),
                    Expanded(
                      child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminDriversProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl,
                      0,
                      AppSpace.xl,
                      AppSpace.xl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _DriverCard(
                      driver: items[i],
                      onTap: () =>
                          context.push(Routes.adminDriverDetail(items[i].id)),
                      onApprove: () => _approve(items[i]),
                      onSuspend: () => _suspend(items[i]),
                    ).entrance(index: i),
                  ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared admin stats bar ────────────────────────────────────────────────────

class _AdminStatsBar extends StatelessWidget {
  const _AdminStatsBar({required this.stats});
  final List<({String value, String label, Color color})> stats;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xs, AppSpace.xl, AppSpace.sm),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: AppSpace.md),
    decoration: BoxDecoration(gradient: AppColors.darkGradient, borderRadius: AppRadius.rLg),
    child: Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0)
            Container(width: 1, height: 32, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(stats[i].value, style: AppTypography.h3.copyWith(color: stats[i].color, fontSize: 22)),
                const SizedBox(height: 2),
                Text(stats[i].label, style: AppTypography.caption.copyWith(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Driver row card: avatar, name, status chips, quick approve/suspend.
class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.onTap,
    required this.onApprove,
    required this.onSuspend,
  });

  final DriverProfile driver;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final pending = !d.isApproved;
    final accentColor = pending
        ? AppColors.warning
        : d.status.raw == 'available'
            ? AppColors.emerald
            : AppColors.muted;

    return AppCard(
      onTap: onTap,
      animate: false,
      padding: const EdgeInsets.all(14),
      border: Border(left: BorderSide(color: accentColor, width: 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                firstName: d.user.firstName,
                lastName: d.user.lastName,
                username: d.user.username,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.fullName(
                        d.user.firstName,
                        d.user.lastName,
                        fallback: d.user.username,
                      ),
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${d.user.phone ?? '—'} · ${d.licenseNumber ?? '—'}',
                      style: AppTypography.caption.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(
                    label: d.isApproved ? 'APPROUVÉ' : 'EN ATTENTE',
                    icon: d.isApproved
                        ? Icons.verified_rounded
                        : Icons.hourglass_top_rounded,
                    tone: d.isApproved ? AppTone.success : AppTone.warning,
                    small: true,
                  ),
                  const SizedBox(height: 4),
                  StatusChip(
                    label: d.status.label.toUpperCase(),
                    tone: AppTone.forStatusKey(d.status.raw),
                    small: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat(Icons.star_rounded, Formatters.rating(d.rating)),
              const SizedBox(width: 14),
              _miniStat(Icons.route_rounded, '${d.totalRides} courses'),
              const Spacer(),
              if (pending)
                _ActionButton(
                  label: 'Approuver',
                  icon: Icons.check_rounded,
                  color: AppColors.emerald,
                  onTap: onApprove,
                )
              else
                _ActionButton(
                  label: 'Suspendre',
                  icon: Icons.block_rounded,
                  color: AppColors.danger,
                  outlined: true,
                  onTap: onSuspend,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value) => Row(
    children: [
      Icon(icon, size: 15, color: AppColors.brandDeep),
      const SizedBox(width: 4),
      Text(
        value,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
