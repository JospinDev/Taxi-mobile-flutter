import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rides/data/models/ride_model.dart';
import '../../shared/providers/repository_providers.dart';
import '../data/wallet_model.dart';

/// The driver's wallet (balance + lifetime totals).
final myWalletProvider = FutureProvider.autoDispose<Wallet>(
  (ref) => ref.read(paymentsRepositoryProvider).myWallet(),
);

/// Latest ledger lines of the current driver (or of [walletId] for admins).
final walletTransactionsProvider = FutureProvider.autoDispose.family<List<WalletTransaction>, int?>(
  (ref, walletId) async =>
      (await ref.read(paymentsRepositoryProvider).transactions(walletId: walletId)).results,
);

/// Today's figures for the driver dashboard, computed from completed rides.
final driverTodayStatsProvider = FutureProvider.autoDispose<({double earnings, int rides, double km})>((
  ref,
) async {
  final page = await ref
      .read(ridesRepositoryProvider)
      .list(statuses: RideStatus.completed.raw, pageSize: 50);
  final now = DateTime.now();
  final today = page.results.where((r) {
    final d = r.completedAt;
    return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
  });
  return (
    earnings: today.fold<double>(0, (sum, r) => sum + (r.driverEarning ?? 0)),
    rides: today.length,
    km: today.fold<double>(0, (sum, r) => sum + (r.actualDistanceKm ?? 0)),
  );
});

/// Admin: every driver wallet, most indebted first.
final adminWalletsProvider = FutureProvider.autoDispose.family<List<Wallet>, String>(
  (ref, search) async => (await ref.read(paymentsRepositoryProvider).wallets(search: search)).results,
);
