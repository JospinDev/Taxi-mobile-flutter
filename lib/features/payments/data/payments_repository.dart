import '../../../core/constants/api_paths.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/api_client.dart';
import 'wallet_model.dart';

/// Wallet & ledger API (backend module 7).
class PaymentsRepository {
  PaymentsRepository(this._api);

  final ApiClient _api;

  Future<Wallet> myWallet() async =>
      Wallet.fromJson(((await _api.get(ApiPaths.myWallet)) as Map).cast<String, dynamic>());

  Future<Paginated<WalletTransaction>> transactions({int page = 1, int? walletId}) async {
    final data = await _api.get(
      ApiPaths.walletTransactions,
      query: {'page': page, 'page_size': 30, 'wallet': ?walletId},
    );
    return Paginated.fromJson((data as Map).cast<String, dynamic>(), WalletTransaction.fromJson);
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  Future<Paginated<Wallet>> wallets({String? search, int page = 1}) async {
    final data = await _api.get(
      ApiPaths.wallets,
      query: {
        'page': page,
        'page_size': 50,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return Paginated.fromJson((data as Map).cast<String, dynamic>(), Wallet.fromJson);
  }

  Future<void> payout(int walletId, double amount, {String reference = '', String description = ''}) =>
      _api.post(
        ApiPaths.walletPayout(walletId),
        data: {'amount': amount.toStringAsFixed(2), 'reference': reference, 'description': description},
      );

  Future<void> adjust(int walletId, double amount, {required String description, String reference = ''}) =>
      _api.post(
        ApiPaths.walletAdjust(walletId),
        data: {'amount': amount.toStringAsFixed(2), 'description': description, 'reference': reference},
      );
}
