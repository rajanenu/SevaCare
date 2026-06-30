import 'dart:math' as math;
import 'package:flutter/material.dart';

/// World-class premium hero animation — 6-layer canvas system:
/// 1. Dot-grid texture (subtle depth like a medical chart)
/// 2. Mesh gradient (5 drifting colored orbs creating rich color depth)
/// 3. Hexagonal rings (cell/biology aesthetic, slowly rotating)
/// 4. Particle constellation network (24 nodes, medical-data metaphor)
/// 5. ECG heartbeat trace (draws itself left→right, loops)
/// 6. Glowing medical cross (top-right, softly pulsing)
class PremiumHeroAnimation extends StatefulWidget {
  const PremiumHeroAnimation({super.key});

  @override
  State<PremiumHeroAnimation> createState() => _PremiumHeroAnimationState();
}

class _PremiumHeroAnimationState extends State<PremiumHeroAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _meshCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _ekgCtrl;
  late final AnimationController _pulseCtrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _meshCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat();

    _ekgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    // Deterministic particle layout (seeded for consistency across rebuilds)
    _particles = List.generate(24, (i) {
      final rng = math.Random(i * 197 + 31);
      return _Particle(
        bx: 0.04 + rng.nextDouble() * 0.92,
        by: 0.04 + rng.nextDouble() * 0.88,
        phase: rng.nextDouble() * math.pi * 2,
        speedX: 0.30 + rng.nextDouble() * 0.70,
        speedY: 0.30 + rng.nextDouble() * 0.70,
        size: 1.2 + rng.nextDouble() * 2.0,
      );
    });
  }

  @override
  void dispose() {
    _meshCtrl.dispose();
    _particleCtrl.dispose();
    _ekgCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _meshCtrl,
            _particleCtrl,
            _ekgCtrl,
            _pulseCtrl,
          ]),
          builder: (_, _) => CustomPaint(
            painter: _PremiumPainter(
              meshT: _meshCtrl.value,
              particleT: _particleCtrl.value,
              ekgT: _ekgCtrl.value,
              pulseT: _pulseCtrl.value,
              particles: _particles,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data types ─────────────────────────────────────────────────────────────────

class _Particle {
  final double bx, by, phase, speedX, speedY, size;
  const _Particle({
    required this.bx,
    required this.by,
    required this.phase,
    required this.speedX,
    required this.speedY,
    required this.size,
  });
}

class _OrbDef {
  final double bx, by, rf;
  final Color color;
  const _OrbDef(this.bx, this.by, this.rf, this.color);
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _PremiumPainter extends CustomPainter {
  final double meshT, particleT, ekgT, pulseT;
  final List<_Particle> particles;

  const _PremiumPainter({
    required this.meshT,
    required this.particleT,
    required this.ekgT,
    required this.pulseT,
    required this.particles,
  });

  static const _orbDefs = [
    _OrbDef(0.10, 0.14, 0.55, Color(0xFF4338CA)),
    _OrbDef(0.92, 0.17, 0.46, Color(0xFF7C3AED)),
    _OrbDef(0.50, 0.90, 0.43, Color(0xFF0D9488)),
    _OrbDef(0.78, 0.56, 0.36, Color(0xFF1D4ED8)),
    _OrbDef(0.18, 0.72, 0.38, Color(0xFF059669)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _drawDotGrid(canvas, size);
    _drawMesh(canvas, size);
    _drawHexRings(canvas, size);
    _drawParticleNetwork(canvas, size);
    _drawEkg(canvas, size);
    _drawGlowCross(canvas, size);
  }

  // Layer 1 — very subtle dot-grid (medical-chart aesthetic)
  void _drawDotGrid(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.032);
    const step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.85, p);
      }
    }
  }

  // Layer 2 — 5 drifting colored blobs → rich mesh gradient
  void _drawMesh(Canvas canvas, Size size) {
    for (final o in _orbDefs) {
      final cx = (o.bx + math.sin(meshT * math.pi * (1.0 + o.bx * 0.3)) * 0.08) * size.width;
      final cy = (o.by + math.cos(meshT * math.pi * (1.1 + o.by * 0.25)) * 0.06) * size.height;
      final r = o.rf * size.width;
      final center = Offset(cx, cy);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [o.color.withValues(alpha: 0.24), o.color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromCircle(center: center, radius: r))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }
  }

  // Layer 3 — rotating hexagonal rings (cell/molecule structure)
  void _drawHexRings(Canvas canvas, Size size) {
    const rings = [
      (0.83, 0.22, 44.0, 1.0),
      (0.14, 0.62, 31.0, -1.4),
      (0.58, 0.78, 26.0, 0.9),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.09);

    for (final (bx, by, r, dir) in rings) {
      canvas.save();
      canvas.translate(bx * size.width, by * size.height);
      canvas.rotate(meshT * math.pi * 2 * dir * 0.12);
      _drawHex(canvas, r, paint);
      _drawHex(canvas, r * 0.58, paint);
      canvas.restore();
    }
  }

  void _drawHex(Canvas canvas, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = i / 6 * math.pi * 2 - math.pi / 2;
      final pt = Offset(r * math.cos(a), r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Layer 4 — 24-particle constellation (connected when within 90px)
  void _drawParticleNetwork(Canvas canvas, Size size) {
    final pts = particles.map((p) => Offset(
          (p.bx + math.sin(particleT * math.pi * 2 * p.speedX + p.phase) * 0.05) * size.width,
          (p.by + math.cos(particleT * math.pi * 2 * p.speedY + p.phase * 1.4) * 0.04) * size.height,
        )).toList();

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    const maxDist = 90.0;

    for (int i = 0; i < pts.length; i++) {
      for (int j = i + 1; j < pts.length; j++) {
        final dist = (pts[i] - pts[j]).distance;
        if (dist < maxDist) {
          linePaint.color = Colors.white.withValues(alpha: (1 - dist / maxDist) * 0.15);
          canvas.drawLine(pts[i], pts[j], linePaint);
        }
      }
    }

    for (int i = 0; i < pts.length; i++) {
      canvas.drawCircle(
        pts[i],
        particles[i].size + 2.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        pts[i],
        particles[i].size,
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }
  }

  // Layer 5 — authentic ECG heartbeat trace (draws itself, then loops)
  void _drawEkg(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF34D399).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final baseY = size.height * 0.86;
    final totalX = size.width * ekgT;
    const period = 108.0;

    final path = Path()..moveTo(0, baseY);
    double x = 0;
    while (x < totalX) {
      final ph = (x % period) / period;
      double y;
      if (ph < 0.28) {
        y = baseY;
      } else if (ph < 0.36) {
        y = baseY - 8 * math.sin((ph - 0.28) / 0.08 * math.pi);
      } else if (ph < 0.44) {
        y = baseY;
      } else if (ph < 0.475) {
        y = baseY - 44 * ((ph - 0.44) / 0.035);
      } else if (ph < 0.505) {
        y = baseY - 44 + 62 * ((ph - 0.475) / 0.03);
      } else if (ph < 0.535) {
        y = baseY + 18 * (1 - (ph - 0.505) / 0.03);
      } else if (ph < 0.65) {
        y = baseY - 13 * math.sin((ph - 0.535) / 0.115 * math.pi);
      } else {
        y = baseY;
      }
      path.lineTo(x.clamp(0, totalX), y);
      x += 1.5;
    }
    canvas.drawPath(path, paint);

    // Glowing dot at the leading edge
    if (ekgT > 0.01 && ekgT < 0.99) {
      canvas.drawCircle(
        Offset(totalX, baseY),
        5.5,
        Paint()
          ..color = const Color(0xFF34D399).withValues(alpha: 0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(totalX, baseY),
        2.5,
        Paint()..color = const Color(0xFF34D399),
      );
    }
  }

  // Layer 6 — medical cross with soft glow, top-right
  void _drawGlowCross(Canvas canvas, Size size) {
    final cx = size.width * 0.87;
    final cy = size.height * 0.19;
    final sz = 19.0 + pulseT * 4.5;
    final alpha = 0.11 + pulseT * 0.10;

    canvas.drawCircle(
      Offset(cx, cy),
      sz + 10,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    final cp = Paint()..color = Colors.white.withValues(alpha: alpha + 0.05);
    final t = sz / 3.6;
    final h = sz * 0.92;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: h * 2, height: t * 2),
        const Radius.circular(3),
      ),
      cp,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: t * 2, height: h * 2),
        const Radius.circular(3),
      ),
      cp,
    );
  }

  @override
  bool shouldRepaint(_PremiumPainter old) =>
      old.meshT != meshT ||
      old.particleT != particleT ||
      old.ekgT != ekgT ||
      old.pulseT != pulseT;
}
