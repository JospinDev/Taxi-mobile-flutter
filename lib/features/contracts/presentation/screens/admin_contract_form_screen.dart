import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../admin/providers/admin_providers.dart';
import '../../../auth/data/models/driver_profile_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_sections.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../providers/contract_providers.dart';

/// ADMIN — create a contract (POST /contracts/). Created unsigned & inactive,
/// awaiting the driver's signature, then admin activation.
class AdminContractFormScreen extends ConsumerStatefulWidget {
  const AdminContractFormScreen({super.key});

  @override
  ConsumerState<AdminContractFormScreen> createState() =>
      _AdminContractFormScreenState();
}

class _AdminContractFormScreenState
    extends ConsumerState<AdminContractFormScreen> {
  final _commission = TextEditingController(text: '20');
  final _content = TextEditingController();
  final _search = TextEditingController();
  DriverProfile? _selected;
  bool _saving = false;
  bool _init = false;

  @override
  void dispose() {
    _commission.dispose();
    _content.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final driver = _selected;
    if (driver == null) {
      AppToast.error(context, 'Sélectionnez un chauffeur.');
      return;
    }
    final pct = double.tryParse(_commission.text.trim());
    if (pct == null || pct <= 0 || pct >= 100) {
      AppToast.error(context, 'Pourcentage invalide (entre 1 et 99).');
      return;
    }
    if (_content.text.trim().isEmpty) {
      AppToast.error(context, 'Rédigez les conditions du contrat.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(adminContractsProvider.notifier).create(
        driver: driver.id,
        commissionPercent: pct.toStringAsFixed(2),
        content: _content.text.trim(),
      );
      if (!mounted) return;
      AppToast.success(context, 'Contrat créé ✓');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_init) {
      _init = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminDriversProvider.notifier).loadMore();
      });
    }
    final drivers = ref.watch(adminDriversProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouveau contrat'),
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.adminContracts);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          const FormSectionLabel('CHAUFFEUR'),
          AppTextField(
            label: 'Rechercher un chauffeur',
            kind: AppFieldKind.search,
            controller: _search,
            prefixIcon: Icons.search_rounded,
            onChanged: (v) => ref
                .read(adminDriversProvider.notifier)
                .setFilter(DriversFilter(search: v)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: drivers.when(
              loading: () => ListView(
                children: const [
                  SkeletonBox(height: 56),
                  SizedBox(height: 8),
                  SkeletonBox(height: 56),
                ],
              ),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(adminDriversProvider),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun chauffeur trouvé.',
                        style: AppTypography.caption,
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => _DriverTile(
                        driver: items[i],
                        selected: _selected?.id == items[i].id,
                        onSelect: () => setState(() => _selected = items[i]),
                      ),
                    ),
            ),
          ),
          const FormSectionLabel('COMMISSION'),
          const FormSectionLabel('COMMISSION'),
          AppTextField(
            label: 'Pourcentage de la société (%)',
            controller: _commission,
            hint: 'Ex : 20',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            prefixIcon: Icons.percent_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 6),
          Text(
            'Part prélevée par la société sur chaque course.',
            style: AppTypography.caption.copyWith(color: AppColors.faint),
          ),
          const FormSectionLabel('CONDITIONS'),
          AppTextField(
            label: 'Texte du contrat',
            controller: _content,
            hint: 'Rédigez les termes acceptés par le chauffeur…',
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpace.xl),
          AppButton(
            label: _saving ? 'Création…' : 'Créer le contrat',
            icon: Icons.add_rounded,
            loading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({
    required this.driver,
    required this.selected,
    required this.onSelect,
  });

  final DriverProfile driver;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final u = driver.user;
    final name = (u.firstName != null && u.lastName != null)
        ? '${u.firstName} ${u.lastName}'
        : u.username;
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.brandSoft,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      onTap: onSelect,
      leading: CircleAvatar(
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
      ),
      title: Text(
        name,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '#${driver.id}',
        style: AppTypography.caption.copyWith(color: AppColors.inkSoft),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.brand)
          : const Icon(Icons.chevron_right_rounded, color: AppColors.line),
    );
  }
}