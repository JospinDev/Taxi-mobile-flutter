import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/features/shared/providers/repository_providers.dart';

import '../data/models/pricing_rule_model.dart';

/// ── Active pricing (client · driver · admin) ────────────────────────────────

/// The single active grille tarifaire. 404s when none is active — callers
/// should show a graceful fallback. Invalidate after any admin mutation.
final activePricingProvider = FutureProvider<PricingRule>(
  (ref) => ref.watch(pricingRepositoryProvider).active(),
);

/// ── Admin · all grilles ─────────────────────────────────────────────────────

class PricingRulesNotifier extends AsyncNotifier<List<PricingRule>> {
  bool _hasNext = false;
  int _page = 1;

  bool get hasNext => _hasNext;

  @override
  Future<List<PricingRule>> build() async {
    _page = 1;
    final res = await ref
        .read(pricingRepositoryProvider)
        .list(page: 1, filters: {'ordering': '-created_at'});
    _hasNext = res.hasNext;
    return res.results;
  }

  Future<void> refresh() async => ref.invalidateSelf();

  Future<void> loadMore() async {
    if (!_hasNext || state.isLoading) return;
    final res = await ref
        .read(pricingRepositoryProvider)
        .list(page: ++_page, filters: {'ordering': '-created_at'});
    _hasNext = res.hasNext;
    state = AsyncData([...state.value ?? [], ...res.results]);
  }

  Future<PricingRule> create(Map<String, dynamic> body) async {
    final created = await ref.read(pricingRepositoryProvider).create(body);
    state = AsyncData([created, ...state.value ?? []]);
    return created;
  }

  Future<PricingRule> updateRule(int id, Map<String, dynamic> body) async {
    final updated = await ref.read(pricingRepositoryProvider).update(id, body);
    _replace(updated);
    return updated;
  }

  Future<void> remove(int id) async {
    await ref.read(pricingRepositoryProvider).delete(id);
    state = AsyncData([
      for (final r in state.value ?? [])
        if (r.id != id) r,
    ]);
  }

  Future<void> activate(int id) async {
    await ref.read(pricingRepositoryProvider).activate(id);
    // Only one grille can be active: rebuild the list so the previously
    // active one flips to inactive without a second round-trip.
    final res = await ref
        .read(pricingRepositoryProvider)
        .list(page: 1, filters: {'ordering': '-created_at'});
    state = AsyncData(res.results);
    ref.invalidate(activePricingProvider);
  }

  Future<void> deactivate(int id) async {
    await ref.read(pricingRepositoryProvider).deactivate(id);
    ref.invalidate(activePricingProvider);
    ref.invalidateSelf();
  }

  void _replace(PricingRule updated) => state = AsyncData([
    for (final r in state.value ?? [])
      if (r.id == updated.id) updated else r,
  ]);
}

final pricingRulesProvider =
    AsyncNotifierProvider<PricingRulesNotifier, List<PricingRule>>(
      PricingRulesNotifier.new,
    );
