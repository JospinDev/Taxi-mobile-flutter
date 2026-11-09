import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../providers/notifications_providers.dart';

/// Round bell button with live unread badge; shakes when a new one arrives.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, required this.route, this.dark = false});

  /// Inbox route for the current role.
  final String route;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final bell = Icon(
      unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
      size: 22,
      color: dark ? Colors.white : AppColors.ink,
    );
    return Material(
      color: dark ? AppColors.surfaceDark : Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: const Color(0x260F172A),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.danger,
            offset: const Offset(6, -6),
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: unread > 0
                ? bell
                    .animate(key: ValueKey(unread), onPlay: (c) => c.forward())
                    .shake(hz: 5, rotation: .12, duration: 600.ms)
                : bell,
          ),
        ),
      ),
    );
  }
}

/// Glassy header pill used over maps.
class MapHeaderCard extends StatelessWidget {
  const MapHeaderCard({super.key, required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: (dark ? AppColors.surfaceDark : Colors.white).withValues(alpha: .96),
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadow.floating,
      ),
      child: child,
    );
  }
}
