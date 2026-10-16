import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/features/admin/presentation/screens/admin_driver_detail_screen.dart';
import 'package:my_app/features/auth/data/models/user_model.dart';

import '../../features/admin/presentation/screens/admin_drivers_screen.dart';
import '../../features/admin/presentation/screens/admin_document_types_screen.dart';
import '../../features/admin/presentation/screens/admin_shell.dart';
import '../../features/admin/presentation/screens/admin_user_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/admin/presentation/screens/admin_vehicle_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_vehicles_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
import '../../features/auth/presentation/screens/register_client_screen.dart';
import '../../features/auth/presentation/screens/register_driver_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/client/presentation/screens/client_history_screen.dart';
import '../../features/client/presentation/screens/client_home_screen.dart';
import '../../features/client/presentation/screens/client_shell.dart';
import '../../features/client/presentation/screens/edit_profile_screen.dart';
import '../../features/client/presentation/screens/profile_screen.dart';
import '../../features/driver/presentation/screens/driver_dashboard_screen.dart';
import '../../features/driver/presentation/screens/driver_shell.dart';
import '../../features/driver/presentation/screens/driver_profile_screen.dart';
import '../../features/driver/presentation/screens/driver_vehicles_screen.dart';
import '../../features/driver/presentation/screens/upload_document_screen.dart';
import '../../features/driver/presentation/screens/vehicle_detail_screen.dart';
import '../../features/driver/presentation/screens/vehicle_form_screen.dart';

/// Route paths — single source of truth, importable from any screen.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const registerClient = '/register-client';
  static const registerDriver = '/register-driver';

  // Client
  static const clientHome = '/client/home';
  static const clientHistory = '/client/history';
  static const clientProfile = '/client/profile';
  static const editProfile = '/edit-profile';

  // Driver
  static const driverHome = '/driver/dashboard';
  static const driverVehicles = '/driver/vehicles';
  static const driverProfile = '/driver/profile';
  static const driverPending = '/driver/pending';
  static const vehicleNew = '/driver/vehicles/new';
  static String vehicleDetail(int id) => '/driver/vehicles/$id';

  // Admin
  static const adminDrivers = '/admin/drivers';
  static const adminUsers = '/admin/users';
  static const adminVehicles = '/admin/vehicles';
  static const adminDocTypes = '/admin/document-types';
  static String adminDriverDetail(int id) => '/admin/drivers/$id';
  static String adminUserDetail(int id) => '/admin/users/$id';
  static String adminVehicleDetail(int id) => '/admin/vehicles/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluates redirects whenever auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // 1) Session still restoring → splash only.
      if (auth.status == AuthStatus.initial || auth.isBootstrapping) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final onPublicRoute =
          location == Routes.splash ||
          location == Routes.login ||
          location == Routes.registerClient ||
          location == Routes.registerDriver;

      // 2) Not authenticated → only auth routes allowed.
      if (!auth.isAuthenticated) {
        if (onPublicRoute && location != Routes.splash) return null;
        return location == Routes.login ? null : Routes.login;
      }

      // 3) Authenticated → never stay on auth/splash screens.
      if (onPublicRoute) return _homeFor(auth);

      // 4) Role gating: a user only reaches their own area.
      final allowed = switch (auth.role) {
        UserRole.client =>
          location.startsWith('/client') || location == Routes.editProfile,
        UserRole.driver =>
          location.startsWith('/driver') || location == Routes.editProfile,
        UserRole.admin => location.startsWith('/admin'),
        UserRole.unknown => false,
      };
      if (!allowed) return _homeFor(auth);

      // 5) Driver approval gate: pending drivers only see the waiting screen.
      if (auth.role == UserRole.driver && auth.isDriverPendingApproval) {
        return location == Routes.driverPending ? null : Routes.driverPending;
      }
      if (auth.role == UserRole.driver && location == Routes.driverPending) {
        return Routes.driverHome;
      }

      return null;
    },
    routes: [
      // ─────────────────────────── Public ───────────────────────────
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.registerClient,
        builder: (context, state) => const RegisterClientScreen(),
      ),
      GoRoute(
        path: Routes.registerDriver,
        builder: (context, state) => const RegisterDriverScreen(),
      ),

      // ─────────────────────────── Client ───────────────────────────
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.driverPending,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ClientShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.clientHome,
                builder: (context, state) => const ClientHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.clientHistory,
                builder: (context, state) => const ClientHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.clientProfile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─────────────────────────── Driver ───────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            DriverShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.driverHome,
                builder: (context, state) => const DriverDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.driverVehicles,
                builder: (context, state) => const DriverVehiclesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const VehicleFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => VehicleDetailScreen(
                      vehicleId: int.parse(state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'documents/:docType/upload',
                        builder: (context, state) => UploadDocumentScreen(
                          vehicleId: int.parse(state.pathParameters['id']!),
                          docTypeCode: state.pathParameters['docType']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.driverProfile,
                builder: (context, state) => const DriverProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─────────────────────────── Admin ───────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminDrivers,
                builder: (context, state) => const AdminDriversScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AdminDriverDetailScreen(
                      driverId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminUsers,
                builder: (context, state) => const AdminUsersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AdminUserDetailScreen(
                      userId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminVehicles,
                builder: (context, state) => const AdminVehiclesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AdminVehicleDetailScreen(
                      vehicleId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminDocTypes,
                builder: (context, state) => const AdminDocumentTypesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

String _homeFor(AuthState auth) => switch (auth.role) {
  UserRole.client => Routes.clientHome,
  UserRole.driver =>
    auth.isDriverPendingApproval ? Routes.driverPending : Routes.driverHome,
  UserRole.admin => Routes.adminDrivers,
  UserRole.unknown => Routes.login,
};
