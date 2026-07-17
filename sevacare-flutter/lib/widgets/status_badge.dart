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
    final (bg, fg, icon, label) = _resolve(context, status.toLowerCase());
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

  (Color, Color, IconData, String) _resolve(BuildContext context, String s) => switch (s) {
        'active' => (
          context.colors.mintSoft,
          context.colors.mintForeground,
          Icons.check_circle_outline_rounded,
          'Active'
        ),
        'inactive' || 'disabled' => (
          context.colors.surfaceMuted,
          context.colors.textMuted,
          Icons.cancel_outlined,
          'Inactive'
        ),
        'upcoming' => (
          context.colors.primarySoft,
          context.colors.primary,
          Icons.schedule_rounded,
          'Upcoming'
        ),
        'completed' => (
          context.colors.mintSoft,
          context.colors.mintForeground,
          Icons.task_alt_rounded,
          'Completed'
        ),
        'past' => (
          context.colors.surfaceMuted,
          context.colors.textMuted,
          Icons.history_rounded,
          'Past'
        ),
        'cancelled' || 'canceled' => (
          context.colors.errorSurface,
          context.colors.danger,
          Icons.block_rounded,
          'Cancelled'
        ),
        'pending' => (
          context.colors.warningSurface,
          context.colors.warning,
          Icons.hourglass_empty_rounded,
          'Pending'
        ),
        'approved' => (
          context.colors.mintSoft,
          context.colors.mintForeground,
          Icons.verified_rounded,
          'Approved'
        ),
        'declined' => (
          context.colors.errorSurface,
          context.colors.danger,
          Icons.thumb_down_outlined,
          'Declined'
        ),
        'auto_approved' => (
          context.colors.mintSoft,
          context.colors.mintForeground,
          Icons.auto_awesome_rounded,
          'Auto-Approved'
        ),
        _ => (
          context.colors.surfaceMuted,
          context.colors.textMuted,
          Icons.info_outline_rounded,
          s
        ),
      };
}
