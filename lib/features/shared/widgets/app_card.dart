import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';

/// Standard elevated card with soft double shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpace.card,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color = AppColors.surface,
    this.border,
    this.shadow,
    this.radius,
    this.animate = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color color;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final BorderRadius? radius;

  /// Subtle fade + rise when the card appears (every screen gets it for free).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final card = _build(context);
    if (!animate) return card;
    return card
        .animate()
        .fadeIn(duration: 260.ms, curve: Curves.easeOutCubic)
        .slideY(begin: .04, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }

  Widget _build(BuildContext context) {
    final r = radius ?? AppRadius.rLg;
    // `AppShadow.card` is a getter (not a const), so it can't be a
    // default parameter value in a const constructor. Resolve it here.
    final effectiveShadow = shadow ?? AppShadow.card;
    final decoration = BoxDecoration(
      color: color,
      borderRadius: r,
      border: border,
      boxShadow: effectiveShadow,
    );

    if (onTap == null) {
      return Padding(
        padding: margin,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      );
    }

    // Use Ink for the background so the InkWell splash paints *above*
    // the card color instead of being hidden behind a Container.
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: double.infinity,
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: r,
            splashColor: AppColors.brand.withValues(alpha: .2),
            highlightColor: AppColors.ink.withValues(alpha: .04),
            child: Container(
              width: double.infinity,
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated press feedback wrapper for custom tap targets.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _down = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
