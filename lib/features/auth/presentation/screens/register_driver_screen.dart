import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../data/models/auth_session.dart';
import '../../providers/auth_controller.dart';
import '../widgets/register_scaffold.dart';
import '../../../shared/widgets/app_sections.dart';

/// Driver registration — POST /accounts/auth/register-driver/
///
/// The created account starts with `driver_profile.status = pending` and
/// `is_approved = false`; the router then lands on the approval screen.
class RegisterDriverScreen extends ConsumerStatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  ConsumerState<RegisterDriverScreen> createState() =>
      _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends ConsumerState<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _license = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _loading = false;
  bool _sameWhatsapp = true;

  @override
  void dispose() {
    for (final c in [
      _username,
      _email,
      _phone,
      _whatsapp,
      _firstName,
      _lastName,
      _license,
      _password,
      _passwordConfirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerDriver(
            RegisterPayload(
              username: _username.text,
              email: _email.text,
              phone: _phone.text,
              whatsapp: _sameWhatsapp ? _phone.text : _whatsapp.text,
              firstName: _firstName.text,
              lastName: _lastName.text,
              password: _password.text,
              passwordConfirm: _passwordConfirm.text,
              licenseNumber: _license.text,
            ),
          );
      if (!mounted) return;
      AppToast.success(
        context,
        'Compte créé ! En attente de validation par un administrateur.',
      );
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegisterScaffold(
      icon: Icons.drive_eta_rounded,
      title: 'Devenir chauffeur',
      subtitle: 'Créez votre compte chauffeur, faites valider vos documents et commencez à gagner.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                StatusChip(
                  label: 'VALIDATION ADMIN',
                  icon: Icons.verified_user_outlined,
                  tone: AppTone.brand,
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Votre compte sera examiné par un administrateur avant de '
              'pouvoir accepter des courses.',
              style: AppTypography.caption.copyWith(height: 1.5),
            ),

            const FormSectionLabel('IDENTITÉ'),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Prénom',
                    controller: _firstName,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'Prénom'),
                  ),
                ),
                gapSm,
                Expanded(
                  child: AppTextField(
                    label: 'Nom',
                    controller: _lastName,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'Nom'),
                  ),
                ),
              ],
            ),
            gapMd,
            AppTextField(
              label: 'Nom d\'utilisateur',
              hint: 'ex: pierre',
              controller: _username,
              prefixIcon: Icons.alternate_email_rounded,
              textInputAction: TextInputAction.next,
              validator: Validators.username,
            ),
            gapMd,
            AppTextField(
              label: 'Email',
              hint: 'pierre@test.com',
              controller: _email,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
            ),
            gapMd,
            AppTextField(
              label: 'Téléphone',
              hint: '+25769876543',
              controller: _phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: Validators.phone,
            ),
            gapSm,
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Utiliser le même numéro pour WhatsApp',
                    style: AppTypography.caption,
                  ),
                ),
                Switch(
                  value: _sameWhatsapp,
                  onChanged: (v) => setState(() => _sameWhatsapp = v),
                ),
              ],
            ),
            if (!_sameWhatsapp) ...[
              gapSm,
              AppTextField(
                label: 'WhatsApp',
                hint: '+25769876543',
                controller: _whatsapp,
                prefixIcon: Icons.chat_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: Validators.phone,
              ),
            ],

            const FormSectionLabel('PERMIS DE CONDUIRE'),
            AppTextField(
              label: 'N° de permis',
              hint: 'ex: PERM-2026-001',
              controller: _license,
              prefixIcon: Icons.credit_card_rounded,
              textInputAction: TextInputAction.next,
              validator: Validators.licenseNumber,
            ),

            const FormSectionLabel('MOT DE PASSE'),
            AppTextField(
              label: 'Mot de passe',
              hint: '8 caractères min. (lettre + chiffre)',
              controller: _password,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
            ),
            gapMd,
            AppTextField(
              label: 'Confirmer le mot de passe',
              controller: _passwordConfirm,
              prefixIcon: Icons.lock_reset_outlined,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => Validators.passwordConfirm(v, _password.text),
            ),
            const SizedBox(height: AppSpace.xl),
            AppButton(
              label: 'Créer mon compte chauffeur',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Déjà un compte ?',
                  style: AppTypography.body.copyWith(color: AppColors.muted),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Se connecter',
                    style: AppTypography.button.copyWith(
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
              ],
            ),
            gapLg,
          ],
        ),
      ),
    );
  }
}
