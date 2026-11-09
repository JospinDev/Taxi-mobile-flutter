import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

double _d(Object? v) => double.tryParse('${v ?? 0}') ?? 0;

class Wallet {
  const Wallet({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.balance,
    required this.totalEarned,
    required this.totalCommission,
    required this.totalPaidOut,
    required this.currency,
    this.updatedAt,
  });

  final int id;
  final int driverId;
  final String driverName;

  /// > 0: the company owes the driver. < 0: the driver owes commissions.
  final double balance;
  final double totalEarned;
  final double totalCommission;
  final double totalPaidOut;
  final String currency;
  final DateTime? updatedAt;

  bool get inDebt => balance < 0;

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
    id: (j['id'] as num?)?.toInt() ?? 0,
    driverId: (j['driver'] as num?)?.toInt() ?? 0,
    driverName: '${j['driver_name'] ?? ''}',
    balance: _d(j['balance']),
    totalEarned: _d(j['total_earned']),
    totalCommission: _d(j['total_commission']),
    totalPaidOut: _d(j['total_paid_out']),
    currency: '${j['currency'] ?? 'BIF'}',
    updatedAt: DateTime.tryParse('${j['updated_at']}')?.toLocal(),
  );
}

enum WalletTxType {
  rideEarning('ride_earning', 'Gain de course', Icons.south_west_rounded, AppColors.emeraldDeep),
  commission('commission', 'Commission (espèces)', Icons.percent_rounded, AppColors.warning),
  payout('payout', 'Versement reçu', Icons.north_east_rounded, AppColors.info),
  adjustment('adjustment', 'Ajustement', Icons.tune_rounded, AppColors.muted);

  const WalletTxType(this.raw, this.label, this.icon, this.color);

  final String raw;
  final String label;
  final IconData icon;
  final Color color;

  static WalletTxType parse(Object? v) =>
      values.firstWhere((t) => t.raw == '$v', orElse: () => WalletTxType.adjustment);
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.rideId,
    this.description = '',
    this.reference = '',
    this.createdAt,
  });

  final int id;
  final WalletTxType type;
  final double amount;
  final double balanceAfter;
  final int? rideId;
  final String description;
  final String reference;
  final DateTime? createdAt;

  bool get isCredit => amount >= 0;

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
    id: (j['id'] as num?)?.toInt() ?? 0,
    type: WalletTxType.parse(j['type']),
    amount: _d(j['amount']),
    balanceAfter: _d(j['balance_after']),
    rideId: (j['ride'] as num?)?.toInt(),
    description: '${j['description'] ?? ''}',
    reference: '${j['reference'] ?? ''}',
    createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal(),
  );
}
