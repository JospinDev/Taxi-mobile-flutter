import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/driver_profile_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../providers/admin_providers.dart';

const _months = [
  'JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUN',
  'JUL', 'AOÛ', 'SEP', 'OCT', 'NOV', 'DÉC',
];

/// ADMIN — portal home (Student-Portal style): gradient header with search,
/// "Accès rapide" grid linking to every console section, and a feed of
/// pending driver approvals.
///
/// No [Scaffold] here on purpose — the screen renders inside [AdminShell]'s
/// body so `Scaffold.of(context)` can open the shared navigation drawer.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  String _query = '';

  List<_QuickAccess> get _filteredTiles {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _tiles;
    return [
      for (final t in _tiles)
        if (t.title.toLowerCase().contains(q) ||
            t.subtitle.toLowerCase().contains(q))
          t,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final pending = ref.watch(pendingDriversProvider);
    final pendingCount = pending.asData?.value.length ?? 0;
    final top = MediaQuery.of(context).padding.top;
    final name = user?.firstName ?? user?.username ?? 'Admin';

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(top, name, pendingCount),
            const SizedBox(height: AppSpace.xl),
            _buildSectionTitle(
              'Accès rapide',
              trailing: 'Tout voir',
              onTrailing: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(height: AppSpace.sm),
            _buildGrid(),
            const SizedBox(height: AppSpace.xl),
            _buildSectionTitle(
              'Demandes en attente',
              trailing: 'Tout voir',
              onTrailing: () => context.go(Routes.adminDrivers),
            ),
            const SizedBox(height: AppSpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: _PendingCard(pending: pending),
            ),
            const SizedBox(height: AppSpace.xxxl),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(double top, String name, int pendingCount) {
    final u = ref.read(currentUserProvider);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpace.xl,
        top + AppSpace.md,
        AppSpace.xl,
        AppSpace.xl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.portalGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpace.sm + 2),
              Expanded(
                child: Text(
                  'Console admin',
                  style: AppTypography.h2.copyWith(color: Colors.white),
                ),
              ),
              _BellBadge(count: pendingCount),
              const SizedBox(width: AppSpace.xs),
              AppAvatar(
                firstName: u?.firstName,
                lastName: u?.lastName,
                username: u?.username,
                size: 42,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Bonjour, $name 👋',
            style: AppTypography.h3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            pendingCount > 0
                ? '$pendingCount demande${pendingCount > 1 ? 's' : ''} en attente d\'approbation'
                : 'Tout est à jour — belle journée !',
            style: AppTypography.caption.copyWith(
              color: pendingCount > 0
                  ? AppColors.warning
                  : Colors.white.withValues(alpha: .75),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rPill,
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 22, color: AppColors.muted),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Rechercher un espace…',
                isDense: true,
                filled: false,
                border: InputBorder.none,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _query = ''),
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(
    String title, {
    required String trailing,
    required VoidCallback onTrailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Row(
        children: [
          Text(title, style: AppTypography.h3),
          const Spacer(),
          GestureDetector(
            onTap: onTrailing,
            child: Text(
              trailing,
              style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brandDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final tiles = _filteredTiles;
    if (tiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Center(
          child: Text(
            'Aucun espace ne correspond à « $_query »',
            style: AppTypography.caption,
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpace.sm,
        crossAxisSpacing: AppSpace.sm,
        childAspectRatio: 0.82,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) => _QuickTile(
        tile: tiles[i],
        onTap: () => context.go(tiles[i].path),
      ).entrance(index: i),
    );
  }
}

// ── Notification bell with pending badge ───────────────────────────────────

class _BellBadge extends StatelessWidget {
  const _BellBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.go(Routes.adminDrivers),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: AppRadius.rPill,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Quick-access tile ──────────────────────────────────────────────────────

class _QuickAccess {
  const _QuickAccess(
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.background,
    this.path,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String path;
}

const _tiles = <_QuickAccess>[
  _QuickAccess(
    'Courses',
    'Suivi en temps réel',
    Icons.local_taxi_rounded,
    Color(0xFFE8A400),
    Color(0xFFFFF6DC),
    Routes.adminRides,
  ),
  _QuickAccess(
    'Portefeuilles',
    'Commissions & versements',
    Icons.account_balance_wallet_rounded,
    Color(0xFF059669),
    Color(0xFFE3F9F0),
    Routes.adminWallets,
  ),
  _QuickAccess(
    'Chauffeurs',
    'Approbation & statut',
    Icons.groups_rounded,
    Color(0xFF6366F1),
    Color(0xFFEEF0FF),
    Routes.adminDrivers,
  ),
  _QuickAccess(
    'Utilisateurs',
    'Comptes de la plateforme',
    Icons.manage_accounts_rounded,
    Color(0xFFF97316),
    Color(0xFFFFF1E6),
    Routes.adminUsers,
  ),
  _QuickAccess(
    'Véhicules',
    'Documents & activation',
    Icons.directions_car_rounded,
    Color(0xFF10B981),
    Color(0xFFE7F8F1),
    Routes.adminVehicles,
  ),
  _QuickAccess(
    'Types de documents',
    'Configuration',
    Icons.folder_copy_rounded,
    Color(0xFF3B82F6),
    Color(0xFFE8F1FE),
    Routes.adminDocTypes,
  ),
  _QuickAccess(
    'Contrats',
    'Création & activation',
    Icons.description_rounded,
    Color(0xFFF59E0B),
    Color(0xFFFFF6DC),
    Routes.adminContracts,
  ),
  _QuickAccess(
    'Nouveau contrat',
    'Créer & activer',
    Icons.post_add_rounded,
    Color(0xFF14B8A6),
    Color(0xFFDFF7F3),
    Routes.adminContractNew,
  ),
];

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.tile, required this.onTap});

  final _QuickAccess tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: tile.background,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: tile.iconColor.withValues(alpha: .12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tile.iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(tile.icon, size: 18, color: Colors.white),
            ),
            const Spacer(),
            Text(
              tile.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tile.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.muted,
                      height: 1.25,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.faint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



// ── Pending approvals card ─────────────────────────────────────────────────

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.pending});

  final AsyncValue<List<DriverProfile>> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadow.soft,
      ),
      child: pending.when(
        data: (drivers) {
          if (drivers.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Center(
                child: Text(
                  'Aucune demande en attente 🎉',
                  style: AppTypography.caption,
                ),
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < drivers.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _PendingRow(driver: drivers[i]),
              ],
            ],
          );
        },
        loading: () => const Column(
          children: [
            SkeletonBox(height: 56),
            SizedBox(height: 10),
            SkeletonBox(height: 56),
          ],
        ),
        error: (e, _) => ErrorView(
          title: 'Impossible de charger les demandes',
          message: '$e',
          onRetry: () => ref.invalidate(pendingDriversProvider),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.driver});

  final DriverProfile driver;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(driver.createdAt ?? '');
    final day = createdAt != null ? '${createdAt.day}' : '–';
    final month = createdAt != null ? _months[createdAt.month - 1] : '';
    final name = Formatters.fullName(
      driver.user.firstName,
      driver.user.lastName,
      fallback: driver.user.username,
    );

    return InkWell(
      onTap: () => context.go(Routes.adminDrivers),
      borderRadius: AppRadius.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm - 2),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: AppRadius.rMd,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    month,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.info,
                      letterSpacing: .5,
                    ),
                  ),
                  Text(day, style: AppTypography.h3.copyWith(fontSize: 17)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLg.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    driver.licenseNumber?.isNotEmpty == true
                        ? 'Licence ${driver.licenseNumber}'
                        : 'Nouvelle demande de chauffeur',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            const StatusChip(
              label: 'En attente',
              tone: AppTone.warning,
              small: true,
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.faint,
            ),
          ],
        ),
      ),
    );
  }
}

