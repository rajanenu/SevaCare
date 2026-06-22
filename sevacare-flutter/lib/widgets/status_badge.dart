import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _resolve(status.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        '+ ${label.toUpperCase()}',
        style: AppTextStyles.badgeText(fg),
      ),
    );
  }

  (Color, Color, String) _resolve(String s) => switch (s) {
    'active' => (SevaCareColors.mintSoft, SevaCareColors.mintForeground, 'Active'),
    'inactive' || 'disabled' => (SevaCareColors.surfaceMuted, SevaCareColors.textMuted, 'Inactive'),
    'upcoming' => (SevaCareColors.primarySoft, SevaCareColors.primary, 'Upcoming'),
    'completed' || 'past' => (SevaCareColors.mintSoft, SevaCareColors.mintForeground, s == 'completed' ? 'Completed' : 'Past'),
    'cancelled' || 'canceled' => (SevaCareColors.errorSurface, SevaCareColors.danger, 'Cancelled'),
    'pending' => (SevaCareColors.warningSurface, SevaCareColors.warning, 'Pending'),
    'approved' => (SevaCareColors.mintSoft, SevaCareColors.mintForeground, 'Approved'),
    _ => (SevaCareColors.surfaceMuted, SevaCareColors.textMuted, s),
  };
}
