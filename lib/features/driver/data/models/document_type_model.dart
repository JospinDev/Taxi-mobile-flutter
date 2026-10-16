/// Document type definition — drives the dynamic upload grid.
///
/// The app never hardcodes which documents are needed: it iterates this list
/// and renders a slot per type, adding an expiry date field when
/// [requiresExpiry] is true and marking the slot mandatory when [isRequired].
class DocumentType {
  const DocumentType({
    required this.id,
    required this.code,
    required this.label,
    this.description,
    this.isRequired = false,
    this.requiresExpiry = false,
    this.isActive = true,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String code;
  final String label;
  final String? description;
  final bool isRequired;
  final bool requiresExpiry;
  final bool isActive;
  final int order;
  final String? createdAt;
  final String? updatedAt;

  factory DocumentType.fromJson(Map<String, dynamic> json) => DocumentType(
    id: (json['id'] as num?)?.toInt() ?? 0,
    code: '${json['code'] ?? ''}',
    label: '${json['label'] ?? ''}',
    description: json['description'] as String?,
    isRequired: json['is_required'] as bool? ?? false,
    requiresExpiry: json['requires_expiry'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
    order: (json['order'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'description': description ?? '',
    'is_required': isRequired,
    'requires_expiry': requiresExpiry,
    'is_active': isActive,
    'order': order,
  };

  DocumentType copyWith({
    String? label,
    String? description,
    bool? isRequired,
    bool? requiresExpiry,
    bool? isActive,
    int? order,
  }) => DocumentType(
    id: id,
    code: code,
    label: label ?? this.label,
    description: description ?? this.description,
    isRequired: isRequired ?? this.isRequired,
    requiresExpiry: requiresExpiry ?? this.requiresExpiry,
    isActive: isActive ?? this.isActive,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
