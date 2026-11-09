import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../driver/data/models/document_type_model.dart';
import '../../../driver/providers/vehicle_providers.dart';
import 'admin_shell.dart';

class AdminDocumentTypesScreen extends ConsumerStatefulWidget {
  const AdminDocumentTypesScreen({super.key});
  @override
  ConsumerState<AdminDocumentTypesScreen> createState() => _S();
}

class _S extends ConsumerState<AdminDocumentTypesScreen> {
  bool _all = false;
  Future<void> _save({DocumentType? cur}) async {
    final r = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _Form(cur: cur),
    );
    if (r == null || !mounted) return;
    try {
      if (cur == null) {
        await ref.read(documentTypesProvider.notifier).create(r);
        if (mounted) AppToast.success(context, 'Type cree');
      } else {
        await ref.read(documentTypesProvider.notifier).updateType(cur.id, r);
        if (mounted) AppToast.success(context, 'Type mis a jour');
      }
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    }
  }

  Future<void> _tog(DocumentType t) async {
    try {
      await ref.read(documentTypesProvider.notifier).updateType(t.id, {
        'is_active': !t.isActive,
      });
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    }
  }

  Future<void> _del(DocumentType t) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer « ${t.label} » ?',
      message: 'Le slot ne sera plus propose aux chauffeurs.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(documentTypesProvider.notifier).remove(t.id);
      if (mounted) AppToast.success(context, 'Type supprime');
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(documentTypesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Types de documents'),
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _save(),
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Masquer les inactifs',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: !_all,
                  onChanged: (v) {
                    setState(() => _all = !v);
                    ref
                        .read(documentTypesProvider.notifier)
                        .setFilter(activeOnly: v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ts.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const SkeletonBox(height: 92),
              ),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(documentTypesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyView(
                    icon: Icons.folder_copy_outlined,
                    title: 'Aucun type',
                    message: 'Creez le premier type de document.',
                    action: AppButton(
                      label: 'Nouveau type',
                      icon: Icons.add_rounded,
                      expanded: false,
                      onPressed: () => _save(),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(documentTypesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      final t = items[i];
                      final iconColors = [AppColors.info, AppColors.brand, AppColors.emerald, AppColors.warning, AppColors.danger];
                      final iconColor = iconColors[t.order % iconColors.length];
                      return AppCard(
                        animate: false,
                        border: Border(left: BorderSide(color: t.isActive ? iconColor : AppColors.line, width: 4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: .12),
                                    borderRadius: AppRadius.rMd,
                                  ),
                                  child: Icon(Icons.description_rounded, size: 20, color: iconColor),
                                ),
                                Expanded(
                                  child: Text(
                                    t.label,
                                    style: AppTypography.bodyLg.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                StatusChip(
                                  label: t.isActive ? 'ACTIF' : 'INACTIF',
                                  tone: t.isActive
                                      ? AppTone.success
                                      : AppTone.neutral,
                                  small: true,
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.rMd,
                                  ),
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _save(cur: t);
                                    } else if (v == 'tog') {
                                      _tog(t);
                                    } else {
                                      _del(t);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Modifier'),
                                    ),
                                    PopupMenuItem(
                                      value: 'tog',
                                      child: Text('Activer / desactiver'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'del',
                                      child: Text(
                                        'Supprimer',
                                        style: TextStyle(
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              'Code : ${t.code} · ordre ${t.order}',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (t.isRequired)
                                  const StatusChip(
                                    label: 'OBLIGATOIRE',
                                    tone: AppTone.warning,
                                    small: true,
                                  ),
                                if (t.requiresExpiry)
                                  const StatusChip(
                                    label: 'AVEC EXPIRATION',
                                    icon: Icons.event_rounded,
                                    tone: AppTone.info,
                                    small: true,
                                  ),
                                if ((t.description ?? '').isNotEmpty)
                                  StatusChip(
                                    label: t.description!,
                                    tone: AppTone.neutral,
                                    small: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ).entrance(index: i);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({this.cur});

  final DocumentType? cur;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController _code;
  late final TextEditingController _label;
  late final TextEditingController _desc;
  late final TextEditingController _order;

  late bool _isRequired;
  late bool _requiresExpiry;
  late bool _isActive;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cur = widget.cur;
    _code = TextEditingController(text: cur?.code ?? '');
    _label = TextEditingController(text: cur?.label ?? '');
    _desc = TextEditingController(text: cur?.description ?? '');
    _order = TextEditingController(text: '${cur?.order ?? 0}');
    _isRequired = cur?.isRequired ?? false;
    _requiresExpiry = cur?.requiresExpiry ?? false;
    _isActive = cur?.isActive ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _label.dispose();
    _desc.dispose();
    _order.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code.text.trim();
    final label = _label.text.trim();
    if (code.isEmpty || label.isEmpty) {
      setState(() => _error = 'Code et libelle sont requis.');
      return;
    }
    final order = int.tryParse(_order.text.trim()) ?? 0;
    Navigator.of(context).pop<Map<String, dynamic>>({
      'code': code,
      'label': label,
      'description': _desc.text.trim(),
      'is_required': _isRequired,
      'requires_expiry': _requiresExpiry,
      'is_active': _isActive,
      'order': order,
    });
  }
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cur != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Modifier le type' : 'Nouveau type',
              style: AppTypography.h3,
            ),
            const SizedBox(height: 4),
            Text(
              isEdit ? 'Modifiez le slot document.' : 'Creez un slot chauffeur.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Code',
              controller: _code,
              hint: 'Ex : permis_conduire',
              enabled: !isEdit,
              autocorrect: false,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Libelle',
              controller: _label,
              hint: 'Ex : Permis de conduire',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Description (optionnel)',
              controller: _desc,
              hint: 'Precision pour les chauffeurs',
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Ordre',
              controller: _order,
              hint: '0',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obligatoire'),
              value: _isRequired,
              onChanged: (v) => setState(() => _isRequired = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avec expiration'),
              value: _requiresExpiry,
              onChanged: (v) => setState(() => _requiresExpiry = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actif'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Annuler',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: isEdit ? 'Enregistrer' : 'Creer',
                    icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


