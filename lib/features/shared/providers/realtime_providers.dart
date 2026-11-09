import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_paths.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../auth/providers/auth_controller.dart';
import 'repository_providers.dart';

/// The user's personal WebSocket (`ws/notifications/`).
///
/// Connected while authenticated, closed on logout. Features subscribe to
/// [RealtimeClient.events] (offers, ride status, in-app notifications).
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(
    path: ApiPaths.wsNotifications,
    storage: ref.watch(tokenStorageProvider),
    // Any authenticated call refreshes an expired access token (Dio interceptor).
    onAuthExpired: () => ref.read(apiClientProvider).get(ApiPaths.notificationsUnread),
  );
  ref.listen<bool>(
    authControllerProvider.select((s) => s.isAuthenticated),
    (_, authenticated) => authenticated ? client.connect() : client.disconnect(),
    fireImmediately: true,
  );
  ref.onDispose(client.dispose);
  return client;
});
