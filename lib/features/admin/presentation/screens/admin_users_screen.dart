import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../providers/admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _S();
}

class _S extends ConsumerState<AdminUsersScreen> {
  final _q = TextEditingController();
  String? _role;
  void _apply() {
    ref
        .read(adminUsersProvider.notifier)
        .setFilter(UsersFilter(role: _role, search: _q.text));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Widget _chip(String l, bool s, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: f,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: s ? AppColors.ink : Colors.white,
          borderRadius: AppRadius.rPill,
          border: Border.all(color: s ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          l,
          style: AppTypography.caption.copyWith(
            color: s ? Colors.white : AppColors.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final n = ref.read(adminUsersProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(adminUsersProvider),
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
                  label: 'Rechercher',
                  kind: AppFieldKind.search,
                  controller: _q,
                  prefixIcon: Icons.search_rounded,
                  onChanged: (_) => _apply(),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('Tous', _role == null, () {
                        setState(() => _role = null);
                        _apply();
                      }),
                      _chip('Clients', _role == 'client', () {
                        setState(
                          () => _role = _role == 'client' ? null : 'client',
                        );
                        _apply();
                      }),
                      _chip('Chauffeurs', _role == 'driver', () {
                        setState(
                          () => _role = _role == 'driver' ? null : 'driver',
                        );
                        _apply();
                      }),
                      _chip('Admins', _role == 'admin', () {
                        setState(
                          () => _role = _role == 'admin' ? null : 'admin',
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
            child: users.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const SkeletonBox(height: 84),
              ),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(adminUsersProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyView(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Aucun utilisateur',
                    message: 'Aucun resultat pour ces filtres.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminUsersProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: items.length + (n.hasNext ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      if (i >= items.length) {
                        return Center(
                          child: TextButton.icon(
                            onPressed: () => n.loadMore(),
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Charger plus'),
                          ),
                        );
                      }
                      final u = items[i];
                      return AppCard(
                        onTap: () => context.push(Routes.adminUserDetail(u.id)),
                        child: Row(
                          children: [
                            AppAvatar(
                              firstName: u.firstName,
                              lastName: u.lastName,
                              username: u.username,
                              size: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Formatters.fullName(
                                      u.firstName,
                                      u.lastName,
                                      fallback: u.username,
                                    ),
                                    style: AppTypography.bodyLg.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '@${u.username} · ${u.phone ?? '—'}',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      StatusChip(
                                        label: u.role.label.toUpperCase(),
                                        tone: u.role == UserRole.client
                                            ? AppTone.info
                                            : u.role == UserRole.driver
                                            ? AppTone.brand
                                            : u.role == UserRole.admin
                                            ? AppTone.ink
                                            : AppTone.neutral,
                                        small: true,
                                      ),
                                      const SizedBox(width: 6),
                                      StatusChip(
                                        label: u.isActive
                                            ? 'ACTIF'
                                            : 'DESACTIVE',
                                        tone: u.isActive
                                            ? AppTone.success
                                            : AppTone.danger,
                                        small: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.faint,
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
