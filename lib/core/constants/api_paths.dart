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

  // ────────────────────────── MODULE 3 — CONTRACTS ────────────────────────────
  static const contracts = 'contracts/';
  static String contractById(int id) => 'contracts/$id/';
  static String contractSign(int id) => 'contracts/$id/sign/';
  static String contractActivate(int id) => 'contracts/$id/activate/';
  static String contractDeactivate(int id) => 'contracts/$id/deactivate/';

  // ─────────────────────────── MODULE 4 — PRICING ─────────────────────────────
  static const pricingRules = 'pricing/rules/';
  static const pricingRuleActive = 'pricing/rules/active/';
  static String pricingRuleById(int id) => 'pricing/rules/$id/';
  static String pricingRuleActivate(int id) => 'pricing/rules/$id/activate/';
  static String pricingRuleDeactivate(int id) => 'pricing/rules/$id/deactivate/';

  // ─────────────────────── MODULE 5/6 — RIDES & TRACKING ─────────────────────
  static const rides = 'rides/';
  static const rideEstimate = 'rides/estimate/';
  static const rideCurrent = 'rides/current/';
  static const rideOffers = 'rides/offers/';
  static const rideNearbyDrivers = 'rides/nearby-drivers/';
  static String rideById(int id) => 'rides/$id/';
  static String rideAccept(int id) => 'rides/$id/accept/';
  static String rideReject(int id) => 'rides/$id/reject/';
  static String rideCancel(int id) => 'rides/$id/cancel/';
  static String rideArrived(int id) => 'rides/$id/arrived/';
  static String rideStart(int id) => 'rides/$id/start/';
  static String rideTrack(int id) => 'rides/$id/track/';
  static String rideRoute(int id) => 'rides/$id/route/';
  static String rideComplete(int id) => 'rides/$id/complete/';
  static String rideRate(int id) => 'rides/$id/rate/';
  static String rideConfirmPayment(int id) => 'rides/$id/confirm-payment/';

  // ─────────────────────────── MODULE 9 — CHAT ────────────────────────────────
  static String rideMessages(int id) => 'rides/$id/messages/';
  static String rideMessagesRead(int id) => 'rides/$id/messages/read/';

  // ─────────────────────── MODULE 7 — PAYMENTS & WALLET ───────────────────────
  static const wallets = 'payments/wallets/';
  static const myWallet = 'payments/wallets/me/';
  static String walletPayout(int id) => 'payments/wallets/$id/payout/';
  static String walletAdjust(int id) => 'payments/wallets/$id/adjust/';
  static const walletTransactions = 'payments/transactions/';

  // ──────────────────────── MODULE 8 — NOTIFICATIONS ──────────────────────────
  static const notifications = 'notifications/';
  static const notificationsUnread = 'notifications/unread-count/';
  static const notificationsReadAll = 'notifications/read-all/';
  static String notificationRead(int id) => 'notifications/$id/read/';

  // ───────────────────────────── WEBSOCKETS ───────────────────────────────────
  static const wsNotifications = 'ws/notifications/';
  static String wsRide(int id) => 'ws/rides/$id/';
}
