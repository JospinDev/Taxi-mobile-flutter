import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';

export '../../../shared/widgets/app_sections.dart' show FormSectionLabel;

/// Shared chrome for the two registration screens: gradient header with
/// back button, step title/subtitle, and scrollable form body.
class RegisterScaffold extends StatelessWidget {
  const RegisterScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Hero header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: AppSpace.xl,
              left: AppSpace.md,
              right: AppSpace.md,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.darkGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: .1),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.h2.copyWith(color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: AppRadius.rMd,
                      ),
                      child: Icon(icon, size: 24, color: AppColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    subtitle,
                    style: AppTypography.body.copyWith(
                      color: Colors.white.withValues(alpha: .65),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Form body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: form,
            ),
          ),
          if (footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.sm,
                  AppSpace.xl,
                  AppSpace.xl,
                ),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}
