import '../../../../core/models/creator_ref.dart';

/// Pricing rule (grille tarifaire) — module 4.
///
/// All monetary fields arrive as strings (`"500.00"`) to avoid float rounding.
/// The backend does ALL price calculations; the app only displays them.
class PricingRule {
  const PricingRule({
    required this.id,
    required this.name,
    required this.baseFare,
    required this.pricePerKm,
    required this.pricePerMinTraffic,
    this.maxSpeedKmhForTraffic = 10,
    this.minTrafficDurationSeconds = 30,
    this.roundingUnit = 50,
    required this.minFare,
    this.isActive = false,
    this.effectiveFrom,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;

  /// Raw decimal strings — parse with [amount] helper for display only.
  final String baseFare;
  final String pricePerKm;
  final String pricePerMinTraffic;
  final int maxSpeedKmhForTraffic;
  final int minTrafficDurationSeconds;
  final int roundingUnit;
  final String minFare;

  final bool isActive;
  final String? effectiveFrom;
  final CreatorRef? createdBy;
  final String? createdAt;
  final String? updatedAt;

  /// Display helper — parses a decimal string to a number (no math done here).
  static num amount(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    return num.tryParse(raw) ?? 0;
  }

  num get base => amount(baseFare);
  num get perKm => amount(pricePerKm);
  num get perMin => amount(pricePerMinTraffic);
  num get minimum => amount(minFare);

  factory PricingRule.fromJson(Map<String, dynamic> json) => PricingRule(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: '${json['name'] ?? ''}',
    baseFare: '${json['base_fare'] ?? '0'}',
    pricePerKm: '${json['price_per_km'] ?? '0'}',
    pricePerMinTraffic: '${json['price_per_min_traffic'] ?? '0'}',
    maxSpeedKmhForTraffic:
        (json['max_speed_kmh_for_traffic'] as num?)?.toInt() ?? 10,
    minTrafficDurationSeconds:
        (json['min_traffic_duration_seconds'] as num?)?.toInt() ?? 30,
    roundingUnit: (json['rounding_unit'] as num?)?.toInt() ?? 50,
    minFare: '${json['min_fare'] ?? '0'}',
    isActive: json['is_active'] as bool? ?? false,
    effectiveFrom: json['effective_from'] as String?,
    createdBy: json['created_by'] is Map
        ? CreatorRef.fromJson(
            (json['created_by'] as Map).cast<String, dynamic>(),
          )
        : null,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );
}
