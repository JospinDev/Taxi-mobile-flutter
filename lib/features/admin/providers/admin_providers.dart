import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/models/driver_profile_model.dart';
import '../../auth/data/models/user_model.dart';
import '../../shared/providers/repository_providers.dart';

/// ── Admin · drivers ─────────────────────────────────────────────────────────

class DriversFilter {
  const DriversFilter({this.status, this.isApproved, this.search = ''});

  final String? status;
  final bool? isApproved;
  final String search;

  DriversFilter copyWith({
    String? Function()? status,
    bool? Function()? isApproved,
    String? search,
  }) => DriversFilter(
    status: status != null ? status() : this.status,
    isApproved: isApproved != null ? isApproved() : this.isApproved,
    search: search ?? this.search,
  );

  Map<String, dynamic> toQuery() => {
    if (status != null && status!.isNotEmpty) 'status': status,
    if (isApproved != null) 'is_approved': isApproved,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'ordering': '-created_at',
  };
}

/// Paginated driver list (admin) with live approve/suspend mutations.
class AdminDriversNotifier extends AsyncNotifier<List<DriverProfile>> {
  DriversFilter _filter = const DriversFilter();
  bool _hasNext = false;
  int _count = 0;

  DriversFilter get filter => _filter;
  bool get hasNext => _hasNext;
  int get count => _count;
  int _page = 1;

  @override
  Future<List<DriverProfile>> build() async {
    _page = 1;
    final res = await ref
        .read(adminAccountsRepositoryProvider)
        .listDrivers(filters: _filter.toQuery(), page: 1);
    _hasNext = res.hasNext;
    _count = res.count;
    return res.results;
  }

  Future<void> setFilter(DriversFilter f) async {
    _filter = f;
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    if (!_hasNext || state.isLoading) return;
    final res = await ref
        .read(adminAccountsRepositoryProvider)
        .listDrivers(filters: _filter.toQuery(), page: ++_page);
    _hasNext = res.hasNext;
    state = AsyncData([...state.value ?? [], ...res.results]);
  }

  Future<void> approve(int id) async {
    final updated = await ref
        .read(adminAccountsRepositoryProvider)
        .approveDriver(id);
    _update(updated);
  }

  Future<void> suspend(int id) async {
    final updated = await ref
        .read(adminAccountsRepositoryProvider)
        .suspendDriver(id);
    _update(updated);
  }

  void _update(DriverProfile updated) => state = AsyncData([
    for (final d in state.value ?? [])
      if (d.id == updated.id) updated else d,
  ]);
}

final adminDriversProvider =
    AsyncNotifierProvider<AdminDriversNotifier, List<DriverProfile>>(
      AdminDriversNotifier.new,
    );

final adminDriverDetailProvider = FutureProvider.autoDispose
    .family<DriverProfile, int>(
      (ref, id) => ref.watch(adminAccountsRepositoryProvider).getDriver(id),
    );

/// ── Admin · users ───────────────────────────────────────────────────────────

class UsersFilter {
  const UsersFilter({this.role, this.search = ''});

  final String? role;
  final String search;

  Map<String, dynamic> toQuery() => {
    if (role != null && role!.isNotEmpty) 'role': role,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'ordering': '-created_at',
  };
}

class AdminUsersNotifier extends AsyncNotifier<List<AppUser>> {
  UsersFilter _filter = const UsersFilter();
  bool _hasNext = false;
  int _page = 1;

  UsersFilter get filter => _filter;
  bool get hasNext => _hasNext;

  @override
  Future<List<AppUser>> build() async {
    _page = 1;
    final res = await ref
        .read(adminAccountsRepositoryProvider)
        .listUsers(filters: _filter.toQuery(), page: 1);
    _hasNext = res.hasNext;
    return res.results;
  }

  Future<void> setFilter(UsersFilter f) async {
    _filter = f;
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    if (!_hasNext || state.isLoading) return;
    final res = await ref
        .read(adminAccountsRepositoryProvider)
        .listUsers(filters: _filter.toQuery(), page: ++_page);
    _hasNext = res.hasNext;
    state = AsyncData([...state.value ?? [], ...res.results]);
  }

  Future<AppUser> toggleActive(int id) async {
    final updated = await ref
        .read(adminAccountsRepositoryProvider)
        .toggleActive(id);
    _update(updated);
    return updated;
  }

  Future<void> remove(int id) async {
    await ref.read(adminAccountsRepositoryProvider).deleteUser(id);
    state = AsyncData([
      for (final u in state.value ?? [])
        if (u.id != id) u,
    ]);
  }

  void _update(AppUser updated) => state = AsyncData([
    for (final u in state.value ?? [])
      if (u.id == updated.id) updated else u,
  ]);
}

final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersNotifier, List<AppUser>>(
      AdminUsersNotifier.new,
    );

final adminUserDetailProvider = FutureProvider.autoDispose.family<AppUser, int>(
  (ref, id) => ref.watch(adminAccountsRepositoryProvider).getUser(id),
);

/// ── Admin · dashboard ───────────────────────────────────────────────────────

/// Latest drivers awaiting approval — surfaced on the portal home.
final pendingDriversProvider = FutureProvider.autoDispose<List<DriverProfile>>((
  ref,
) async {
  final res = await ref.watch(adminAccountsRepositoryProvider).listDrivers(
    filters: const {'is_approved': false, 'ordering': '-created_at'},
    pageSize: 5,
  );
  return res.results;
});
