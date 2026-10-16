import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';
import '../../../app/theme/app_typography.dart';

/// Section title with optional trailing action ("Voir tout", add...).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  actionLabel!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Labeled value row used in detail/profile screens.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.faint),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.overline.copyWith(
                    color: AppColors.faint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.bodyLg),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small caps section label used inside forms.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.sm),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTypography.overline),
      ],
    ),
  );
}

/// Vertical gap helpers to keep call-sites tidy.
const SizedBox gapXs = SizedBox(height: AppSpace.xs);
const SizedBox gapSm = SizedBox(height: AppSpace.sm);
const SizedBox gapMd = SizedBox(height: AppSpace.md);
const SizedBox gapLg = SizedBox(height: AppSpace.lg);
const SizedBox gapXl = SizedBox(height: AppSpace.xl);
