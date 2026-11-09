import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// An in-app notification (inbox item or WebSocket popup).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.event,
    required this.title,
    required this.body,
    this.rideId,
    this.data = const {},
    this.isRead = false,
    this.createdAt,
    this.popupTtl = const Duration(seconds: 5),
    this.highPriority = false,
  });

  final int id;
  final String event;
  final String title;
  final String body;
  final int? rideId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;
  final Duration popupTtl;
  final bool highPriority;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final popup = (j['popup'] as Map?)?.cast<String, dynamic>() ?? const {};
    final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppNotification(
      id: (j['id'] as num?)?.toInt() ?? 0,
      event: '${j['event'] ?? ''}',
      title: '${j['title'] ?? ''}',
      body: '${j['body'] ?? ''}',
      rideId: (j['ride_id'] as num?)?.toInt() ??
          (j['ride'] as num?)?.toInt() ??
          (data['ride_id'] as num?)?.toInt(),
      data: data,
      isRead: j['is_read'] == true,
      createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal(),
      popupTtl: Duration(seconds: (popup['ttl_s'] as num?)?.toInt() ?? 5),
      highPriority: popup['priority'] == 'high',
    );
  }

  AppNotification markRead() => AppNotification(
    id: id,
    event: event,
    title: title,
    body: body,
    rideId: rideId,
    data: data,
    isRead: true,
    createdAt: createdAt,
    popupTtl: popupTtl,
    highPriority: highPriority,
  );

  /// Visual identity of each event type.
  ({IconData icon, Color color}) get visual => switch (event) {
    'ride_offer' => (icon: Icons.local_taxi_rounded, color: AppColors.brandDeep),
    'driver_assigned' => (icon: Icons.directions_car_rounded, color: AppColors.info),
    'driver_arrived' => (icon: Icons.where_to_vote_rounded, color: AppColors.emerald),
    'ride_started' => (icon: Icons.route_rounded, color: AppColors.emerald),
    'ride_invoice' => (icon: Icons.receipt_long_rounded, color: AppColors.ink),
    'ride_cancelled' || 'driver_cancelled' => (icon: Icons.cancel_rounded, color: AppColors.danger),
    'no_driver' => (icon: Icons.search_off_rounded, color: AppColors.warning),
    'payment_confirmed' || 'wallet_payout' => (
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.emeraldDeep,
    ),
    _ => (icon: Icons.notifications_rounded, color: AppColors.brandDeep),
  };
}
