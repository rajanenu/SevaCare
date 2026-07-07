import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/app_colors.dart';

/// Consistent app-wide snackbars. Replaces the many ad-hoc `SnackBar`s that
/// differed in colour, shape and position. Every message is floating, rounded,
/// carries a leading status icon and a matching accent, and gives light haptic
/// feedback so success/error feel distinct.
class AppSnack {
  const AppSnack._();

  static void success(BuildContext context, String message) =>
      _show(context, message, SevaCareColors.mint, Icons.check_circle_rounded,
          haptic: HapticFeedback.lightImpact);

  static void error(BuildContext context, String message) =>
      _show(context, message, SevaCareColors.danger, Icons.error_rounded,
          haptic: HapticFeedback.heavyImpact);

  static void info(BuildContext context, String message) =>
      _show(context, message, SevaCareColors.primary, Icons.info_rounded,
          haptic: HapticFeedback.selectionClick);

  static void _show(
    BuildContext context,
    String message,
    Color accent,
    IconData icon, {
    void Function()? haptic,
  }) {
    haptic?.call();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
