import '../../../core/constants/api_paths.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/api_client.dart';
import 'notification_model.dart';

/// In-app inbox API (backend module 8).
class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<Paginated<AppNotification>> list({int page = 1}) async {
    final data = await _api.get(ApiPaths.notifications, query: {'page': page, 'page_size': 20});
    return Paginated.fromJson((data as Map).cast<String, dynamic>(), AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final data = await _api.get(ApiPaths.notificationsUnread);
    return ((data as Map)['unread_count'] as num?)?.toInt() ?? 0;
  }

  /// Returns the new unread count.
  Future<int> markRead(int id) async {
    final data = await _api.post(ApiPaths.notificationRead(id));
    return ((data as Map)['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAllRead() => _api.post(ApiPaths.notificationsReadAll);
}
