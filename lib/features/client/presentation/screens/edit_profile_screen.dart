import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../features/auth/providers/auth_controller.dart';
import '../../../../features/shared/widgets/app_avatar.dart';
import '../../../../features/shared/widgets/app_button.dart';
import '../../../../features/shared/widgets/app_feedback.dart';
import '../../../../features/shared/widgets/app_sections.dart';
import '../../../../features/shared/widgets/app_text_field.dart';

/// Shared "Modifier mon profil" — PATCH /accounts/me/ (client & driver).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _whatsapp;
  bool _loading = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _whatsapp = TextEditingController(text: user?.whatsapp ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
      });
      if (!mounted) return;
      setState(() => _dirty = false);
      AppToast.success(context, 'Profil mis à jour ✓');
      context.pop();
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmLeave() async {
    if (!_dirty) {
      context.pop();
      return;
    }
    final leave = await confirmDialog(
      context,
      title: 'Quitter sans sauvegarder ?',
      message: 'Vos modifications seront perdues.',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (!mounted) return;
    if (leave) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_dirty) return;
        _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Modifier le profil'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _confirmLeave,
          ),
        ),
        body: Form(
          key: _formKey,
          onChanged: () => setState(() => _dirty = true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.xl,
            ),
            children: [
              Center(
                child: AppAvatar(
                  firstName: user?.firstName,
                  lastName: user?.lastName,
                  username: user?.username,
                  size: 84,
                ),
              ),
              gapSm,
              Center(
                child: Text(user?.username ?? '', style: AppTypography.caption),
              ),
              const FormSectionLabel('INFORMATIONS PERSONNELLES'),
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
                label: 'Email',
                controller: _email,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              gapMd,
              AppTextField(
                label: 'WhatsApp',
                controller: _whatsapp,
                prefixIcon: Icons.chat_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                validator: Validators.phone,
              ),
              gapSm,
              Text(
                'Le nom d\'utilisateur et le téléphone ne peuvent pas être '
                'modifiés ici.',
                style: AppTypography.caption.copyWith(color: AppColors.faint),
              ),
              gapXl,
              AppButton(
                label: 'Enregistrer les modifications',
                icon: Icons.check_rounded,
                loading: _loading,
                onPressed: _save,
              ),
              gapSm,
              if (_dirty)
                Center(
                  child: Text(
                    'Modifications non sauvegardées',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
