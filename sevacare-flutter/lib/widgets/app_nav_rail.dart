import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/i18n.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/role_style.dart';
import '../data/models/models.dart';
import 'bottom_nav.dart';

const double kAppNavRailWidth = 220;

/// Sidebar navigation shown instead of [AppBottomNav] on tablet/desktop
/// widths. Takes the same `items`/`currentIndex`/`onTap` shape as the bottom
/// nav so screens don't need any changes to opt into it.
class AppNavRail extends ConsumerWidget {
  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final UserRole? role;

  const AppNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.role,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: kAppNavRailWidth,
      margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.glassSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: context.colors.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (role != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: role!.bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: role!.fgColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(role!.icon, size: 14, color: role!.fgColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      role!.label,
                      style: AppTextStyles.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: context.colors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (int i = 0; i < items.length; i++) ...[
            _RailItem(
              item: items[i],
              isActive: i == currentIndex,
              onTap: () => onTap(i),
            ),
            if (i != items.length - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends ConsumerWidget {
  final BottomNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _RailItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: context.colors.buttonGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isActive
                  ? context.colors.textOnPrimary
                  : context.colors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(ref, item.label),
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: isActive
                      ? context.colors.textOnPrimary
                      : context.colors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
