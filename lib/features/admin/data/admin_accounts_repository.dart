import '../../../core/constants/api_paths.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/models/driver_profile_model.dart';
import '../../auth/data/models/user_model.dart';

/// Accounts API — admin-side resources (drivers, users).
class AdminAccountsRepository {
  AdminAccountsRepository(this._api);

  final ApiClient _api;

  // ── Drivers (1.7 → 1.10) ───────────────────────────────────────────────────

  Future<Paginated<DriverProfile>> listDrivers({
    Map<String, dynamic>? filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get(
      ApiPaths.drivers,
      query: {...?filters, 'page': page, 'page_size': pageSize},
    );
    return Paginated.fromJson(
      (data as Map).cast<String, dynamic>(),
      DriverProfile.fromJson,
    );
  }

  Future<DriverProfile> getDriver(int id) async {
    final data = await _api.get(ApiPaths.driverById(id));
    return DriverProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Empty-body POST — any body makes the backend respond 400.
  Future<DriverProfile> approveDriver(int id) async {
    final data = await _api.post(ApiPaths.driverApprove(id), data: const {});
    return DriverProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<DriverProfile> suspendDriver(int id) async {
    final data = await _api.post(ApiPaths.driverSuspend(id), data: const {});
    return DriverProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── Users (1.14 → 1.18) ────────────────────────────────────────────────────

  Future<Paginated<AppUser>> listUsers({
    Map<String, dynamic>? filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get(
      ApiPaths.users,
      query: {...?filters, 'page': page, 'page_size': pageSize},
    );
    return Paginated.fromJson(
      (data as Map).cast<String, dynamic>(),
      AppUser.fromJson,
    );
  }

  Future<AppUser> getUser(int id) async {
    final data = await _api.get(ApiPaths.userById(id));
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppUser> updateUser(int id, Map<String, dynamic> fields) async {
    final data = await _api.patch(ApiPaths.userById(id), data: fields);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> deleteUser(int id) => _api.delete(ApiPaths.userById(id));

  Future<AppUser> toggleActive(int id) async {
    final data = await _api.post(ApiPaths.userToggleActive(id), data: const {});
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }
}
