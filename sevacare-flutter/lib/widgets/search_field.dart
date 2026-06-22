import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

class SearchField extends StatelessWidget {
  final String? value;
  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  const SearchField({
    super.key,
    this.value,
    this.controller,
    this.placeholder = 'Search…',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: SevaCareColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.inputText(SevaCareColors.text),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 20, color: SevaCareColors.textMuted),
          hintText: placeholder,
          hintStyle: AppTextStyles.inputHint(SevaCareColors.textMuted.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
