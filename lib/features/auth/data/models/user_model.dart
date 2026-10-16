/// `role` values returned by the backend.
enum UserRole {
  client('client'),
  driver('driver'),
  admin('admin'),
  unknown('unknown');

  const UserRole(this.raw);

  final String raw;

  static UserRole parse(Object? value) => switch ('$value') {
    'client' => UserRole.client,
    'driver' => UserRole.driver,
    'admin' => UserRole.admin,
    _ => UserRole.unknown,
  };

  String get label => switch (this) {
    UserRole.client => 'Client',
    UserRole.driver => 'Chauffeur',
    UserRole.admin => 'Administrateur',
    UserRole.unknown => 'Utilisateur',
  };
}

/// Core user entity (accounts module).
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.whatsapp,
    this.isVerified = false,
    this.isActive = true,
    this.fcmToken,
    this.createdAt,
  });

  final int id;
  final String username;
  final UserRole role;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? whatsapp;
  final bool isVerified;
  final bool isActive;
  final String? fcmToken;
  final String? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: '${json['username'] ?? ''}',
    role: UserRole.parse(json['role']),
    email: json['email'] as String?,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    phone: json['phone'] as String?,
    whatsapp: json['whatsapp'] as String?,
    isVerified: json['is_verified'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
    fcmToken: json['fcm_token'] as String?,
    createdAt: json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'role': role.raw,
    'phone': phone,
    'whatsapp': whatsapp,
    'is_verified': isVerified,
    'is_active': isActive,
    'fcm_token': fcmToken,
    'created_at': createdAt,
  };

  AppUser copyWith({
    String? email,
    String? firstName,
    String? lastName,
    String? whatsapp,
    String? fcmToken,
    bool? isVerified,
    bool? isActive,
  }) => AppUser(
    id: id,
    username: username,
    role: role,
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone,
    whatsapp: whatsapp ?? this.whatsapp,
    isVerified: isVerified ?? this.isVerified,
    isActive: isActive ?? this.isActive,
    fcmToken: fcmToken ?? this.fcmToken,
    createdAt: createdAt,
  );
}
