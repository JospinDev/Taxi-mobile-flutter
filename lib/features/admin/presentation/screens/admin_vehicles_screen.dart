import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../driver/data/models/vehicle_model.dart';
import '../../../driver/providers/vehicle_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminVehiclesScreen extends ConsumerStatefulWidget {
  const AdminVehiclesScreen({super.key});

  @override
  ConsumerState<AdminVehiclesScreen> createState() =>
      _AdminVehiclesScreenState();
}

class _AdminVehiclesScreenState extends ConsumerState<AdminVehiclesScreen> {
  final _q = TextEditingController();
  String _f = 'all';

  static const _filters = [
    ('all', 'Tous'),
    ('active', 'Actifs'),
    ('inactive', 'Inactifs'),
    ('docs', 'Docs incomplets'),
  ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _matchesQuery(Vehicle v, String q) {
    if (q.isEmpty) return true;
    final plate = v.plateNumber.toLowerCase();
    final brand = v.brand.toLowerCase();
    final model = v.model.toLowerCase();
    final driver = (v.driverName ?? '').toLowerCase();
    return plate.contains(q) ||
        brand.contains(q) ||
        model.contains(q) ||
        driver.contains(q);
  }

  bool _matchesFilter(Vehicle v) {
    if (_f == 'active') return v.isActive;
    if (_f == 'inactive') return !v.isActive;
    if (_f == 'docs') return !v.requiredDocsValidated;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final vs = ref.watch(vehiclesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicules'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(vehiclesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Column(
              children: [
                AppTextField(
                  label: 'Rechercher (plaque, marque, chauffeur…)',
                  kind: AppFieldKind.search,
                  controller: _q,
                  prefixIcon: Icons.search_rounded,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final e in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _f = e.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _f == e.$1
                                    ? AppColors.ink
                                    : Colors.white,
                                borderRadius: AppRadius.rPill,
                                border: Border.all(
                                  color: _f == e.$1
                                      ? AppColors.ink
                                      : AppColors.line,
                                ),
                              ),
                              child: Text(
                                e.$2,
                                style: AppTypography.caption.copyWith(
                                  color: _f == e.$1
                                      ? Colors.white
                                      : AppColors.inkSoft,
                                  fontWeight: FontWeight.w700,
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
          Expanded(
            child: vs.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const SkeletonBox(height: 100),
              ),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(vehiclesProvider),
              ),
              data: (items) {
                final q = _q.text.trim().toLowerCase();
                final list = items
                    .where((v) => _matchesQuery(v, q) && _matchesFilter(v))
                    .toList();
                if (list.isEmpty) {
                  return const EmptyView(
                    icon: Icons.directions_car_outlined,
                    title: 'Aucun vehicule',
                    message: 'Aucun resultat pour ces filtres.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(vehiclesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final v = list[i];
                      final dv = v.documents.values
                          .where((d) => d.isValidated)
                          .length;
                      final allDone = dv == v.documents.length &&
                          v.documents.isNotEmpty;
                      return AppCard(
                        onTap: () =>
                            context.push(Routes.adminVehicleDetail(v.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSoft,
                                    borderRadius: AppRadius.rMd,
                                  ),
                                  child: const Icon(
                                    Icons.directions_car_rounded,
                                    color: AppColors.brandDeep,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${v.brand} ${v.model}',
                                        style: AppTypography.bodyLg.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${v.plateNumber} · ${v.driverName ?? '—'}',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip(
                                  label: v.isActive ? 'ACTIF' : 'INACTIF',
                                  tone: v.isActive
                                      ? AppTone.success
                                      : AppTone.neutral,
                                  small: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                StatusChip(
                                  label: 'DOCS $dv/${v.documents.length}',
                                  icon: Icons.description_outlined,
                                  tone: allDone
                                      ? AppTone.success
                                      : AppTone.warning,
                                  small: true,
                                ),
                                const SizedBox(width: 6),
                                if (v.requiredDocsValidated)
                                  const StatusChip(
                                    label: 'PRET',
                                    icon: Icons.verified_rounded,
                                    tone: AppTone.success,
                                    small: true,
                                  ),
                                const Spacer(),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.faint,
                                ),
                              ],
                            ),
                          ],
                        ),
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

