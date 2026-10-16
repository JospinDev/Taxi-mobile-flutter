import 'user_model.dart';

/// Driver lifecycle status (manual toggle only accepts available/offline).
enum DriverStatus {
  pending('pending'),
  available('available'),
  busy('busy'),
  offline('offline'),
  unknown('unknown');

  const DriverStatus(this.raw);

  final String raw;

  static DriverStatus parse(Object? value) => switch ('$value') {
    'pending' => DriverStatus.pending,
    'available' => DriverStatus.available,
    'busy' => DriverStatus.busy,
    'offline' => DriverStatus.offline,
    _ => DriverStatus.unknown,
  };

  String get label => switch (this) {
    DriverStatus.pending => 'En attente',
    DriverStatus.available => 'Disponible',
    DriverStatus.busy => 'En course',
    DriverStatus.offline => 'Hors ligne',
    DriverStatus.unknown => 'Inconnu',
  };
}

/// `driver_profile` object embedded in login / drivers endpoints.
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.user,
    required this.status,
    this.licenseNumber,
    this.lastLocation,
    this.lastLocationAt,
    this.rating = 0,
    this.totalRides = 0,
    this.isApproved = false,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final AppUser user;
  final DriverStatus status;
  final String? licenseNumber;

  /// Raw PostGIS string, e.g. `SRID=4326;POINT (29.3644 -3.3821)`.
  final String? lastLocation;
  final String? lastLocationAt;
  final double rating;
  final int totalRides;
  final bool isApproved;
  final String? approvedAt;
  final String? createdAt;
  final String? updatedAt;

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
    id: (json['id'] as num?)?.toInt() ?? 0,
    user: AppUser.fromJson(
      (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    status: DriverStatus.parse(json['status']),
    licenseNumber: json['license_number'] as String?,
    lastLocation: json['last_location'] as String?,
    lastLocationAt: json['last_location_at'] as String?,
    rating: double.tryParse('${json['rating'] ?? 0}') ?? 0,
    totalRides: (json['total_rides'] as num?)?.toInt() ?? 0,
    isApproved: json['is_approved'] as bool? ?? false,
    approvedAt: json['approved_at'] as String?,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user.toJson(),
    'status': status.raw,
    'license_number': licenseNumber,
    'last_location': lastLocation,
    'last_location_at': lastLocationAt,
    'rating': rating.toStringAsFixed(2),
    'total_rides': totalRides,
    'is_approved': isApproved,
    'approved_at': approvedAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  /// Parses `SRID=4326;POINT (lng lat)` → `{lng, lat}`, or null.
  ({double lng, double lat})? get coordinates {
    final raw = lastLocation;
    if (raw == null) return null;
    final match = RegExp(r'POINT\s*\(([^)]+)\)').firstMatch(raw);
    if (match == null) return null;
    final parts = match.group(1)!.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lng == null || lat == null) return null;
    return (lng: lng, lat: lat);
  }

  DriverProfile copyWith({
    DriverStatus? status,
    bool? isApproved,
    double? rating,
    int? totalRides,
    String? lastLocation,
    String? lastLocationAt,
    String? approvedAt,
  }) => DriverProfile(
    id: id,
    user: user,
    status: status ?? this.status,
    licenseNumber: licenseNumber,
    lastLocation: lastLocation ?? this.lastLocation,
    lastLocationAt: lastLocationAt ?? this.lastLocationAt,
    rating: rating ?? this.rating,
    totalRides: totalRides ?? this.totalRides,
    isApproved: isApproved ?? this.isApproved,
    approvedAt: approvedAt ?? this.approvedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
