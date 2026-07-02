import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  const SegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SevaCareColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: SevaCareColors.border, width: 1),
      ),
      child: Row(
        children: items.map((item) {
          final isActive = item.value == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: SevaCareColors.buttonGradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: SevaCareColors.primary.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 13,
                        color: isActive
                            ? SevaCareColors.textOnPrimary
                            : SevaCareColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.chipLabel(
                          isActive
                              ? SevaCareColors.textOnPrimary
                              : SevaCareColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  const SegmentItem({required this.value, required this.label, this.icon});
}
