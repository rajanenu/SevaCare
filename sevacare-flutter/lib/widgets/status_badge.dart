import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// WCAG-accessible status badge: pairs color WITH an icon AND a text label
/// so colorblind users are never relying on color alone.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = _resolve(status.toLowerCase());
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
            Text(label.toUpperCase(), style: AppTextStyles.badgeText(fg)),
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData, String) _resolve(String s) => switch (s) {
        'active' => (
          SevaCareColors.mintSoft,
          SevaCareColors.mintForeground,
          Icons.check_circle_outline_rounded,
          'Active'
        ),
        'inactive' || 'disabled' => (
          SevaCareColors.surfaceMuted,
          SevaCareColors.textMuted,
          Icons.cancel_outlined,
          'Inactive'
        ),
        'upcoming' => (
          SevaCareColors.primarySoft,
          SevaCareColors.primary,
          Icons.schedule_rounded,
          'Upcoming'
        ),
        'completed' => (
          SevaCareColors.mintSoft,
          SevaCareColors.mintForeground,
          Icons.task_alt_rounded,
          'Completed'
        ),
        'past' => (
          SevaCareColors.surfaceMuted,
          SevaCareColors.textMuted,
          Icons.history_rounded,
          'Past'
        ),
        'cancelled' || 'canceled' => (
          SevaCareColors.errorSurface,
          SevaCareColors.danger,
          Icons.block_rounded,
          'Cancelled'
        ),
        'pending' => (
          SevaCareColors.warningSurface,
          SevaCareColors.warning,
          Icons.hourglass_empty_rounded,
          'Pending'
        ),
        'approved' => (
          SevaCareColors.mintSoft,
          SevaCareColors.mintForeground,
          Icons.verified_rounded,
          'Approved'
        ),
        'declined' => (
          SevaCareColors.errorSurface,
          SevaCareColors.danger,
          Icons.thumb_down_outlined,
          'Declined'
        ),
        'auto_approved' => (
          SevaCareColors.mintSoft,
          SevaCareColors.mintForeground,
          Icons.auto_awesome_rounded,
          'Auto-Approved'
        ),
        _ => (
          SevaCareColors.surfaceMuted,
          SevaCareColors.textMuted,
          Icons.info_outline_rounded,
          s
        ),
      };
}
