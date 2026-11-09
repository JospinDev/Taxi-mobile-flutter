import 'package:my_app/features/auth/data/models/user_model.dart';

/// Compact `{id, username, first_name, last_name, role}` object embedded in
/// contracts & pricing rules (`created_by`), as returned by the backend.
class CreatorRef {
  const CreatorRef({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.role = UserRole.unknown,
  });

  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final UserRole role;

  String get displayName =>
      '${firstName ?? ''} ${lastName ?? ''}'.trim().isEmpty
          ? username
          : '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory CreatorRef.fromJson(Map<String, dynamic> json) => CreatorRef(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: '${json['username'] ?? ''}',
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    role: UserRole.parse(json['role']),
  );
}
