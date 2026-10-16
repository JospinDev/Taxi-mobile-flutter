import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';
import '../../../app/theme/app_typography.dart';

/// Full-screen loading indicator with subtle message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(message!, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// Shimmer-like placeholder card list while data loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 96, this.radius = AppRadius.lg});

  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _c.value, 0),
            end: Alignment(1 + 2 * _c.value, 0),
            colors: const [
              Color(0xFFF1F3F8),
              Color(0xFFFAFBFD),
              Color(0xFFF1F3F8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic error state with retry.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.title = 'Oups, une erreur est survenue',
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: const BoxDecoration(
                color: AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.danger),
            ),
            const SizedBox(height: AppSpace.md),
            Text(title, textAlign: TextAlign.center, style: AppTypography.h3),
            if (message != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.muted),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.lg),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state (no results, module not available yet...).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.auto_awesome_rounded,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: AppRadius.rXl,
              ),
              child: Icon(icon, size: 36, color: AppColors.brandDeep),
            ),
            const SizedBox(height: AppSpace.md),
            Text(title, textAlign: TextAlign.center, style: AppTypography.h3),
            if (message != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
