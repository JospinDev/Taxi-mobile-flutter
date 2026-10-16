import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/network/api_client.dart';
import 'package:my_app/core/storage/token_storage.dart';
import 'package:my_app/features/driver/data/vehicles_repository.dart';
import 'package:my_app/features/admin/data/admin_accounts_repository.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';

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
