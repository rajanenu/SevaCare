import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

class AppFormField extends StatelessWidget {
  final String label;
  final String? value;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool required;
  final bool readOnly;
  final bool obscureText;
  final int? maxLines;
  final String? errorText;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;

  /// Puts the cursor here the moment the field appears, so a screen whose job
  /// is "type this one thing" needs no tap to start typing.
  final bool autofocus;

  const AppFormField({
    super.key,
    required this.label,
    this.value,
    this.placeholder,
    this.onChanged,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.required = false,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.errorText,
    this.validator,
    this.inputFormatters,
    this.suffixIcon,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTextStyles.label(context.colors.textMuted)),
            if (required)
              Text(' *', style: AppTextStyles.label(context.colors.danger)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller ?? (value != null ? (TextEditingController(text: value)) : null),
          onChanged: onChanged,
          keyboardType: keyboardType,
          readOnly: readOnly,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          validator: validator,
          inputFormatters: inputFormatters,
          focusNode: focusNode,
          autofocus: autofocus,
          textInputAction: textInputAction,
          onEditingComplete: onEditingComplete,
          style: AppTextStyles.inputText(context.colors.text),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTextStyles.inputHint(context.colors.textMuted.withValues(alpha: 0.6)),
            errorText: errorText,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? context.colors.surfaceMuted : context.colors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.error, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// Dropdown select widget
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool required;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTextStyles.label(context.colors.textMuted)),
            if (required) Text(' *', style: AppTextStyles.label(context.colors.danger)),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          style: AppTextStyles.inputText(context.colors.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.colors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide(color: context.colors.primary, width: 2),
            ),
          ),
          dropdownColor: context.colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
