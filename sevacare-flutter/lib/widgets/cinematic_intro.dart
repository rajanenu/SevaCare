import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Cinematic app-launch intro (~6s), played once per launch as an overlay
/// above the router. Choreography on a single master controller:
///
///   1. Night backdrop, drifting depth particles (parallax)
///   2. A glowing ECG heartbeat line draws itself across the screen
///   3. The pulse blooms at center; the "S" logo mark flips in with 3D depth
///   4. Backdrop warms from night-indigo to the app's cream (dark → light,
///      the healing arc) while "SevaCare" reveals letter by letter in brand
///      indigo with a light sweep
///   5. Tagline fades in, then the whole scene push-zooms and cross-fades,
///      revealing whatever screen the router already resolved beneath it
///
/// Tap anywhere to fast-forward. Honors reduced-motion by finishing
/// immediately.
class CinematicIntro extends StatefulWidget {
  final VoidCallback onFinished;
  const CinematicIntro({super.key, required this.onFinished});

  @override
  State<CinematicIntro> createState() => _CinematicIntroState();
}

class _CinematicIntroState extends State<CinematicIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_IntroParticle> _far;
  late final List<_IntroParticle> _near;
  bool _finished = false;

  /// The intro is painted over the whole app, so if its animation never
  /// completes the app is simply invisible. Ticker-driven progress stalls
  /// whenever the engine stops producing frames — which is exactly what
  /// happens when Android cold-starts the process while it is still off
  /// screen. This wall-clock timer is independent of the ticker and dismisses
  /// the overlay no matter what the animation did.
  Timer? _failsafe;

  static const _letters = ['S', 'e', 'v', 'a', 'C', 'a', 'r', 'e'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
    _ctrl.forward();
    _failsafe = Timer(const Duration(seconds: 9), _finish);

    // Deterministic particle layout (seeded, same idiom as PremiumHeroAnimation)
    _far = List.generate(16, (i) => _IntroParticle.seeded(i * 131 + 7, small: true));
    _near = List.generate(10, (i) => _IntroParticle.seeded(i * 977 + 43, small: false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _failsafe?.cancel();
    widget.onFinished();
  }

  void _skip() {
    if (_ctrl.value < 0.88 && !_finished) {
      _ctrl.animateTo(1.0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  // Interval helper: progress of t through [a, b], shaped by [curve].
  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) {
    return curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  static const _nightColors = [Color(0xFF141233), Color(0xFF221D5C), Color(0xFF2E2880)];
  static const _dawnColors = SevaCareColors.screenGradient;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final bgT = _iv(t, 0.34, 0.58, Curves.easeInOut);
        final exitT = _iv(t, 0.90, 1.0, Curves.easeIn);

        final bg = List<Color>.generate(
          3,
          (i) => Color.lerp(_nightColors[i], _dawnColors[i], bgT)!,
        );

        // Material ancestor: the intro renders above the Navigator, so without
        // this every Text gets the yellow "missing Material" underline.
        return Material(
          type: MaterialType.transparency,
          child: Opacity(
            opacity: 1.0 - exitT,
            child: GestureDetector(
              onTap: _skip,
              behavior: HitTestBehavior.opaque,
              child: Transform.scale(
                scale: 1.0 + 0.05 * exitT,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: bg,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: _IntroScenePainter(
                            t: t,
                            bgT: bgT,
                            far: _far,
                            near: _near,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLogoMark(t),
                            const SizedBox(height: 22),
                            _buildWordmark(t),
                            const SizedBox(height: 16),
                            _buildTagline(t, bgT),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Logo mark: 3D perspective flip-in ───────────────────────────────────────

  Widget _buildLogoMark(double t) {
    final flipT = _iv(t, 0.30, 0.52, Curves.easeOutBack);
    final opacity = _iv(t, 0.30, 0.40);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: 0.55 + 0.45 * flipT,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateX((1.0 - flipT) * -1.1),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: SevaCareColors.buttonGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: SevaCareColors.primary.withValues(alpha: 0.45),
                  blurRadius: 34,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'S',
                style: AppTextStyles.display(
                  size: 42,
                  weight: FontWeight.w800,
                  color: SevaCareColors.textOnPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Wordmark: staggered letters + light sweep ───────────────────────────────

  Widget _buildWordmark(double t) {
    final shimT = _iv(t, 0.66, 0.82);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _letters.length; i++)
          _buildLetter(t, i),
      ],
    );

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-2.4 + 4.8 * shimT, -0.3),
        end: Alignment(-1.4 + 4.8 * shimT, 0.3),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.55),
          Colors.transparent,
        ],
      ).createShader(bounds),
      child: row,
    );
  }

  Widget _buildLetter(double t, int i) {
    final start = 0.48 + i * 0.022;
    final p = _iv(t, start, start + 0.10, Curves.easeOutCubic);

    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, (1.0 - p) * 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.2),
          child: Text(
            _letters[i],
            style: AppTextStyles.display(
              size: 36,
              weight: FontWeight.w800,
              color: SevaCareColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Tagline ─────────────────────────────────────────────────────────────────

  Widget _buildTagline(double t, double bgT) {
    final p = _iv(t, 0.72, 0.86, Curves.easeOut);
    // Muted-on-cream once the backdrop has warmed; soft white before that
    final color = Color.lerp(
      Colors.white.withValues(alpha: 0.75),
      SevaCareColors.textMuted,
      bgT,
    )!;

    // A bright glint sweeps left-to-right across the line once it's settled,
    // giving the tagline a "shine" moment before the scene exits. Widened from
    // 0.82-1.0 so the sweep takes longer and is readable, not a quick flash.
    final shineT = _iv(t, 0.68, 1.0, Curves.easeInOut);
    final sweep = -0.5 + shineT * 2.0;
    final stops = <double>[
      (sweep - 0.28).clamp(0.0, 1.0),
      (sweep - 0.12).clamp(0.0, 1.0),
      sweep.clamp(0.0, 1.0),
      (sweep + 0.12).clamp(0.0, 1.0),
      (sweep + 0.28).clamp(0.0, 1.0),
    ];

    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, (1.0 - p) * 10),
        child: ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [color, color, Colors.white, color, color],
            stops: stops,
          ).createShader(bounds),
          child: Text(
            'service — is right there in the name.',
            style: AppTextStyles.body(
              size: 15,
              weight: FontWeight.w600,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scene painter: particles, ECG trace, center bloom ─────────────────────────

class _IntroParticle {
  final double bx; // base x (0..1)
  final double by; // base y (0..1)
  final double radius;
  final double speed;
  final double phase;

  const _IntroParticle({
    required this.bx,
    required this.by,
    required this.radius,
    required this.speed,
    required this.phase,
  });

  factory _IntroParticle.seeded(int seed, {required bool small}) {
    final rng = math.Random(seed);
    return _IntroParticle(
      bx: 0.03 + rng.nextDouble() * 0.94,
      by: 0.05 + rng.nextDouble() * 0.90,
      radius: small ? 1.2 + rng.nextDouble() * 1.6 : 2.6 + rng.nextDouble() * 2.6,
      speed: 0.4 + rng.nextDouble() * 0.6,
      phase: rng.nextDouble() * math.pi * 2,
    );
  }
}

class _IntroScenePainter extends CustomPainter {
  final double t;
  final double bgT;
  final List<_IntroParticle> far;
  final List<_IntroParticle> near;

  _IntroScenePainter({
    required this.t,
    required this.bgT,
    required this.far,
    required this.near,
  });

  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) {
    return curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintParticles(canvas, size, far, layerAlpha: 0.35, drift: 0.05);
    _paintParticles(canvas, size, near, layerAlpha: 0.55, drift: 0.11);
    _paintBloom(canvas, size);
    _paintEcg(canvas, size);
  }

  void _paintParticles(Canvas canvas, Size size, List<_IntroParticle> layer,
      {required double layerAlpha, required double drift}) {
    // White sparks on the night backdrop, soft indigo motes once it warms
    final color = Color.lerp(
      Colors.white,
      SevaCareColors.primary,
      bgT,
    )!;

    for (final p in layer) {
      final dy = (p.by - t * p.speed * drift) % 1.0;
      final dx = p.bx + math.sin(t * math.pi * 2 * 0.5 + p.phase) * 0.012;
      final twinkle = 0.55 + 0.45 * math.sin(t * math.pi * 2 + p.phase);
      final alpha = layerAlpha * twinkle * lerpDouble(1.0, 0.45, bgT)!;

      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.radius,
        Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }
  }

  void _paintBloom(Canvas canvas, Size size) {
    final rise = _iv(t, 0.26, 0.42, Curves.easeOutCubic);
    final decay = 1.0 - _iv(t, 0.44, 0.62, Curves.easeIn);
    final alpha = rise * decay;
    if (alpha <= 0.01) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 30.0 + 130.0 * rise;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9F96F5).withValues(alpha: 0.55 * alpha),
            const Color(0xFF9F96F5).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _paintEcg(Canvas canvas, Size size) {
    final drawT = _iv(t, 0.02, 0.26, Curves.easeInOutCubic);
    final fade = 1.0 - _iv(t, 0.28, 0.40);
    if (drawT <= 0.001 || fade <= 0.01) return;

    final w = size.width;
    final cy = size.height / 2;

    // Classic ECG trace: baseline → P wave → QRS spike (centered) → T wave
    final path = Path()
      ..moveTo(0, cy)
      ..lineTo(w * 0.30, cy)
      ..quadraticBezierTo(w * 0.335, cy - 12, w * 0.37, cy)
      ..lineTo(w * 0.415, cy)
      ..lineTo(w * 0.435, cy + 14)
      ..lineTo(w * 0.465, cy - 74)
      ..lineTo(w * 0.495, cy + 26)
      ..lineTo(w * 0.515, cy)
      ..quadraticBezierTo(w * 0.575, cy - 18, w * 0.635, cy)
      ..lineTo(w, cy);

    final metric = path.computeMetrics().first;
    final visible = metric.extractPath(0, metric.length * drawT);

    // Outer glow pass
    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8F86F0).withValues(alpha: 0.35 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Bright core pass
    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFEDEBFF).withValues(alpha: fade),
    );

    // Glowing head dot at the draw position
    if (drawT < 1.0) {
      final head = metric.getTangentForOffset(metric.length * drawT)?.position;
      if (head != null) {
        canvas.drawCircle(
          head,
          13,
          Paint()
            ..color = const Color(0xFF8F86F0).withValues(alpha: 0.5 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawCircle(head, 4.5, Paint()..color = Colors.white.withValues(alpha: fade));
      }
    }
  }

  @override
  bool shouldRepaint(_IntroScenePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.bgT != bgT;
}
