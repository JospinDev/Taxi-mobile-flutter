import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';

/// Gradient initials avatar — no network images needed anywhere in the app.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.firstName,
    this.lastName,
    this.username,
    this.size = 48,
    this.icon,
    this.iconColor,
  });

  final String? firstName;
  final String? lastName;
  final String? username;
  final double size;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final initials = Formatters.initials(
      firstName,
      lastName,
      username: username,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33E8A400),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: icon != null
          ? Icon(icon, color: iconColor ?? AppColors.ink, size: size * 0.46)
          : Text(
              initials,
              style: AppTypography.h3.copyWith(
                fontSize: size * 0.36,
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
