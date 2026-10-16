import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../shared/providers/repository_providers.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_session.dart';
import '../data/models/driver_profile_model.dart';
import '../data/models/user_model.dart';

/// The authentication state driving the whole router/UI.
enum AuthStatus { initial, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.driverProfile,
    this.isBootstrapping = true,
  });

  final AuthStatus status;
  final AppUser? user;
  final DriverProfile? driverProfile;

  /// True while we restore the session from storage (splash screen shows).
  final bool isBootstrapping;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  UserRole get role => user?.role ?? UserRole.unknown;

  /// A registered driver that hasn't been approved by an admin yet.
  bool get isDriverPendingApproval =>
      role == UserRole.driver && (driverProfile?.isApproved ?? false) == false;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    DriverProfile? driverProfile,
    bool clearDriverProfile = false,
    bool? isBootstrapping,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    driverProfile: clearDriverProfile
        ? null
        : (driverProfile ?? this.driverProfile),
    isBootstrapping: isBootstrapping ?? this.isBootstrapping,
  );
}

/// Owns login/register/logout and the session lifecycle.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  AuthState get _s => state;

  /// Restores the session at startup (called once from the splash screen).
  Future<void> bootstrap() async {
    final storage = ref.read(tokenStorageProvider);
    if (!storage.hasSession) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        isBootstrapping: false,
      );
      return;
    }
    try {
      // The Dio interceptor transparently refreshes the access token on 401.
      final user = await _repo.me();
      DriverProfile? profile;
      if (user.role == UserRole.driver) {
        profile = await _tryDriverProfile();
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        driverProfile: profile,
        isBootstrapping: false,
      );
    } catch (_) {
      await storage.clear();
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        isBootstrapping: false,
      );
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final session = await _repo.login(username: username, password: password);
    await _persistSession(session);
  }

  /// Registers a client. The API returns the created user (201, no tokens),
  /// so we then auto-login to obtain the session.
  Future<void> registerClient(RegisterPayload payload) async {
    await _repo.registerClient(payload);
    await _autoLoginAfterRegister(payload);
  }

  /// Registers a driver → account created as `pending`, needs admin approval.
  Future<void> registerDriver(RegisterPayload payload) async {
    await _repo.registerDriver(payload);
    await _autoLoginAfterRegister(payload);
  }

  Future<void> _autoLoginAfterRegister(RegisterPayload payload) async {
    final session = await _repo.login(
      username: payload.username,
      password: payload.password,
    );
    await _persistSession(session);
  }

  Future<void> _persistSession(AuthSession session) async {
    final storage = ref.read(tokenStorageProvider);
    await storage.save(
      access: session.accessToken,
      refresh: session.refreshToken,
      role: session.user.role.raw,
    );
    var profile = session.driverProfile;
    if (session.user.role == UserRole.driver && profile == null) {
      profile = await _tryDriverProfile();
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: session.user,
      driverProfile: profile,
      isBootstrapping: false,
    );
  }

  /// Refreshes `/accounts/me/` + driver profile (pull-to-refresh, after edit).
  Future<void> refreshMe() async {
    final user = await _repo.me();
    DriverProfile? profile;
    if (user.role == UserRole.driver) profile = await _tryDriverProfile();
    state = _s.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      driverProfile: profile,
      clearDriverProfile: profile == null,
    );
  }

  Future<AppUser> updateProfile(Map<String, dynamic> fields) async {
    final user = await _repo.updateMe(fields);
    state = _s.copyWith(user: user);
    return user;
  }

  /// Polls `/accounts/drivers/me/`; tolerates 403/404 (still unapproved).
  Future<DriverProfile?> _tryDriverProfile() async {
    try {
      return await _repo.myDriverProfile();
    } on ApiException catch (e) {
      if (e.isForbidden || e.isNotFound || e.isValidation) return null;
      rethrow;
    }
  }

  /// Called by the pending-approval screen (polling) & dashboard refresh.
  Future<void> refreshDriverProfile() async {
    final profile = await _tryDriverProfile();
    if (profile != null) state = _s.copyWith(driverProfile: profile);
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isBootstrapping: false,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Convenience selectors.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);
final currentDriverProfileProvider = Provider<DriverProfile?>(
  (ref) => ref.watch(authControllerProvider).driverProfile,
);

