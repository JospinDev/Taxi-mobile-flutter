import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';
import '../../../app/theme/app_typography.dart';

/// Labeled text field with floating label, optional obscure toggle,
/// leading icon, and preset styles ([AppFieldKind.form] for full forms,
/// [AppFieldKind.search] for the search bars).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.autocorrect = false,
    this.enabled = true,
    this.obscureText = false,
    this.required = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.initialValue,
    this.maxLines = 1,
    this.kind = AppFieldKind.form,
    this.prefix,
    this.suffix,
    this.onTap,
    this.readOnly = false,
  });

  final String label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enabled;
  final bool obscureText;
  final bool required;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final String? initialValue;
  final int maxLines;
  final AppFieldKind kind;
  final Widget? prefix;
  final Widget? suffix;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

enum AppFieldKind { form, search }

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final isSearch = widget.kind == AppFieldKind.search;

    final decoration = InputDecoration(
      labelText: isSearch ? null : widget.label,
      hintText: widget.hint ?? (isSearch ? widget.label : null),
      helperText: widget.error ?? widget.helper,
      helperMaxLines: 2,
      errorText: widget.error,
      errorMaxLines: 2,
      prefixIcon: widget.prefixIcon != null
          ? Icon(widget.prefixIcon, size: isSearch ? 20 : 22)
          : null,
      prefix: isSearch ? widget.prefix : null,
      suffixIcon:
          widget.suffix ??
          (widget.obscureText
              ? IconButton(
                  tooltip: _obscured ? 'Afficher' : 'Masquer',
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : null),
      filled: true,
      fillColor: isSearch ? AppColors.surface : null,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );

    final field = TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      obscureText: _obscured,
      autocorrect: widget.autocorrect,
      enableSuggestions: !widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      style: isSearch
          ? AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)
          : AppTypography.bodyLg,
      decoration: decoration,
    );

    if (!isSearch) return field;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadow.soft,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: field,
    );
  }
}
