/// A document attached to a vehicle (carte rose, assurance, etc.).
class VehicleDocument {
  const VehicleDocument({
    required this.file,
    this.originalName,
    this.sizeBytes,
    this.uploadedAt,
    this.expiresAt,
    this.isValidated = false,
    this.validatedBy,
    this.validatedAt,
    this.note,
  });

  final String file;
  final String? originalName;
  final int? sizeBytes;
  final String? uploadedAt;
  final String? expiresAt;
  final bool isValidated;
  final int? validatedBy;
  final String? validatedAt;
  final String? note;

  bool get isPending => !isValidated;

  factory VehicleDocument.fromJson(Map<String, dynamic> json) =>
      VehicleDocument(
        file: '${json['file'] ?? ''}',
        originalName: json['original_name'] as String?,
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        uploadedAt: json['uploaded_at'] as String?,
        expiresAt: json['expires_at'] as String?,
        isValidated: json['is_validated'] as bool? ?? false,
        validatedBy: (json['validated_by'] as num?)?.toInt(),
        validatedAt: json['validated_at'] as String?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'file': file,
    'original_name': originalName,
    'size_bytes': sizeBytes,
    'uploaded_at': uploadedAt,
    'expires_at': expiresAt,
    'is_validated': isValidated,
    'validated_by': validatedBy,
    'validated_at': validatedAt,
    'note': note,
  };
}

/// Vehicle entity (vehicles module).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.driverId,
    this.driverName,
    required this.plateNumber,
    required this.brand,
    required this.model,
    required this.year,
    this.color,
    required this.seats,
    this.documents = const {},
    this.isActive = false,
    this.requiredDocsValidated = false,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int driverId;
  final String? driverName;
  final String plateNumber;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final int seats;

  /// Keyed by document type code, e.g. `carte_rose`.
  final Map<String, VehicleDocument> documents;
  final bool isActive;
  final bool requiredDocsValidated;
  final String? createdAt;
  final String? updatedAt;

  String get name => '$brand $model';

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: (json['id'] as num?)?.toInt() ?? 0,
    driverId: (json['driver'] as num?)?.toInt() ?? 0,
    driverName: json['driver_name'] as String?,
    plateNumber: '${json['plate_number'] ?? ''}',
    brand: '${json['brand'] ?? ''}',
    model: '${json['model'] ?? ''}',
    year: (json['year'] as num?)?.toInt() ?? 0,
    color: json['color'] as String?,
    seats: (json['seats'] as num?)?.toInt() ?? 0,
    documents: (json['documents'] as Map? ?? const {}).map(
      (k, v) => MapEntry(
        '$k',
        VehicleDocument.fromJson((v as Map).cast<String, dynamic>()),
      ),
    ),
    isActive: json['is_active'] as bool? ?? false,
    requiredDocsValidated: json['required_docs_validated'] as bool? ?? false,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );

  Vehicle copyWith({
    String? plateNumber,
    String? brand,
    String? model,
    int? year,
    String? color,
    int? seats,
    Map<String, VehicleDocument>? documents,
    bool? isActive,
    bool? requiredDocsValidated,
  }) => Vehicle(
    id: id,
    driverId: driverId,
    driverName: driverName,
    plateNumber: plateNumber ?? this.plateNumber,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    year: year ?? this.year,
    color: color ?? this.color,
    seats: seats ?? this.seats,
    documents: documents ?? this.documents,
    isActive: isActive ?? this.isActive,
    requiredDocsValidated: requiredDocsValidated ?? this.requiredDocsValidated,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
