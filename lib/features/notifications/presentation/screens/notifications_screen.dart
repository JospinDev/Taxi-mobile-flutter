import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_states.dart';
import '../../data/notification_model.dart';
import '../../providers/notifications_providers.dart';

/// Inbox of in-app notifications, grouped by day, with infinite scroll.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(inboxProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(AppNotification n) {
    ref.read(inboxProvider.notifier).markRead(n);
    final role = ref.read(authControllerProvider).role;
    if (role == UserRole.driver) {
      if (n.event == 'payment_confirmed' || n.event == 'wallet_payout') {
        context.push(Routes.driverWallet);
      } else if (n.rideId != null) {
        context.push(Routes.driverRideDetail(n.rideId!));
      }
    } else if (n.rideId != null) {
      context.push(Routes.clientRideDetail(n.rideId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: () => ref.read(inboxProvider.notifier).markAllRead(),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tout lire'),
            ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
      body: inbox.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 78))],
        ),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(inboxProvider)),
        data: (state) {
          if (state.items.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_off_outlined,
              title: 'Aucune notification',
              message: 'Les nouvelles de vos courses apparaîtront ici en temps réel.',
            );
          }
          final rows = _groupByDay(state.items);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inboxProvider);
              await ref.read(unreadCountProvider.notifier).refresh();
            },
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.xxl),
              itemCount: rows.length + (state.loadingMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= rows.length) {
                  return const Padding(padding: EdgeInsets.all(AppSpace.md), child: Center(child: CircularProgressIndicator()));
                }
                final row = rows[i];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, AppSpace.md, 4, AppSpace.xs),
                    child: Text(row.toUpperCase(), style: AppTypography.overline),
                  );
                }
                final n = row as AppNotification;
                return _NotificationTile(notification: n, onTap: () => _open(n)).entrance(index: i);
              },
            ),
          );
        },
      ),
    );
  }

  static List<Object> _groupByDay(List<AppNotification> items) {
    final out = <Object>[];
    String? last;
    final now = DateTime.now();
    for (final n in items) {
      final d = n.createdAt ?? now;
      final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
      final label = switch (diff) {
        0 => 'Aujourd\'hui',
        1 => 'Hier',
        _ => DateFormat('EEEE d MMMM', 'fr_FR').format(d),
      };
      if (label != last) out.add(label);
      last = label;
      out.add(n);
    }
    return out;
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final visual = n.visual;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: n.isRead ? AppColors.surface : AppColors.brandSoft.withValues(alpha: .55),
        borderRadius: AppRadius.rLg,
        child: InkWell(
          borderRadius: AppRadius.rLg,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.rLg,
              border: Border.all(color: n.isRead ? AppColors.line : AppColors.brand.withValues(alpha: .5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: visual.color.withValues(alpha: .12), shape: BoxShape.circle),
                  child: Icon(visual.icon, size: 20, color: visual.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyLg.copyWith(
                                color: AppColors.ink,
                                fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            Formatters.timeAgo(n.createdAt?.toIso8601String()),
                            style: AppTypography.caption.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(n.body, style: AppTypography.body.copyWith(color: AppColors.inkSoft, height: 1.4)),
                    ],
                  ),
                ),
                if (!n.isRead)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
