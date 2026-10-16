import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../providers/auth_controller.dart';

/// Shown to drivers whose account is still `is_approved = false`.
///
/// Polls `GET /accounts/drivers/me/` every [AppConfig.approvalPollInterval];
/// as soon as an admin approves, the auth state updates and the router
/// automatically lands on the dashboard.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _checks = 0;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(AppConfig.approvalPollInterval, (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    _checks++;
    try {
      await ref.read(authControllerProvider.notifier).refreshDriverProfile();
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      if (!auth.isDriverPendingApproval) {
        _timer?.cancel();
        AppToast.success(context, 'Votre compte a été approuvé ! 🎉');
        // Router redirects to the dashboard on the next frame.
      }
    } catch (e) {
      // Transient network errors must not kill the polling loop.
      if (_checks % 12 == 0 && mounted) AppToast.apiError(context, e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final approvedAt = ref.watch(
      authControllerProvider.select((s) => s.driverProfile?.approvedAt),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            children: [
              const Spacer(),
              _pulsingMark(),
              const SizedBox(height: AppSpace.xl),
              Text(
                'Compte en cours de validation',
                textAlign: TextAlign.center,
                style: AppTypography.h1.copyWith(fontSize: 26),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Votre compte chauffeur est en attente de validation par un '
                'administrateur. Cela prend généralement peu de temps.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              _statusCard(user, approvedAt),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Se déconnecter'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: _check,
                child: const Text('Vérifier maintenant'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pulsingMark() => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) {
      final t = _pulse.value;
      return Container(
        width: 132 + 16 * t,
        height: 132 + 16 * t,
        decoration: BoxDecoration(
          color: AppColors.brandSoft.withValues(alpha: 1 - .25 * t),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            gradient: AppColors.brandGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x59E8A400),
                blurRadius: 30,
                spreadRadius: -6,
              ),
            ],
          ),
          child: const Icon(
            Icons.hourglass_bottom_rounded,
            size: 44,
            color: AppColors.ink,
          ),
        ),
      );
    },
  );

  Widget _statusCard(dynamic user, String? approvedAt) => Container(
    padding: AppSpace.card,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.rLg,
      border: Border.all(color: AppColors.line),
      boxShadow: AppShadow.soft,
    ),
    child: Column(
      children: [
        _row(
          Icons.person_outline_rounded,
          'Compte',
          user != null
              ? Formatters.fullName(
                  user.firstName as String?,
                  user.lastName as String?,
                  fallback: user.username as String? ?? '—',
                )
              : '—',
        ),
        const Divider(height: 20),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brandDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Vérification automatique toutes les '
                '${AppConfig.approvalPollInterval.inSeconds} s…',
                style: AppTypography.caption,
              ),
            ),
            Text(
              approvedAt != null
                  ? 'Approuvé ${Formatters.dateTime(approvedAt)}'
                  : 'En attente',
              style: AppTypography.caption.copyWith(
                color: AppColors.brandDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _row(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.faint),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: AppTypography.caption)),
      Text(
        value,
        style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
