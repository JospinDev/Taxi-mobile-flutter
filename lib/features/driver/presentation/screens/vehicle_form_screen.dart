import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../providers/vehicle_providers.dart';

/// DRIVER — "Enregistrer mon véhicule" → POST /vehicles/
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _seats = TextEditingController(text: '4');
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_plate, _brand, _model, _year, _color, _seats]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final vehicle = await ref.read(vehiclesProvider.notifier).create({
        'plate_number': _plate.text.trim().toUpperCase(),
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'year': int.parse(_year.text.trim()),
        'color': _color.text.trim(),
        'seats': int.parse(_seats.text.trim()),
      });
      if (!mounted) return;
      AppToast.success(
        context,
        'Véhicule enregistré ! Ajoutez maintenant vos documents.',
      );
      context.pop();
      context.push('/driver/vehicles/${vehicle.id}');
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajouter un véhicule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.sm,
            AppSpace.xl,
            AppSpace.xl,
          ),
          children: [
            Container(
              padding: AppSpace.card,
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: AppRadius.rLg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le véhicule sera inactif tant que l\'administrateur '
                      'n\'a pas validé tous les documents obligatoires.',
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF1D4ED8),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const FormSectionLabel('IMMATRICULATION'),
            AppTextField(
              label: 'Numéro de plaque',
              hint: 'ex: AB-123-CD',
              controller: _plate,
              prefixIcon: Icons.confirmation_number_outlined,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              validator: Validators.plateNumber,
            ),
            gapMd,
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Marque',
                    hint: 'Toyota',
                    controller: _brand,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'Marque'),
                  ),
                ),
                gapSm,
                Expanded(
                  child: AppTextField(
                    label: 'Modèle',
                    hint: 'Corolla',
                    controller: _model,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'Modèle'),
                  ),
                ),
              ],
            ),
            const FormSectionLabel('CARACTÉRISTIQUES'),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Année',
                    hint: '2018',
                    controller: _year,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: Validators.year,
                  ),
                ),
                gapSm,
                Expanded(
                  child: AppTextField(
                    label: 'Sièges',
                    hint: '5',
                    controller: _seats,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: Validators.seats,
                  ),
                ),
              ],
            ),
            gapMd,
            AppTextField(
              label: 'Couleur',
              hint: 'Blanc',
              controller: _color,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => Validators.required(v, 'Couleur'),
            ),
            gapXl,
            AppButton(
              label: 'Enregistrer le véhicule',
              icon: Icons.check_rounded,
              loading: _loading,
              onPressed: _submit,
            ),
            gapSm,
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Annuler'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
