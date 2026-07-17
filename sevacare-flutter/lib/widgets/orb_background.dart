import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Full-screen ambient background — three soft pastel orbs that gently drift.
/// Wraps every AppShell body so all screens feel alive without distracting.
class OrbBackground extends StatefulWidget {
  final Widget child;
  const OrbBackground({super.key, required this.child});

  @override
  State<OrbBackground> createState() => _OrbBackgroundState();
}

class _OrbBackgroundState extends State<OrbBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => CustomPaint(
                painter: _OrbPainter(
                  t: _ctrl.value,
                  orb1: context.colors.primarySoft.withValues(alpha: 0.70),
                  orb2: context.colors.mintSoft.withValues(alpha: 0.65),
                  orb3: context.colors.peachSoft.withValues(alpha: 0.60),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final Color orb1;
  final Color orb2;
  final Color orb3;
  const _OrbPainter({
    required this.t,
    required this.orb1,
    required this.orb2,
    required this.orb3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _orb(
      canvas,
      20 + math.cos(t * math.pi * 0.7) * 18,
      40 + math.sin(t * math.pi) * 22,
      100,
      orb1,
    );
    _orb(
      canvas,
      size.width - 20 + math.sin(t * math.pi * 1.1) * 14,
      160 + math.cos(t * math.pi * 0.8) * 18,
      80,
      orb2,
    );
    _orb(
      canvas,
      size.width - 25 + math.cos(t * math.pi * 0.6) * 12,
      size.height - 185 + math.sin(t * math.pi * 0.9) * 20,
      65,
      orb3,
    );
  }

  void _orb(Canvas canvas, double cx, double cy, double r, Color color) {
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.orb1 != orb1 || old.orb2 != orb2 || old.orb3 != orb3;
}
