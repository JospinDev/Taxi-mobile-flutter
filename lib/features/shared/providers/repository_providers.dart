import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/network/api_client.dart';
import 'package:my_app/core/storage/token_storage.dart';
import 'package:my_app/features/driver/data/vehicles_repository.dart';
import 'package:my_app/features/admin/data/admin_accounts_repository.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/contracts/data/contracts_repository.dart';
import 'package:my_app/features/pricing/data/pricing_repository.dart';
import 'package:my_app/features/rides/data/rides_repository.dart';
import 'package:my_app/core/services/geo_services.dart';
import 'package:my_app/features/notifications/data/notifications_repository.dart';
import 'package:my_app/features/payments/data/payments_repository.dart';

/// ── Infrastructure ──────────────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) =>
      throw UnimplementedError('Overridden in main() with a real instance'),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStorageProvider)),
);

/// ── Repositories ────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final vehiclesRepositoryProvider = Provider<VehiclesRepository>(
  (ref) => VehiclesRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
  ),
);

final adminAccountsRepositoryProvider = Provider<AdminAccountsRepository>(
  (ref) => AdminAccountsRepository(ref.watch(apiClientProvider)),
);

final contractsRepositoryProvider = Provider<ContractsRepository>(
  (ref) => ContractsRepository(ref.watch(apiClientProvider)),
);

final pricingRepositoryProvider = Provider<PricingRepository>(
  (ref) => PricingRepository(ref.watch(apiClientProvider)),
);

final ridesRepositoryProvider = Provider<RidesRepository>(
  (ref) => RidesRepository(ref.watch(apiClientProvider)),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(apiClientProvider)),
);

/// Address search, reverse geocoding & road routing (OSM).
final geoServicesProvider = Provider<GeoServices>((ref) => GeoServices());
