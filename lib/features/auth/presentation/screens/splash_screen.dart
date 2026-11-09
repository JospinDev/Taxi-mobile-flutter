import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../../features/auth/providers/auth_controller.dart';
import '../../../shared/widgets/app_motion.dart';

/// Launch screen: brand animation + session restore.
///
/// Calls [AuthController.bootstrap] once; the router then redirects to the
/// role-specific home (or login).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, .6, curve: Curves.elasticOut),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(.3, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the router's refreshListenable fires as soon as auth resolves.
    ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _logoScale,
                child: PulseRings(
                  color: AppColors.brand,
                  size: 200,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: AppRadius.rXxl,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66E8A400),
                          blurRadius: 40,
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded,
                      size: 52,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      'Taxi Driving',
                      style: AppTypography.h1.copyWith(
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'Votre taxi, à la demande',
                      style: AppTypography.body.copyWith(
                        color: Colors.white.withValues(alpha: .6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
