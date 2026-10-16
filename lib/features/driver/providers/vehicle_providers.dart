import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/repository_providers.dart';
import '../data/models/document_type_model.dart';
import '../data/models/vehicle_model.dart';

/// ── Document types ──────────────────────────────────────────────────────────

/// All document types (active ones by default) — drives the dynamic upload
/// grid on the driver side and the CRUD screen on the admin side.
class DocumentTypesNotifier extends AsyncNotifier<List<DocumentType>> {
  bool _activeOnly = true;

  @override
  Future<List<DocumentType>> build() async {
    final res = await ref
        .read(vehiclesRepositoryProvider)
        .documentTypes(filters: _activeOnly ? {'is_active': true} : null);
    final items = <DocumentType>[...res.results.whereType<DocumentType>()]
      ..sort(
        (DocumentType a, DocumentType b) => a.order.compareTo(b.order),
      );
    return items;
  }

  Future<void> setFilter({required bool activeOnly}) async {
    if (_activeOnly == activeOnly) return;
    _activeOnly = activeOnly;
    ref.invalidateSelf();
    await future;
  }

  Future<DocumentType> create(Map<String, dynamic> body) async {
    final created = await ref
        .read(vehiclesRepositoryProvider)
        .createDocumentType(body);
    state = AsyncData([...state.value ?? [], created]);
    return created;
  }

  Future<DocumentType> updateType(int id, Map<String, dynamic> body) async {
    final updated = await ref
        .read(vehiclesRepositoryProvider)
        .updateDocumentType(id, body);
    state = AsyncData([
      for (final t in state.value ?? [])
        if (t.id == id) updated else t,
    ]);
    return updated;
  }

  Future<void> remove(int id) async {
    await ref.read(vehiclesRepositoryProvider).deleteDocumentType(id);
    state = AsyncData([
      for (final t in state.value ?? [])
        if (t.id != id) t,
    ]);
  }
}

final documentTypesProvider =
    AsyncNotifierProvider<DocumentTypesNotifier, List<DocumentType>>(
      DocumentTypesNotifier.new,
    );

/// ── Vehicles ────────────────────────────────────────────────────────────────

/// Vehicles visible to the current user (driver's own / admin sees all).
class VehiclesNotifier extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() async {
    final res = await ref.read(vehiclesRepositoryProvider).list();
    return res.results;
  }

  Future<Vehicle> create(Map<String, dynamic> body) async {
    final v = await ref.read(vehiclesRepositoryProvider).create(body);
    state = AsyncData([v, ...state.value ?? []]);
    return v;
  }

  Future<Vehicle> updateVehicle(int id, Map<String, dynamic> body) async {
    final v = await ref.read(vehiclesRepositoryProvider).update(id, body);
    _replace(v);
    return v;
  }

  Future<void> remove(int id) async {
    await ref.read(vehiclesRepositoryProvider).delete(id);
    state = AsyncData([
      for (final v in state.value ?? [])
        if (v.id != id) v,
    ]);
  }

  void apply(Vehicle v) => _replace(v);

  void _replace(Vehicle v) => state = AsyncData([
    for (final old in state.value ?? [])
      if (old.id == v.id) v else old,
  ]);
}

final vehiclesProvider = AsyncNotifierProvider<VehiclesNotifier, List<Vehicle>>(
  VehiclesNotifier.new,
);

/// Single vehicle detail (family by id) — used by driver & admin detail
/// screens, invalidated after document operations.
final vehicleDetailProvider = FutureProvider.autoDispose.family<Vehicle, int>((
  ref,
  id,
) async {
  final v = await ref.watch(vehiclesRepositoryProvider).get(id);
  return v;
});
