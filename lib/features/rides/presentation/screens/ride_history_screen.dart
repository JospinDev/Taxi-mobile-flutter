import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_states.dart';
import '../../providers/rides_providers.dart';
import '../widgets/ride_widgets.dart';

/// Ride history with status filters + infinite scroll.
/// Used by the client ("Mes courses"), the driver and the admin.
class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({
    super.key,
    required this.title,
    required this.detailRoute,
    this.showEarning = false,
    this.showParties = false,
    this.leading,
  });

  final String title;
  final String Function(int id) detailRoute;

  /// Driver: show the net earning instead of the fare.
  final bool showEarning;

  /// Admin: show client & driver names.
  final bool showParties;
  final Widget? leading;

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  final _scroll = ScrollController();
  int _filter = 0;

  static const _filters = <(String, String?)>[
    ('Toutes', null),
    ('En cours', 'searching,accepted,arrived,in_progress'),
    ('Terminées', 'completed'),
    ('Annulées', 'cancelled,no_driver'),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(rideListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _filter) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = i);
    ref.read(rideListProvider.notifier).setFilter(_filters[i].$2);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(rideListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        leading: widget.leading,
        automaticallyImplyLeading: widget.leading == null && context.canPop(),
        toolbarHeight: 64,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _filter;
                return GestureDetector(
                  onTap: () => _select(i),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.ink : AppColors.surface,
                      borderRadius: AppRadius.rPill,
                      border: Border.all(color: selected ? AppColors.ink : AppColors.line),
                    ),
                    child: Text(
                      _filters[i].$1,
                      style: AppTypography.caption.copyWith(
                        color: selected ? Colors.white : AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: list.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonBox(height: 140))],
        ),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(rideListProvider)),
        data: (state) {
          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(rideListProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyView(
                    icon: Icons.route_rounded,
                    title: 'Aucune course',
                    message: 'Vos trajets apparaîtront ici.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(rideListProvider);
              await ref.read(rideListProvider.future);
            },
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xxl),
              itemCount: state.items.length + (state.loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i >= state.items.length) {
                  return const Center(child: Padding(padding: EdgeInsets.all(AppSpace.md), child: CircularProgressIndicator()));
                }
                final ride = state.items[i];
                return RideListCard(
                  ride: ride,
                  showEarning: widget.showEarning,
                  showClient: widget.showParties,
                  onTap: () => context.push(widget.detailRoute(ride.id)),
                ).entrance(index: i);
              },
            ),
          );
        },
      ),
    );
  }
}
