import '../../../core/constants/api_paths.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/api_client.dart';
import 'models/contract_model.dart';

/// Contracts API (module 3).
///
/// Driver: list own / read / sign. Admin: list all / create / activate.
/// Every action endpoint requires an explicit empty JSON body `{}`.
class ContractsRepository {
  ContractsRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Contract>> list({
    Map<String, dynamic>? filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get(
      ApiPaths.contracts,
      query: {...?filters, 'page': page, 'page_size': pageSize},
    );
    return Paginated.fromJson(
      (data as Map).cast<String, dynamic>(),
      Contract.fromJson,
    );
  }

  Future<Contract> get(int id) async {
    final data = await _api.get(ApiPaths.contractById(id));
    return Contract.fromJson((data as Map).cast<String, dynamic>());
  }

  /// ADMIN — creates an unsigned, inactive contract awaiting driver signature.
  Future<Contract> create({
    required int driver,
    required String commissionPercent,
    required String content,
  }) async {
    final data = await _api.post(
      ApiPaths.contracts,
      data: {
        'driver': driver,
        'commission_percent': commissionPercent,
        'content': content,
      },
    );
    return Contract.fromJson((data as Map).cast<String, dynamic>());
  }

  /// DRIVER — signs their own contract. Response wraps `{detail, contract}`.
  Future<Contract> sign(int id) async {
    final data = await _api.post(ApiPaths.contractSign(id), data: const {});
    final contract = (data as Map)['contract'];
    return Contract.fromJson((contract as Map).cast<String, dynamic>());
  }

  /// ADMIN — activates the contract (all other contracts of that driver are
  /// deactivated server-side). Empty body required.
  Future<Contract> activate(int id) async {
    final data = await _api.post(
      ApiPaths.contractActivate(id),
      data: const {},
    );
    return Contract.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Contract> deactivate(int id) async {
    final data = await _api.post(
      ApiPaths.contractDeactivate(id),
      data: const {},
    );
    return Contract.fromJson((data as Map).cast<String, dynamic>());
  }
}
