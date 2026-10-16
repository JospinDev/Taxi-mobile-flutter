import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';
import '../../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, danger, ghost, success }

/// The app's standard CTA button.
///
/// * gradient primary with soft brand shadow,
/// * built-in loading state (spinner replaces the label),
/// * scale micro-interaction + haptic feedback on tap,
/// * auto-disables while [loading] to prevent double submits.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 54,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final double height;
  final TextStyle? textStyle;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _tapDown(_) => setState(() => _pressed = true);
  void _tapUp(_) => setState(() => _pressed = false);
  void _tapCancel() => setState(() => _pressed = false);

  void _handleTap() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  ({Color fg, List<BoxShadow> shadow}) _colors() => switch (widget.variant) {
    AppButtonVariant.primary => (
      fg: AppColors.ink,
      shadow: _pressed ? const [] : AppShadow.brand,
    ),
    AppButtonVariant.success => (
      fg: Colors.white,
      shadow: const [
        BoxShadow(
          color: Color(0x59059669),
          blurRadius: 20,
          offset: Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
    ),
    AppButtonVariant.danger => (
      fg: Colors.white,
      shadow: const [
        BoxShadow(
          color: Color(0x40EF4444),
          blurRadius: 18,
          offset: Offset(0, 6),
          spreadRadius: -4,
        ),
      ],
    ),
    AppButtonVariant.secondary => (fg: AppColors.ink, shadow: AppShadow.soft),
    AppButtonVariant.outline => (fg: AppColors.ink, shadow: const []),
    AppButtonVariant.ghost => (fg: AppColors.inkSoft, shadow: const []),
  };

  @override
  Widget build(BuildContext context) {
    final colors = _colors();

    Widget child = AnimatedScale(
      scale: _pressed && _enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: widget.loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color:
                    widget.variant == AppButtonVariant.outline ||
                        widget.variant == AppButtonVariant.ghost
                    ? AppColors.ink
                    : colors.fg,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: colors.fg),
                  const SizedBox(width: AppSpace.xs),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: (widget.textStyle ?? AppTypography.button).copyWith(
                      color: colors.fg,
                    ),
                  ),
                ),
              ],
            ),
    );

    final base = switch (widget.variant) {
      AppButtonVariant.primary => BoxDecoration(
        gradient: _pressed ? null : AppColors.brandGradient,
        color: _pressed ? AppColors.brandDeep : null,
        borderRadius: AppRadius.rMd,
        boxShadow: colors.shadow,
      ),
      AppButtonVariant.success => BoxDecoration(
        gradient: _pressed ? null : AppColors.emeraldGradient,
        color: _pressed ? AppColors.emeraldDeep : null,
        borderRadius: AppRadius.rMd,
        boxShadow: colors.shadow,
      ),
      AppButtonVariant.danger => BoxDecoration(
        color: _pressed ? const Color(0xFFDC2626) : AppColors.danger,
        borderRadius: AppRadius.rMd,
        boxShadow: colors.shadow,
      ),
      AppButtonVariant.secondary => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.line),
        boxShadow: colors.shadow,
      ),
      AppButtonVariant.outline => BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.line, width: 1.4),
      ),
      AppButtonVariant.ghost => BoxDecoration(
        color: _pressed
            ? AppColors.line.withValues(alpha: .5)
            : Colors.transparent,
        borderRadius: AppRadius.rMd,
      ),
    };

    return GestureDetector(
      onTapDown: _enabled ? _tapDown : null,
      onTapUp: _enabled ? _tapUp : null,
      onTapCancel: _enabled ? _tapCancel : null,
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: widget.height,
        width: widget.expanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        decoration: base,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
