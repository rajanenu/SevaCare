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
            Expanded(child: _sessionPill(context, 'MORNING', 'Morning Token', Icons.wb_sunny_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _sessionPill(context, 'EVENING', 'Evening Token', Icons.nightlight_outlined)),
          ],
        ),
        if (selectedSession != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.primarySoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 18, color: context.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: loadingPreview
                      ? Text('Checking next token…', style: AppTextStyles.label(context.colors.primary))
                      : Text(
                          nextTokenNumber != null
                              ? 'Your token number will be #$nextTokenNumber'
                              : 'Token number will be assigned on booking',
                          style: AppTextStyles.label(context.colors.primary)
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

  Widget _sessionPill(BuildContext context, String value, String label, IconData icon) {
    final isSelected = selectedSession == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: context.colors.buttonGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected ? null : context.colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? context.colors.textOnPrimary : context.colors.textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.chipLabel(isSelected ? context.colors.textOnPrimary : context.colors.text),
            ),
          ],
        ),
      ),
    );
  }
}
