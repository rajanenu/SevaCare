import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// Shows a full-screen celebration overlay when an appointment is booked.
/// Plays: animated ring draw → checkmark reveal → confetti burst.
/// Novel for healthcare apps — makes the most important patient action memorable.
Future<void> showBookingSuccessOverlay(
  BuildContext context, {
  required String doctorName,
  required String displaySlot,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.60),
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, _) => _SuccessOverlay(
      doctorName: doctorName,
      displaySlot: displaySlot,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SuccessOverlay extends StatefulWidget {
  final String doctorName;
  final String displaySlot;

  const _SuccessOverlay({required this.doctorName, required this.displaySlot});

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _circleCtrl;
  late final AnimationController _confettiCtrl;
  late final List<_Confetti> _confettiList;

  @override
  void initState() {
    super.initState();

    _circleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _circleCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _confettiCtrl.forward();
    });

    final rng = math.Random(73);
    _confettiList = List.generate(64, (i) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 70.0 + rng.nextDouble() * 130;
      return _Confetti(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed - 50,
        color: _kColors[i % _kColors.length],
        size: 4.0 + rng.nextDouble() * 5,
        rotation: rng.nextDouble() * math.pi * 2,
        spin: (rng.nextDouble() - 0.5) * 9,
      );
    });
  }

  static const _kColors = [
    Color(0xFF5148CC), Color(0xFF52C499), Color(0xFFF0A86B),
    Color(0xFF818CF8), Color(0xFF34D399), Color(0xFFFBBF24),
    Color(0xFFF87171), Color(0xFF60A5FA), Color(0xFFEC4899),
  ];

  @override
  void dispose() {
    _circleCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: GestureDetector(
          onTap: () {}, // prevent tap-through on content
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated ring + checkmark + confetti ──────────────
                SizedBox(
                  width: 148,
                  height: 148,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_circleCtrl, _confettiCtrl]),
                    builder: (_, _) => CustomPaint(
                      painter: _CelebrationPainter(
                        circleT: _circleCtrl.value,
                        confettiT: _confettiCtrl.value,
                        particles: _confettiList,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // ── Details card ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: SevaCareColors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radius + 4),
                    boxShadow: [
                      BoxShadow(
                        color: SevaCareColors.primary.withValues(alpha: 0.18),
                        blurRadius: 36,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Appointment Confirmed!',
                        style: AppTextStyles.sectionTitle(SevaCareColors.text),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.doctorName.isNotEmpty
                            ? 'with Dr. ${widget.doctorName}'
                            : 'Your appointment is booked',
                        style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.displaySlot.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEEEEFF), Color(0xFFE8F8F3)],
                            ),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(
                                color: SevaCareColors.primary
                                    .withValues(alpha: 0.20)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 14, color: SevaCareColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                widget.displaySlot,
                                style: AppTextStyles.chipLabel(
                                    SevaCareColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _GoBtn(onTap: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Done button with spring press ─────────────────────────────────────────────

class _GoBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _GoBtn({required this.onTap});

  @override
  State<_GoBtn> createState() => _GoBtnState();
}

class _GoBtnState extends State<_GoBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
        scale: _p ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: SevaCareColors.buttonGradient,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: [
              BoxShadow(
                color: SevaCareColors.primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Go to Dashboard',
            style: AppTextStyles.body(
              size: 15,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ── Canvas celebration painter ─────────────────────────────────────────────────

class _Confetti {
  final double dx, dy, size, rotation, spin;
  final Color color;
  const _Confetti({
    required this.dx,
    required this.dy,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.color,
  });
}

class _CelebrationPainter extends CustomPainter {
  final double circleT;
  final double confettiT;
  final List<_Confetti> particles;

  const _CelebrationPainter({
    required this.circleT,
    required this.confettiT,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 10;

    // Soft glow
    if (circleT > 0.4) {
      final a = ((circleT - 0.4) / 0.6).clamp(0.0, 1.0) * 0.18;
      canvas.drawCircle(
        Offset(cx, cy),
        r + 14,
        Paint()
          ..color = SevaCareColors.mint.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }

    // Ring arc draws in
    final ringProgress = (circleT * 1.4).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      ringProgress * math.pi * 2,
      false,
      Paint()
        ..color = SevaCareColors.mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // Filled center circle fades in
    if (circleT > 0.5) {
      final fillA = ((circleT - 0.5) / 0.5).clamp(0.0, 1.0) * 0.08;
      canvas.drawCircle(
        Offset(cx, cy),
        r - 4,
        Paint()..color = SevaCareColors.mint.withValues(alpha: fillA),
      );
    }

    // Checkmark draws in after ring reaches 60%
    if (circleT > 0.55) {
      final ck = ((circleT - 0.55) / 0.45).clamp(0.0, 1.0);
      _drawCheck(canvas, cx, cy, r * 0.50, ck);
    }

    // Confetti burst
    if (confettiT > 0) {
      _drawConfetti(canvas, cx, cy);
    }
  }

  void _drawCheck(Canvas canvas, double cx, double cy, double r, double t) {
    final p = Paint()
      ..color = SevaCareColors.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final a = Offset(cx - r * 0.55, cy + r * 0.05);
    final b = Offset(cx - r * 0.05, cy + r * 0.55);
    final c = Offset(cx + r * 0.65, cy - r * 0.55);

    if (t < 0.45) {
      final s = t / 0.45;
      canvas.drawLine(a, Offset.lerp(a, b, s)!, p);
    } else {
      canvas.drawLine(a, b, p);
      final s = (t - 0.45) / 0.55;
      canvas.drawLine(b, Offset.lerp(b, c, s)!, p);
    }
  }

  void _drawConfetti(Canvas canvas, double cx, double cy) {
    const g = 220.0;
    for (final p in particles) {
      final t = confettiT;
      final x = cx + p.dx * t;
      final y = cy + p.dy * t + 0.5 * g * t * t;
      final alpha = (1.0 - t * 0.75).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.45),
          const Radius.circular(1),
        ),
        Paint()..color = p.color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) =>
      old.circleT != circleT || old.confettiT != confettiT;
}
