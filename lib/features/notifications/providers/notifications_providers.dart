import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_controller.dart';
import '../../shared/providers/realtime_providers.dart';
import '../../shared/providers/repository_providers.dart';
import '../data/notification_model.dart';

/// Unread badge — seeded from the API, then kept live by the WebSocket.
class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() {
    final authenticated = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
    if (!authenticated) return 0;

    final sub = ref.watch(realtimeClientProvider).events.listen((e) {
      final count = (e.data['unread_count'] as num?)?.toInt();
      if ((e.event == 'notification' || e.event == 'notification.unread_count') && count != null) {
        state = count;
      }
    });
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      state = await ref.read(notificationsRepositoryProvider).unreadCount();
    } catch (_) {}
  }

  void set(int value) => state = value < 0 ? 0 : value;

  /// Marks one notification read without loading the inbox.
  Future<void> markRead(int id) async {
    try {
      state = await ref.read(notificationsRepositoryProvider).markRead(id);
    } catch (_) {}
  }
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

/// Inbox list state with infinite scroll.
class InboxState {
  const InboxState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  InboxState copyWith({List<AppNotification>? items, int? page, bool? hasMore, bool? loadingMore}) =>
      InboxState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class InboxNotifier extends AsyncNotifier<InboxState> {
  @override
  Future<InboxState> build() async {
    final sub = ref.watch(realtimeClientProvider).events.listen((e) {
      if (e.event != 'notification') return;
      final current = state.value;
      if (current == null) return;
      final n = AppNotification.fromJson(e.data);
      if (current.items.any((i) => i.id == n.id)) return;
      state = AsyncData(current.copyWith(items: [n, ...current.items]));
    });
    ref.onDispose(sub.cancel);

    final first = await ref.read(notificationsRepositoryProvider).list();
    return InboxState(items: first.results, page: 1, hasMore: first.hasNext);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(notificationsRepositoryProvider).list(page: current.page + 1);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.results],
          page: current.page + 1,
          hasMore: next.hasNext,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(items: [for (final i in current.items) i.id == n.id ? i.markRead() : i]),
      );
    }
    try {
      final unread = await ref.read(notificationsRepositoryProvider).markRead(n.id);
      ref.read(unreadCountProvider.notifier).set(unread);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(items: [for (final i in current.items) i.markRead()]));
    }
    ref.read(unreadCountProvider.notifier).set(0);
    await ref.read(notificationsRepositoryProvider).markAllRead();
  }
}

final inboxProvider = AsyncNotifierProvider.autoDispose<InboxNotifier, InboxState>(InboxNotifier.new);

/// Queue of popups to show over the app (one at a time, auto-dismissed).
class InAppPopupNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    final authenticated = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
    if (!authenticated) return const [];
    final sub = ref.watch(realtimeClientProvider).events.listen((e) {
      if (e.event != 'notification') return;
      final n = AppNotification.fromJson(e.data);
      if (state.any((i) => i.id == n.id)) return;
      // High-priority popups jump the queue (ride offer, driver arrived…).
      state = n.highPriority ? [n, ...state] : [...state, n];
    });
    ref.onDispose(sub.cancel);
    return const [];
  }

  void dismiss(int id) => state = [for (final n in state) if (n.id != id) n];
}

final inAppPopupProvider = NotifierProvider<InAppPopupNotifier, List<AppNotification>>(
  InAppPopupNotifier.new,
);
