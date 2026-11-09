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

  // app_config.dart
  static const String cartoApiKey = String.fromEnvironment(
    'cb1_553w_1_a255d3538a11917f2ce332c1',
    defaultValue: '',
  );

  /// WebSocket origin derived from [apiBaseUrl]:
  /// `http://host:8000/api/v1/` → `ws://host:8000/` (https → wss).
  static String get wsOrigin {
    final uri = Uri.parse(apiBaseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$port/';
  }

  /// User-Agent sent to the public OSM services (Nominatim / OSRM policy).
  static const String osmUserAgent = 'TaxiDriving/0.1 (com.jospindev.taxi)';

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

  /// Batch interval for GPS points sent during a ride (`rides/{id}/track/`).
  static const Duration rideTrackInterval = Duration(seconds: 5);

  /// Fallback polling when the WebSocket is down.
  static const Duration ridePollInterval = Duration(seconds: 6);
  static const Duration offersPollInterval = Duration(seconds: 5);
}
