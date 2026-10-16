import 'driver_profile_model.dart';
import 'user_model.dart';

/// Payload returned by `POST /accounts/auth/login/`.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.driverProfile,
  });

  final String accessToken;
  final String refreshToken;
  final AppUser user;
  final DriverProfile? driverProfile;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: '${json['access'] ?? ''}',
    refreshToken: '${json['refresh'] ?? ''}',
    user: AppUser.fromJson(
      (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    driverProfile: json['driver_profile'] is Map
        ? DriverProfile.fromJson(
            (json['driver_profile'] as Map).cast<String, dynamic>(),
          )
        : null,
  );

  AuthSession copyWith({AppUser? user, DriverProfile? driverProfile}) =>
      AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user ?? this.user,
        driverProfile: driverProfile ?? this.driverProfile,
      );
}

/// Registration payload shared by client & driver (driver adds license).
class RegisterPayload {
  const RegisterPayload({
    required this.username,
    required this.email,
    required this.phone,
    required this.whatsapp,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.passwordConfirm,
    this.licenseNumber,
  });

  final String username;
  final String email;
  final String phone;
  final String whatsapp;
  final String firstName;
  final String lastName;
  final String password;
  final String passwordConfirm;
  final String? licenseNumber;

  Map<String, dynamic> toJson() => {
    'username': username.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'whatsapp': whatsapp.trim(),
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'password': password,
    'password_confirm': passwordConfirm,
    if (licenseNumber != null && licenseNumber!.trim().isNotEmpty)
      'license_number': licenseNumber!.trim(),
  };
}
