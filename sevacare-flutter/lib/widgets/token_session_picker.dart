import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// Morning/Evening session picker for token-based booking. Tokens have no
/// fixed time grid — the patient just picks a session and gets the next
/// sequential number, so this shows two large pills plus a live preview of
/// the token number that will be assigned once a session is chosen.
class TokenSessionPicker extends StatelessWidget {
  final String? selectedSession;
  final ValueChanged<String> onSelect;
  final bool loadingPreview;
  final int? nextTokenNumber;

  const TokenSessionPicker({
    super.key,
    required this.selectedSession,
    required this.onSelect,
    this.loadingPreview = false,
    this.nextTokenNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sessionPill('MORNING', 'Morning Token', Icons.wb_sunny_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _sessionPill('EVENING', 'Evening Token', Icons.nightlight_outlined)),
          ],
        ),
        if (selectedSession != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: SevaCareColors.primarySoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: SevaCareColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 18, color: SevaCareColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: loadingPreview
                      ? Text('Checking next token…', style: AppTextStyles.label(SevaCareColors.primary))
                      : Text(
                          nextTokenNumber != null
                              ? 'Your token number will be #$nextTokenNumber'
                              : 'Token number will be assigned on booking',
                          style: AppTextStyles.label(SevaCareColors.primary)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sessionPill(String value, String label, IconData icon) {
    final isSelected = selectedSession == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: SevaCareColors.buttonGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected ? null : SevaCareColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: isSelected ? SevaCareColors.primary : SevaCareColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? SevaCareColors.textOnPrimary : SevaCareColors.textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.chipLabel(isSelected ? SevaCareColors.textOnPrimary : SevaCareColors.text),
            ),
          ],
        ),
      ),
    );
  }
}
