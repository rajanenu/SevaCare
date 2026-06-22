import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

class BottomNavItem {
  final String label;
  final IconData icon;
  final String route;

  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

class AppBottomNav extends StatelessWidget {
  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: SevaCareColors.glassSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: SevaCareColors.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SevaCareColors.shadowColor.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isActive = index == currentIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                            color: SevaCareColors.primary.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: isActive ? SevaCareColors.textOnPrimary : SevaCareColors.textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: AppTextStyles.body(
                        size: 10,
                        weight: FontWeight.w600,
                        color: isActive ? SevaCareColors.textOnPrimary : SevaCareColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
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
