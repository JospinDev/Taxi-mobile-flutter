/// Central application configuration.
///
/// The API base URL can be overridden at build time without touching code:
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://192.168.30.194:8000/api/v1/
/// ```
/// Note: `127.0.0.1` only works when the backend runs on the same machine
/// as the app (iOS Simulator / desktop). On a real Android device use your
/// LAN IP (currently 192.168.30.194), on the Android emulator use `10.0.2.2`.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.30.194:8000/api/v1/',
  );

  /// App-wide debug flag (enables verbose network logs in dev builds).
  static const bool enableApiLogs = bool.fromEnvironment(
    'API_LOGS',
    defaultValue: true,
  );

  static const String appName = 'Taxi Driving';
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);

  /// Driver GPS location push interval (spec: every 5–10 seconds).
  static const Duration locationPushInterval = Duration(seconds: 8);

  /// Polling interval used while waiting for admin approval.
  static const Duration approvalPollInterval = Duration(seconds: 5);

  static const int maxUploadSize = 5 * 1024 * 1024; // 5 MB
}
