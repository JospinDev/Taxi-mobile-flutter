import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../providers/auth_controller.dart';

/// Login (client & driver).
///
/// The "Je suis chauffeur" toggle only changes which registration flow the
/// link points to — the login endpoint is the same for both roles; the API
/// answers with the user's real role and the router routes accordingly.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _driverMode = false;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(username: _usernameCtrl.text, password: _passwordCtrl.text);
      if (mounted) AppToast.success(context, 'Bienvenue !');
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // ── Hero ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  top + AppSpace.xl,
                  AppSpace.xl,
                  AppSpace.xxl + 12,
                ),
                decoration: const BoxDecoration(
                  gradient: AppColors.darkGradient,
                ),
                child: Column(
                  children: [
                    PulseRings(
                      color: AppColors.brand,
                      size: 150,
                      rings: 2,
                      child: _logo(),
                    ),
                    Text(
                      'Bon retour 👋',
                      style: AppTypography.h1.copyWith(color: Colors.white),
                    ).entrance(index: 1),
                    const SizedBox(height: 4),
                    Text(
                      _driverMode
                          ? 'Connectez-vous pour recevoir des courses'
                          : 'Connectez-vous pour commander un taxi',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: Colors.white60),
                    ).entrance(index: 2),
                  ],
                ),
              ),
              // ── Form sheet ─────────────────────────────────────────
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * .62,
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl,
                    AppSpace.xl,
                    AppSpace.xl,
                    AppSpace.xl,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: AutofillGroup(child: _form()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleToggle(
            driverMode: _driverMode,
            onChanged: (v) => setState(() => _driverMode = v),
          ).entrance(index: 2),
          const SizedBox(height: AppSpace.xl),
          AppTextField(
            label: 'Nom d\'utilisateur',
            hint: 'ex: jean',
            controller: _usernameCtrl,
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            validator: (v) => Validators.required(v, 'Nom d\'utilisateur'),
          ),
          gapMd,
          AppTextField(
            label: 'Mot de passe',
            hint: '••••••••',
            controller: _passwordCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            validator: (v) => Validators.required(v, 'Mot de passe'),
          ).entrance(index: 4),
          const SizedBox(height: AppSpace.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => AppToast.info(
                context,
                'Réinitialisation du mot de passe : contactez le support.',
              ),
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
          gapMd,
          AppButton(
            label: 'Se connecter',
            icon: Icons.arrow_forward_rounded,
            loading: _loading,
            onPressed: _submit,
          ).entrance(index: 5),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _driverMode ? 'Pas encore chauffeur ?' : 'Nouveau ici ?',
                style: AppTypography.body.copyWith(color: AppColors.muted),
              ),
              TextButton(
                onPressed: () => context.push(
                  _driverMode ? Routes.registerDriver : Routes.registerClient,
                ),
                child: Text(
                  _driverMode ? 'Devenir chauffeur' : 'Créer un compte',
                  style: AppTypography.button.copyWith(
                    color: AppColors.brandDeep,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logo() => Center(
    child: Container(
      width: 76,
      height: 76,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppRadius.rXl,
        boxShadow: const [
          BoxShadow(
            color: Color(0x4DE8A400),
            blurRadius: 26,
            offset: Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: const Icon(
        Icons.local_taxi_rounded,
        size: 40,
        color: AppColors.ink,
      ),
    ).popIn(),
  );
}

/// iOS-like segmented control: "Je suis client" / "Je suis chauffeur".
class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.driverMode, required this.onChanged});

  final bool driverMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rPill,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _Segment(
            label: 'Je suis client',
            icon: Icons.person_outline_rounded,
            selected: !driverMode,
            onTap: () => onChanged(false),
          ),
          _Segment(
            label: 'Je suis chauffeur',
            icon: Icons.drive_eta_rounded,
            selected: driverMode,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: AppRadius.rPill,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x260F172A),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.brand : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: selected ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
