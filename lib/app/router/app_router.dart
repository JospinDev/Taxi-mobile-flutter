import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_document_types_screen.dart';
import '../../features/admin/presentation/screens/admin_driver_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_drivers_screen.dart';
import '../../features/admin/presentation/screens/admin_home_screen.dart';
import '../../features/admin/presentation/screens/admin_shell.dart';
import '../../features/admin/presentation/screens/admin_user_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/admin/presentation/screens/admin_vehicle_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_vehicles_screen.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
import '../../features/auth/presentation/screens/register_client_screen.dart';
import '../../features/auth/presentation/screens/register_driver_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/client/presentation/screens/client_home_screen.dart';
import '../../features/client/presentation/screens/client_shell.dart';
import '../../features/client/presentation/screens/edit_profile_screen.dart';
import '../../features/client/presentation/screens/profile_screen.dart';
import '../../features/contracts/presentation/screens/admin_contract_form_screen.dart';
import '../../features/contracts/presentation/screens/admin_contracts_screen.dart';
import '../../features/contracts/presentation/screens/contract_detail_screen.dart';
import '../../features/contracts/presentation/screens/driver_contracts_screen.dart';
import '../../features/driver/presentation/screens/driver_dashboard_screen.dart';
import '../../features/driver/presentation/screens/driver_profile_screen.dart';
import '../../features/driver/presentation/screens/driver_shell.dart';
import '../../features/driver/presentation/screens/driver_vehicles_screen.dart';
import '../../features/driver/presentation/screens/upload_document_screen.dart';
import '../../features/driver/presentation/screens/vehicle_detail_screen.dart';
import '../../features/driver/presentation/screens/vehicle_form_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/payments/presentation/screens/admin_wallets_screen.dart';
import '../../features/payments/presentation/screens/wallet_screen.dart';
import '../../features/pricing/presentation/screens/client_pricing_screen.dart';
import '../../features/rides/presentation/screens/client_ride_screen.dart';
import '../../features/rides/presentation/screens/driver_ride_screen.dart';
import '../../features/rides/presentation/screens/ride_chat_screen.dart';
import '../../features/rides/presentation/screens/ride_detail_screen.dart';
import '../../features/rides/presentation/screens/ride_history_screen.dart';

/// Route paths — single source of truth, importable from any screen.
abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const registerClient = '/register-client';
  static const registerDriver = '/register-driver';

  // Client
  static const clientHome = '/client/home';
  static const clientHistory = '/client/history';
  static const clientProfile = '/client/profile';
  static const clientPricing = '/client/pricing';
  static const clientRide = '/client/ride';
  static const clientNotifications = '/client/notifications';
  static String clientRideDetail(int id) => '/client/ride-detail/$id';
  static const editProfile = '/edit-profile';

  /// Chat of the active ride — shared by the client and the driver.
  static const rideChat = '/ride/chat';

  // Driver
  static const driverHome = '/driver/dashboard';
  static const driverRides = '/driver/rides';
  static const driverWallet = '/driver/wallet';
  static const driverProfile = '/driver/profile';
  static const driverRide = '/driver/ride';
  static const driverNotifications = '/driver/notifications';
  static String driverRideDetail(int id) => '/driver/ride-detail/$id';
  static const driverPending = '/driver/pending';
  static const driverVehicles = '/driver/vehicles';
  static const driverPricing = '/driver/pricing';
  static const vehicleNew = '/driver/vehicles/new';
  static String vehicleDetail(int id) => '/driver/vehicles/$id';
  static String contractDetail(int id) => '/driver/pricing/$id';

  // Admin
  static const adminHome = '/admin/home';
  static const adminDrivers = '/admin/drivers';
  static const adminUsers = '/admin/users';
  static const adminVehicles = '/admin/vehicles';
  static const adminDocTypes = '/admin/document-types';
  static const adminContracts = '/admin/contracts';
  static const adminContractNew = '/admin/contracts/new';
  static const adminRides = '/admin/rides';
  static const adminWallets = '/admin/wallets';
  static String adminDriverDetail(int id) => '/admin/drivers/$id';
  static String adminUserDetail(int id) => '/admin/users/$id';
  static String adminVehicleDetail(int id) => '/admin/vehicles/$id';
  static String adminRideDetail(int id) => '/admin/rides/$id';
}

const _publicRoutes = {
  Routes.splash,
  Routes.onboarding,
  Routes.login,
  Routes.registerClient,
  Routes.registerDriver,
};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluates redirects whenever auth or onboarding state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(onboardingDoneProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  int id(GoRouterState s) => int.parse(s.pathParameters['id']!);

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

      final onPublicRoute = _publicRoutes.contains(location);

      // 2) Not authenticated → onboarding (first launch), then auth routes.
      if (!auth.isAuthenticated) {
        final onboarded = ref.read(onboardingDoneProvider);
        if (!onboarded) return location == Routes.onboarding ? null : Routes.onboarding;
        if (location == Routes.onboarding || location == Routes.splash) return Routes.login;
        return onPublicRoute ? null : Routes.login;
      }

      // 3) Authenticated → never stay on auth/splash/onboarding screens.
      if (onPublicRoute) return _homeFor(auth);

      // 4) Role gating: a user only reaches their own area.
      final allowed = switch (auth.role) {
        UserRole.client => location.startsWith('/client') || location == Routes.editProfile,
        UserRole.driver => location.startsWith('/driver') || location == Routes.editProfile,
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
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.registerClient, builder: (_, _) => const RegisterClientScreen()),
      GoRoute(path: Routes.registerDriver, builder: (_, _) => const RegisterDriverScreen()),
      GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: Routes.rideChat, builder: (_, _) => const RideChatScreen()),

      // ─────────────────────────── Client ───────────────────────────
      GoRoute(path: Routes.clientRide, builder: (_, _) => const ClientRideScreen()),
      GoRoute(path: Routes.clientNotifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: '/client/ride-detail/:id',
        builder: (_, s) => RideDetailScreen(rideId: id(s), viewer: RideViewer.client),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ClientShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.clientHome, builder: (_, _) => const ClientHomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.clientHistory,
                builder: (_, _) => const RideHistoryScreen(title: 'Mes courses', detailRoute: Routes.clientRideDetail),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.clientPricing, builder: (_, _) => const ClientPricingScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.clientProfile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),

      // ─────────────────────────── Driver ───────────────────────────
      GoRoute(path: Routes.driverPending, builder: (_, _) => const PendingApprovalScreen()),
      GoRoute(path: Routes.driverRide, builder: (_, _) => const DriverRideScreen()),
      GoRoute(path: Routes.driverNotifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: '/driver/ride-detail/:id',
        builder: (_, s) => RideDetailScreen(rideId: id(s), viewer: RideViewer.driver),
      ),
      GoRoute(
        path: Routes.driverVehicles,
        builder: (_, _) => const DriverVehiclesScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const VehicleFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, s) => VehicleDetailScreen(vehicleId: id(s)),
            routes: [
              GoRoute(
                path: 'documents/:docType/upload',
                builder: (_, s) => UploadDocumentScreen(vehicleId: id(s), docTypeCode: s.pathParameters['docType']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.driverPricing,
        builder: (_, _) => const DriverContractsScreen(),
        routes: [
          GoRoute(path: ':id', builder: (_, s) => ContractDetailScreen(contractId: id(s))),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => DriverShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.driverHome, builder: (_, _) => const DriverDashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.driverRides,
                builder: (_, _) => const RideHistoryScreen(
                  title: 'Mes courses',
                  detailRoute: Routes.driverRideDetail,
                  showEarning: true,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.driverWallet, builder: (_, _) => const WalletScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.driverProfile, builder: (_, _) => const DriverProfileScreen())],
          ),
        ],
      ),

      // ─────────────────────────── Admin ───────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.adminHome, builder: (_, _) => const AdminHomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminDrivers,
                builder: (_, _) => const AdminDriversScreen(),
                routes: [GoRoute(path: ':id', builder: (_, s) => AdminDriverDetailScreen(driverId: id(s)))],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminUsers,
                builder: (_, _) => const AdminUsersScreen(),
                routes: [GoRoute(path: ':id', builder: (_, s) => AdminUserDetailScreen(userId: id(s)))],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminVehicles,
                builder: (_, _) => const AdminVehiclesScreen(),
                routes: [GoRoute(path: ':id', builder: (_, s) => AdminVehicleDetailScreen(vehicleId: id(s)))],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.adminDocTypes, builder: (_, _) => const AdminDocumentTypesScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminContracts,
                builder: (_, _) => const AdminContractsScreen(),
                routes: [GoRoute(path: 'new', builder: (_, _) => const AdminContractFormScreen())],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminRides,
                builder: (_, _) => RideHistoryScreen(
                  title: 'Courses',
                  detailRoute: Routes.adminRideDetail,
                  showParties: true,
                  leading: IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
                routes: [
                  GoRoute(path: ':id', builder: (_, s) => RideDetailScreen(rideId: id(s), viewer: RideViewer.admin)),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.adminWallets, builder: (_, _) => const AdminWalletsScreen())],
          ),
        ],
      ),
    ],
  );
});

String _homeFor(AuthState auth) => switch (auth.role) {
  UserRole.client => Routes.clientHome,
  UserRole.driver => auth.isDriverPendingApproval ? Routes.driverPending : Routes.driverHome,
  UserRole.admin => Routes.adminHome,
  UserRole.unknown => Routes.login,
};
