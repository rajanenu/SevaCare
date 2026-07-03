import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'gradient_button.dart';

/// Shows a standard confirmation dialog and returns true only if the user
/// explicitly confirms. Used before destructive or important actions
/// (delete/add) so a mis-tap doesn't immediately trigger them.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDanger = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SevaCareColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppTextStyles.sectionTitle(SevaCareColors.text)),
      content: Text(message, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
      actions: [
        SecondaryButton(label: cancelLabel, onPressed: () => Navigator.of(ctx).pop(false)),
        const SizedBox(width: 8),
        isDanger
            ? DangerButton(label: confirmLabel, onPressed: () => Navigator.of(ctx).pop(true))
            : PrimaryButton(label: confirmLabel, onPressed: () => Navigator.of(ctx).pop(true)),
      ],
    ),
  );
  return confirmed == true;
}
