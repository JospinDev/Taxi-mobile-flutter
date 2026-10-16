import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';

/// Global helper for snackbar feedback (success / error / info).
///
/// Every user action must give feedback: use [AppToast.success] after a
/// mutation, [AppToast.error] in `catch` blocks, [AppToast.apiError] which
/// understands [ApiException].
class AppToast {
  const AppToast._();

  static void _show(
    BuildContext context,
    String message, {
    required Color color,
    required IconData icon,
  }) {
    // Collapse duplicates (e.g. repeated polling errors).
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.ink,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void success(BuildContext context, String message) => _show(
    context,
    message,
    color: AppColors.emerald,
    icon: Icons.check_circle_rounded,
  );

  static void error(BuildContext context, String message) => _show(
    context,
    message,
    color: const Color(0xFFFF8A80),
    icon: Icons.error_rounded,
  );

  static void info(BuildContext context, String message) =>
      _show(context, message, color: AppColors.brand, icon: Icons.info_rounded);

  /// Maps any thrown object to a friendly message.
  static void apiError(BuildContext context, Object error) {
    final message = error is ApiException
        ? error.message
        : 'Une erreur est survenue. Veuillez réessayer.';
    _show(
      context,
      message,
      color: const Color(0xFFFF8A80),
      icon: Icons.error_rounded,
    );
  }
}

/// Confirmation dialog — used for destructive actions (delete, logout...).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: destructive ? AppColors.dangerSoft : AppColors.brandSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 26,
          color: destructive ? AppColors.danger : AppColors.brandDeep,
        ),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.danger : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
