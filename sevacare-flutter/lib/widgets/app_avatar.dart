import 'package:flutter/material.dart';
import '../core/theme/app_text_styles.dart';

class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final int hue; // 0-360 for doctor-style hue gradient
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.hue = 0,
    this.backgroundColor,
    this.foregroundColor,
  });

  // Derive a consistent hue from a string (name/id)
  static int hueFromString(String s) {
    if (s.isEmpty) return 0;
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) % 360;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? HSLColor.fromAHSL(1, hue.toDouble(), 0.6, 0.85).toColor();
    final fg = foregroundColor ?? HSLColor.fromAHSL(1, hue.toDouble(), 0.6, 0.30).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [bg, HSLColor.fromAHSL(1, (hue + 30) % 360, 0.55, 0.78).toColor()],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials.toUpperCase().substring(0, initials.length.clamp(0, 2)),
          style: AppTextStyles.body(
            size: size * 0.33,
            weight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// Role-based persona chip (shown in top bar)
class PersonaChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  const PersonaChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
