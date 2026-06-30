import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated healthcare background — plays smooth floating orbs + medical
/// symbols. Use [variant] to pick a role-themed palette.
enum HealthcareBgVariant { welcome, doctor, patient, admin }

class AnimatedHealthcareBg extends StatefulWidget {
  final HealthcareBgVariant variant;
  final double height;

  const AnimatedHealthcareBg({
    super.key,
    this.variant = HealthcareBgVariant.welcome,
    this.height = 300,
  });

  @override
  State<AnimatedHealthcareBg> createState() => _AnimatedHealthcareBgState();
}

class _AnimatedHealthcareBgState extends State<AnimatedHealthcareBg>
    with TickerProviderStateMixin {
  late final AnimationController _orbCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _ekgCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _ekgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    _ekgCtrl.dispose();
    super.dispose();
  }

  _BgConfig get _config => _BgConfig.forVariant(widget.variant);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: AnimatedBuilder(
          animation: Listenable.merge([_orbCtrl, _pulseCtrl, _ekgCtrl]),
          builder: (_, child) => CustomPaint(
            painter: _HealthcareBgPainter(
              orbT: _orbCtrl.value,
              pulseT: _pulseCtrl.value,
              ekgT: _ekgCtrl.value,
              config: _config,
              variant: widget.variant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Configuration per role ─────────────────────────────────────────────────────

class _BgConfig {
  final List<Color> orbColors;
  final Color symbolColor;
  final Color waveColor;

  const _BgConfig({
    required this.orbColors,
    required this.symbolColor,
    required this.waveColor,
  });

  static _BgConfig forVariant(HealthcareBgVariant v) => switch (v) {
        HealthcareBgVariant.welcome => _BgConfig(
            orbColors: [
              const Color(0xFF6366F1).withValues(alpha: 0.12),
              const Color(0xFF52C499).withValues(alpha: 0.10),
              const Color(0xFFF0A86B).withValues(alpha: 0.08),
            ],
            symbolColor: const Color(0xFF6366F1).withValues(alpha: 0.10),
            waveColor: const Color(0xFF6366F1).withValues(alpha: 0.05),
          ),
        HealthcareBgVariant.doctor => _BgConfig(
            orbColors: [
              const Color(0xFF3F39A8).withValues(alpha: 0.13),
              const Color(0xFF52C499).withValues(alpha: 0.09),
              const Color(0xFF7C6FE0).withValues(alpha: 0.10),
            ],
            symbolColor: const Color(0xFF5148CC).withValues(alpha: 0.12),
            waveColor: const Color(0xFF52C499).withValues(alpha: 0.06),
          ),
        HealthcareBgVariant.patient => _BgConfig(
            orbColors: [
              const Color(0xFF52C499).withValues(alpha: 0.13),
              const Color(0xFF6366F1).withValues(alpha: 0.08),
              const Color(0xFFF0A86B).withValues(alpha: 0.10),
            ],
            symbolColor: const Color(0xFF52C499).withValues(alpha: 0.11),
            waveColor: const Color(0xFF52C499).withValues(alpha: 0.05),
          ),
        HealthcareBgVariant.admin => _BgConfig(
            orbColors: [
              const Color(0xFF5148CC).withValues(alpha: 0.10),
              const Color(0xFFF0A86B).withValues(alpha: 0.10),
              const Color(0xFF3F39A8).withValues(alpha: 0.08),
            ],
            symbolColor: const Color(0xFFF0A86B).withValues(alpha: 0.12),
            waveColor: const Color(0xFF5148CC).withValues(alpha: 0.04),
          ),
      };
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _HealthcareBgPainter extends CustomPainter {
  final double orbT;   // 0..1 looping, reversed
  final double pulseT; // 0..1 looping
  final double ekgT;   // 0..1 looping
  final _BgConfig config;
  final HealthcareBgVariant variant;

  const _HealthcareBgPainter({
    required this.orbT,
    required this.pulseT,
    required this.ekgT,
    required this.config,
    required this.variant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawWaves(canvas, size);
    _drawOrbs(canvas, size);
    _drawMedicalSymbols(canvas, size);
    if (variant == HealthcareBgVariant.doctor) {
      _drawEkgLine(canvas, size);
    }
    if (variant == HealthcareBgVariant.patient) {
      _drawHeartbeatDots(canvas, size);
    }
    if (variant == HealthcareBgVariant.admin) {
      _drawNetworkNodes(canvas, size);
    }
  }

  void _drawWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = config.waveColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final shift = orbT * math.pi * 2;

    path.moveTo(0, h * 0.55);
    for (double x = 0; x <= w; x++) {
      final y = h * 0.55 +
          math.sin((x / w) * math.pi * 3 + shift) * h * 0.04 +
          math.cos((x / w) * math.pi * 2 - shift * 0.6) * h * 0.02;
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawOrbs(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Three animated orbs — positions drift with orbT
    final orbs = [
      (
        cx: w * 0.82 + math.sin(orbT * math.pi * 2) * w * 0.04,
        cy: h * 0.20 + math.cos(orbT * math.pi * 2) * h * 0.03,
        r: 80.0 + math.sin(pulseT * math.pi * 2) * 8,
        color: config.orbColors[0],
      ),
      (
        cx: w * 0.12 + math.cos(orbT * math.pi * 2) * w * 0.03,
        cy: h * 0.65 + math.sin(orbT * math.pi * 2) * h * 0.04,
        r: 64.0 + math.cos(pulseT * math.pi * 2) * 6,
        color: config.orbColors[1],
      ),
      (
        cx: w * 0.50 + math.sin(orbT * math.pi * 2 + 1.0) * w * 0.05,
        cy: h * 0.42 + math.cos(orbT * math.pi * 2 + 0.5) * h * 0.04,
        r: 48.0 + math.sin(pulseT * math.pi * 2 + 0.8) * 5,
        color: config.orbColors[2],
      ),
    ];

    for (final orb in orbs) {
      final paint = Paint()
        ..color = orb.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(Offset(orb.cx, orb.cy), orb.r, paint);
    }
  }

  void _drawMedicalSymbols(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = config.symbolColor
      ..style = PaintingStyle.fill;

    void drawPlus(double cx, double cy, double sz) {
      final s = sz / 2;
      final t = sz / 5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: s * 2, height: t * 2),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: t * 2, height: s * 2),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    // Floating crosses that breathe slightly with pulseT
    final scale = 1.0 + math.sin(pulseT * math.pi * 2) * 0.08;
    drawPlus(size.width * 0.14, size.height * 0.18, 22 * scale);
    drawPlus(size.width * 0.76, size.height * 0.72, 16 * scale);
    drawPlus(size.width * 0.91, size.height * 0.32, 13 * scale);
    drawPlus(size.width * 0.38, size.height * 0.88, 18 * scale);
    drawPlus(size.width * 0.62, size.height * 0.14, 11 * scale);

    // Small circles (pill shapes)
    final circlePaint = Paint()
      ..color = config.symbolColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.45), 6, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.22), 4, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.55), 5, circlePaint);
  }

  void _drawEkgLine(Canvas canvas, Size size) {
    // Animated EKG / heartbeat trace
    final paint = Paint()
      ..color = const Color(0xFF52C499).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final progress = ekgT; // 0..1
    final w = size.width;
    final baseY = size.height * 0.75;

    final path = Path();
    final totalPoints = (w * progress).clamp(0, w).toDouble();

    double x = 0;
    path.moveTo(x, baseY);

    // EKG segments: flat → small bump → flat → spike → flat
    final period = w * 0.35;

    while (x < totalPoints) {
      final phase = (x % period) / period; // 0..1 within one beat
      double y;
      if (phase < 0.30) {
        y = baseY; // flat
      } else if (phase < 0.38) {
        // small P wave
        y = baseY - 8 * math.sin((phase - 0.30) / 0.08 * math.pi);
      } else if (phase < 0.45) {
        y = baseY; // flat
      } else if (phase < 0.48) {
        // QRS spike up
        y = baseY - 40 * ((phase - 0.45) / 0.03);
      } else if (phase < 0.50) {
        // QRS spike down
        y = baseY - 40 + 60 * ((phase - 0.48) / 0.02);
      } else if (phase < 0.53) {
        // S wave back to baseline
        y = baseY + 20 * (1 - (phase - 0.50) / 0.03);
      } else if (phase < 0.65) {
        // T wave
        y = baseY - 14 * math.sin((phase - 0.53) / 0.12 * math.pi);
      } else {
        y = baseY; // flat
      }
      path.lineTo(x, y);
      x += 2;
    }

    canvas.drawPath(path, paint);

    // Glowing dot at the leading edge
    if (totalPoints > 0 && totalPoints < w) {
      final glowPaint = Paint()
        ..color = const Color(0xFF52C499).withValues(alpha: 0.60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(totalPoints, baseY - 10), 5, glowPaint);
    }
  }

  void _drawHeartbeatDots(Canvas canvas, Size size) {
    // Expanding ripple rings — patient care pulse effect
    for (int i = 0; i < 3; i++) {
      final t = (pulseT + i / 3.0) % 1.0;
      final radius = t * 50.0;
      final alpha = (1.0 - t) * 0.18;
      final paint = Paint()
        ..color = const Color(0xFF52C499).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.15),
        radius,
        paint,
      );
    }
    // Heart icon (simple path)
    _drawHeart(canvas, size.width * 0.88, size.height * 0.15, 10,
        const Color(0xFF52C499).withValues(alpha: 0.25));
  }

  void _drawHeart(Canvas canvas, double cx, double cy, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(cx, cy + r * 0.3);
    path.cubicTo(cx - r * 1.2, cy - r * 0.4, cx - r * 2, cy + r * 0.6, cx, cy + r * 1.8);
    path.cubicTo(cx + r * 2, cy + r * 0.6, cx + r * 1.2, cy - r * 0.4, cx, cy + r * 0.3);
    canvas.drawPath(path, paint);
  }

  void _drawNetworkNodes(Canvas canvas, Size size) {
    // Admin: animated network/org chart — nodes and connecting lines
    final nodePaint = Paint()
      ..color = const Color(0xFFF0A86B).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFFF0A86B).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final nodes = [
      Offset(size.width * 0.50, size.height * 0.20), // root
      Offset(size.width * 0.25, size.height * 0.55),
      Offset(size.width * 0.75, size.height * 0.55),
      Offset(size.width * 0.12, size.height * 0.82),
      Offset(size.width * 0.38, size.height * 0.82),
      Offset(size.width * 0.62, size.height * 0.82),
      Offset(size.width * 0.88, size.height * 0.82),
    ];

    final edges = [
      (0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6),
    ];

    // Animated dash offset for flowing connection lines
    final dashOffset = ekgT * 20;
    for (final edge in edges) {
      final p1 = nodes[edge.$1];
      final p2 = nodes[edge.$2];
      _drawDashedLine(canvas, p1, p2, linePaint, dashOffset);
    }

    // Pulsing nodes
    for (int i = 0; i < nodes.length; i++) {
      final pulse = (pulseT + i * 0.14) % 1.0;
      final r = 7.0 + math.sin(pulse * math.pi * 2) * 2;
      canvas.drawCircle(nodes[i], r, nodePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double offset) {
    const dashLen = 8.0;
    const gapLen = 6.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final ux = dx / dist;
    final uy = dy / dist;
    double d = offset % (dashLen + gapLen);
    while (d < dist) {
      final start = d;
      final end = (d + dashLen).clamp(0, dist).toDouble();
      canvas.drawLine(
        Offset(p1.dx + ux * start, p1.dy + uy * start),
        Offset(p1.dx + ux * end, p1.dy + uy * end),
        paint,
      );
      d += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_HealthcareBgPainter old) =>
      old.orbT != orbT || old.pulseT != pulseT || old.ekgT != ekgT;
}
