import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../data/notification_model.dart';
import '../../providers/notifications_providers.dart';

/// Shows in-app notifications as a popup sliding from the top of the screen.
///
/// One popup at a time; it disappears after its server-defined TTL (shown as
/// a draining bar), can be swiped up, and opens the relevant screen on tap.
/// Notifications received while offline are not lost: they are in the inbox.
class InAppNotificationHost extends ConsumerWidget {
  const InAppNotificationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(inAppPopupProvider);
    final router = ref.read(routerProvider);
    final location = router.routerDelegate.currentConfiguration.uri.path;

    // The driver dashboard already shows offers as a full card.
    final visible = queue.where((n) => !(n.event == 'ride_offer' && location == Routes.driverHome)).toList();
    final current = visible.isEmpty ? null : visible.first;

    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              reverseDuration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(begin: const Offset(0, -1.3), end: Offset.zero).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: current == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : _Popup(
                      key: ValueKey(current.id),
                      notification: current,
                      onDismiss: () => ref.read(inAppPopupProvider.notifier).dismiss(current.id),
                      onOpen: () {
                        ref.read(inAppPopupProvider.notifier).dismiss(current.id);
                        ref.read(unreadCountProvider.notifier).markRead(current.id);
                        final role = ref.read(authControllerProvider).role;
                        router.push(_targetFor(current, role));
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static String _targetFor(AppNotification n, UserRole role) {
    if (role == UserRole.driver) {
      return switch (n.event) {
        'ride_offer' || 'ride_cancelled' => Routes.driverHome,
        'payment_confirmed' || 'wallet_payout' => Routes.driverWallet,
        _ => Routes.driverNotifications,
      };
    }
    if (n.rideId != null) return Routes.clientRide;
    return Routes.clientNotifications;
  }
}

class _Popup extends StatefulWidget {
  const _Popup({super.key, required this.notification, required this.onDismiss, required this.onOpen});

  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  State<_Popup> createState() => _PopupState();
}

class _PopupState extends State<_Popup> with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: widget.notification.popupTtl,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.notification.highPriority) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _life.forward();
    _timer = Timer(widget.notification.popupTtl, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final visual = n.visual;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xs, AppSpace.sm, 0),
      child: Dismissible(
        key: ValueKey('popup-${n.id}'),
        direction: DismissDirection.up,
        onDismissed: (_) => widget.onDismiss(),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onOpen,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: AppRadius.rXl,
                border: Border.all(
                  color: n.highPriority ? visual.color.withValues(alpha: .7) : Colors.white12,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x660F172A), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -6),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: visual.color.withValues(alpha: .2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(visual.icon, size: 22, color: _onDark(visual.color)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(color: Colors.white70, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onDismiss,
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _life,
                    builder: (context, _) => LinearProgressIndicator(
                      value: 1 - _life.value,
                      minHeight: 3,
                      backgroundColor: Colors.white10,
                      color: _onDark(visual.color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ink is unreadable on the dark card: use brand yellow instead.
  static Color _onDark(Color c) => c == AppColors.ink ? AppColors.brand : c;
}
