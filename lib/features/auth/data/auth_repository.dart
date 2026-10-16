import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import 'models/auth_session.dart';
import 'models/driver_profile_model.dart';
import 'models/user_model.dart';

/// Accounts API — auth flows (register client/driver, login, refresh, profile).
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> registerClient(RegisterPayload payload) async {
    final data = await _api.post(
      ApiPaths.registerClient,
      data: payload.toJson(),
    );
    return AuthSession.fromJson({'access': '', 'refresh': '', 'user': data});
  }

  Future<AuthSession> registerDriver(RegisterPayload payload) async {
    final data = await _api.post(
      ApiPaths.registerDriver,
      data: payload.toJson(),
    );
    return AuthSession.fromJson({'access': '', 'refresh': '', 'user': data});
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.post(
      ApiPaths.login,
      data: {'username': username.trim(), 'password': password},
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppUser> me() async {
    final data = await _api.get(ApiPaths.me);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppUser> updateMe(Map<String, dynamic> fields) async {
    final data = await _api.patch(ApiPaths.me, data: fields);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── Driver self-service (module 1.11 → 1.13) ───────────────────────────────

  Future<DriverProfile> myDriverProfile() async {
    final data = await _api.get(ApiPaths.myDriverProfile);
    return DriverProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> updateLocation({required double lat, required double lng}) =>
      _api.patch(ApiPaths.myDriverLocation, data: {'lat': lat, 'lng': lng});

  Future<String> updateStatus(String status) async {
    final data = await _api.patch(
      ApiPaths.myDriverStatus,
      data: {'status': status},
    );
    return '${(data as Map)['status']}';
  }
}
