/// Single source of truth for every backend endpoint (see API docs Modules 1 & 2).
///
/// Paths are relative to `AppConfig.apiBaseUrl` (`http://192.168.30.194:8000/api/v1/`).
class ApiPaths {
  const ApiPaths._();

  // ─────────────────────────── MODULE 1 — ACCOUNTS ───────────────────────────
  static const registerClient = 'accounts/auth/register-client/';
  static const registerDriver = 'accounts/auth/register-driver/';
  static const login = 'accounts/auth/login/';
  static const tokenRefresh = 'accounts/token/refresh/';

  static const me = 'accounts/me/';

  static String driverById(int id) => 'accounts/drivers/$id/';
  static const drivers = 'accounts/drivers/';
  static String driverApprove(int id) => 'accounts/drivers/$id/approve/';
  static String driverSuspend(int id) => 'accounts/drivers/$id/suspend/';
  static const myDriverProfile = 'accounts/drivers/me/';
  static const myDriverLocation = 'accounts/drivers/me/location/';
  static const myDriverStatus = 'accounts/drivers/me/status/';

  static const users = 'accounts/users/';
  static String userById(int id) => 'accounts/users/$id/';
  static String userToggleActive(int id) => 'accounts/users/$id/toggle-active/';

  // ────────────────────────── MODULE 2 — VEHICLES ────────────────────────────
  static const vehicles = 'vehicles/';
  static String vehicleById(int id) => 'vehicles/$id/';
  static String vehicleUploadDocument(int id) =>
      'vehicles/$id/upload-document/';
  static String vehicleDocument(int id, String docType) =>
      'vehicles/$id/documents/$docType/';
  static String vehicleValidateDocument(int id) =>
      'vehicles/$id/validate-document/';
  static String vehicleActivate(int id) => 'vehicles/$id/activate/';
  static String vehicleDeactivate(int id) => 'vehicles/$id/deactivate/';

  static const documentTypes = 'vehicles/document-types/';
  static String documentTypeById(int id) => 'vehicles/document-types/$id/';
}
