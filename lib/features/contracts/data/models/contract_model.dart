import '../../../../core/models/creator_ref.dart';

/// Signature workflow status of a contract.
enum ContractStatus {
  awaitingSignature('awaiting_signature'),
  active('active'),
  archived('archived');

  const ContractStatus(this.raw);
  final String raw;
}

/// Contract between a driver and the company (module 3).
///
/// Business rules encoded here:
/// * a contract can't be modified once signed (sealed with a hash),
/// * only one contract can be active at a time per driver,
/// * amounts/commission come as strings — parse only for display.
class Contract {
  const Contract({
    required this.id,
    required this.driverId,
    this.driverName,
    required this.commissionPercent,
    required this.content,
    this.signedAt,
    this.signatureIp,
    this.signatureHash,
    this.isActive = false,
    this.isSigned = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int driverId;
  final String? driverName;

  /// e.g. `"20.00"` — keep as string, parse only for display.
  final String commissionPercent;
  final String content;

  final String? signedAt;
  final String? signatureIp;
  final String? signatureHash;
  final bool isActive;
  final bool isSigned;
  final CreatorRef? createdBy;
  final String? createdAt;
  final String? updatedAt;

  /// Display-only percentage, e.g. `20`.
  double get commission => double.tryParse(commissionPercent) ?? 0;

  ContractStatus get status => switch ((isActive, isSigned)) {
    (true, _) => ContractStatus.active,
    (false, true) => ContractStatus.archived,
    (false, false) => ContractStatus.awaitingSignature,
  };

  factory Contract.fromJson(Map<String, dynamic> json) => Contract(
    id: (json['id'] as num?)?.toInt() ?? 0,
    driverId: (json['driver'] as num?)?.toInt() ?? 0,
    driverName: json['driver_name'] as String?,
    commissionPercent: '${json['commission_percent'] ?? '0'}',
    content: '${json['content'] ?? ''}',
    signedAt: json['signed_at'] as String?,
    signatureIp: json['signature_ip'] as String?,
    signatureHash: json['signature_hash'] as String?,
    isActive: json['is_active'] as bool? ?? false,
    isSigned: json['is_signed'] as bool? ?? false,
    createdBy: json['created_by'] is Map
        ? CreatorRef.fromJson(
            (json['created_by'] as Map).cast<String, dynamic>(),
          )
        : null,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );
}
