import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT session (access + refresh) and the last known user role.
///
/// Uses [SharedPreferences] so the session survives app restarts with no
/// platform channel setup. Tokens are treated as opaque strings; the app never
/// decodes them.
class TokenStorage {
  TokenStorage(this._prefs);

  static const _kAccess = 'auth.access';
  static const _kRefresh = 'auth.refresh';
  static const _kRole = 'auth.role';

  final SharedPreferences _prefs;

  static Future<TokenStorage> init() async =>
      TokenStorage(await SharedPreferences.getInstance());

  String? get access => _prefs.getString(_kAccess);
  String? get refresh => _prefs.getString(_kRefresh);
  String? get role => _prefs.getString(_kRole);

  bool get hasSession => refresh?.isNotEmpty ?? false;

  Future<void> save({
    required String access,
    required String refresh,
    String? role,
  }) async {
    await _prefs.setString(_kAccess, access);
    await _prefs.setString(_kRefresh, refresh);
    if (role != null) await _prefs.setString(_kRole, role);
  }

  Future<void> updateAccess(String access) =>
      _prefs.setString(_kAccess, access);

  Future<void> setRole(String role) => _prefs.setString(_kRole, role);

  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kRole);
  }
}
