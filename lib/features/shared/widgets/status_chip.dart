import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';
import '../../../app/theme/app_typography.dart';

/// Pill badge used for statuses (available / pending / approved / active...).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppTone.neutral,
    this.small = false,
  });

  final String label;
  final IconData? icon;
  final AppTone tone;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadius.rPill,
        border: Border.all(color: tone.foreground.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 11 : 13, color: tone.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (small ? AppTypography.overline : AppTypography.caption)
                .copyWith(color: tone.foreground),
          ),
        ],
      ),
    );
  }
}

/// Semantic color pair for badges, dots and accents.
class AppTone {
  const AppTone(this.foreground, this.background);

  final Color foreground;
  final Color background;

  static const AppTone neutral = AppTone(AppColors.muted, AppColors.surfaceAlt);
  static const AppTone success = AppTone(
    AppColors.emeraldDeep,
    AppColors.emeraldSoft,
  );
  static const AppTone warning = AppTone(
    Color(0xFFB45309),
    AppColors.warningSoft,
  );
  static const AppTone danger = AppTone(
    Color(0xFFDC2626),
    AppColors.dangerSoft,
  );
  static const AppTone info = AppTone(Color(0xFF1D4ED8), AppColors.infoSoft);
  static const AppTone brand = AppTone(Color(0xFF92600A), AppColors.brandSoft);
  static const AppTone ink = AppTone(Colors.white, AppColors.ink);

  static AppTone forStatusKey(String key) => switch (key) {
    'available' || 'active' || 'validated' || 'approved' || 'true' => success,
    'pending' || 'waiting' || 'offline' || 'expiring' => warning,
    'busy' || 'in_progress' => info,
    'inactive' || 'suspended' || 'rejected' || 'refused' || 'false' => danger,
    _ => neutral,
  };
}

/// Small circular status dot with optional pulse.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
