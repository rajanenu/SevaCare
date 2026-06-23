import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class OrbBackground extends StatelessWidget {
  final Widget child;
  const OrbBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base — theme-aware
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        // Indigo orb — top-left
        Positioned(
          top: -60,
          left: -80,
          child: _orb(200, SevaCareColors.primarySoft.withValues(alpha: 0.55)),
        ),
        // Mint orb — top-right
        Positioned(
          top: 80,
          right: -60,
          child: _orb(160, SevaCareColors.mintSoft.withValues(alpha: 0.50)),
        ),
        // Peach orb — bottom-right
        Positioned(
          bottom: 120,
          right: -40,
          child: _orb(130, SevaCareColors.peachSoft.withValues(alpha: 0.45)),
        ),
        child,
      ],
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      );
}
