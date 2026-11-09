import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_app/features/shared/providers/repository_providers.dart';
import '../data/models/contract_model.dart';

/// ── Driver · my contracts ────────────────────────────────────────────────────

/// The signed-in driver's own contracts (backend scopes them automatically).
class DriverContractsNotifier extends AsyncNotifier<List<Contract>> {
  @override
  Future<List<Contract>> build() async {
    final res = await ref
        .read(contractsRepositoryProvider)
        .list(filters: {'ordering': '-created_at'});
    return res.results;
  }

  Future<void> refresh() async => ref.invalidateSelf();

  /// Signs a contract — returns the sealed contract (with hash) for the
  /// success screen.
  Future<Contract> sign(int id) async {
    final signed = await ref.read(contractsRepositoryProvider).sign(id);
    state = AsyncData([
      for (final c in state.value ?? []) if (c.id == signed.id) signed else c,
    ]);
    return signed;
  }
}

final driverContractsProvider =
    AsyncNotifierProvider<DriverContractsNotifier, List<Contract>>(
      DriverContractsNotifier.new,
    );

/// ── Admin · contracts ────────────────────────────────────────────────────────

class ContractsFilter {
  const ContractsFilter({this.isActive, this.search = ''});

  final bool? isActive;
  final String search;

  Map<String, dynamic> toQuery() => {
    if (isActive != null) 'is_active': isActive,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'ordering': '-created_at',
  };
}

class AdminContractsNotifier extends AsyncNotifier<List<Contract>> {
  ContractsFilter _filter = const ContractsFilter();
  bool _hasNext = false;
  int _page = 1;

  ContractsFilter get filter => _filter;
  bool get hasNext => _hasNext;

  @override
  Future<List<Contract>> build() async {
    _page = 1;
    final res = await ref
        .read(contractsRepositoryProvider)
        .list(filters: _filter.toQuery(), page: 1);
    _hasNext = res.hasNext;
    return res.results;
  }

  Future<void> setFilter(ContractsFilter f) async {
    _filter = f;
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    if (!_hasNext || state.isLoading) return;
    final res = await ref
        .read(contractsRepositoryProvider)
        .list(filters: _filter.toQuery(), page: ++_page);
    _hasNext = res.hasNext;
    state = AsyncData([...state.value ?? [], ...res.results]);
  }

  Future<Contract> create({
    required int driver,
    required String commissionPercent,
    required String content,
  }) async {
    final created = await ref
        .read(contractsRepositoryProvider)
        .create(
          driver: driver,
          commissionPercent: commissionPercent,
          content: content,
        );
    state = AsyncData([created, ...state.value ?? []]);
    return created;
  }

  Future<void> activate(int id) async =>
      _replace(await ref.read(contractsRepositoryProvider).activate(id));

  Future<void> deactivate(int id) async =>
      _replace(await ref.read(contractsRepositoryProvider).deactivate(id));

  void _replace(Contract updated) => state = AsyncData([
    for (final c in state.value ?? []) if (c.id == updated.id) updated else c,
  ]);
}

final adminContractsProvider =
    AsyncNotifierProvider<AdminContractsNotifier, List<Contract>>(
      AdminContractsNotifier.new,
    );

final contractDetailProvider = FutureProvider.autoDispose.family<Contract, int>(
  (ref, id) => ref.watch(contractsRepositoryProvider).get(id),
);
