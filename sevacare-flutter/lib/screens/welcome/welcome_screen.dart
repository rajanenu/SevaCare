import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/widgets.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      hospitalName: 'SevaCare',
      // No role — public landing page
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: _HealthcarePattern()),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // ── Hero card ──────────────────────────────────────────────────
              _HeroCard(),
              const SizedBox(height: 24),
              // ── Section heading ────────────────────────────────────────────
              Text(
                'Quick Actions',
                style: AppTextStyles.sectionTitle(SevaCareColors.text),
              ),
              const SizedBox(height: 12),
              // ── Action card grid ───────────────────────────────────────────
              _ActionGrid(
                items: [
                  _ActionItem(
                    icon: Icons.search,
                    title: 'Search Hospitals',
                    onTap: () => context.go('/search'),
                    enabled: true,
                  ),
                  _ActionItem(
                    icon: Icons.add_business,
                    title: 'Onboard New Hospital',
                    onTap: () => context.go('/platform-login'),
                    enabled: true,
                  ),
                  _ActionItem(
                    icon: Icons.near_me,
                    title: 'Nearby',
                    subtitle: 'Coming Soon',
                    onTap: null,
                    enabled: false,
                  ),
                  _ActionItem(
                    icon: Icons.qr_code_scanner,
                    title: 'Scan QR Code',
                    subtitle: 'Coming Soon',
                    onTap: null,
                    enabled: false,
                  ),
                  _ActionItem(
                    icon: Icons.local_pharmacy_outlined,
                    title: 'Medicine Delivery',
                    subtitle: 'Coming Soon',
                    onTap: null,
                    enabled: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: SevaCareColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: [
          BoxShadow(
            color: SevaCareColors.primaryStrong.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative pill accent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Text(
              'HEALTHCARE SIMPLIFIED',
              style: AppTextStyles.labelCaps(
                SevaCareColors.textOnPrimary.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Smart Healthcare,\nSimplified.',
            style: AppTextStyles.heroTitle(SevaCareColors.textOnPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'Find & book appointments with top\ndoctors near you.',
            style: AppTextStyles.bodyText(
              SevaCareColors.textOnPrimary.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action grid ────────────────────────────────────────────────────────────────

class _ActionItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _ActionItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    required this.enabled,
  });
}

class _ActionGrid extends StatelessWidget {
  final List<_ActionItem> items;

  const _ActionGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) => _ActionCard(item: item)).toList(),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;

  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    // Each card takes ~half the width minus spacing
    final cardWidth = (MediaQuery.of(context).size.width - 32 - 12) / 2;

    final card = Container(
      width: cardWidth,
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.enabled ? SevaCareColors.surface : SevaCareColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: item.enabled ? SevaCareColors.border : SevaCareColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: item.enabled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.enabled ? SevaCareColors.primarySoft : SevaCareColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Center(
              child: Icon(
                item.icon,
                size: 22,
                color: item.enabled
                    ? SevaCareColors.primary
                    : SevaCareColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: AppTextStyles.cardTitle(
              item.enabled ? SevaCareColors.text : SevaCareColors.textMuted,
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: SevaCareColors.peachSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                item.subtitle!,
                style: AppTextStyles.labelCaps(SevaCareColors.peachForeground),
              ),
            ),
          ],
        ],
      ),
    );

    if (item.enabled && item.onTap != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            splashColor: SevaCareColors.primary.withValues(alpha: 0.08),
            highlightColor: SevaCareColors.primary.withValues(alpha: 0.04),
            child: card,
          ),
        ),
      );
    }

    // Disabled card — render as-is, no ink
    return Opacity(
      opacity: item.enabled ? 1.0 : 0.65,
      child: card,
    );
  }
}

// ── Healthcare background pattern ──────────────────────────────────────────────

class _HealthcarePattern extends StatelessWidget {
  const _HealthcarePattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: CustomPaint(
          painter: _PatternPainter(),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Large blurred circles — medical orb aesthetic
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.2), 90, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.7), 70, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 50, paint);

    // Subtle cross / plus signs (healthcare symbol)
    final crossPaint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    void drawCross(double cx, double cy, double sz) {
      final s = sz / 2;
      final t = sz / 6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: s * 2, height: t * 2),
          const Radius.circular(2),
        ),
        crossPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: t * 2, height: s * 2),
          const Radius.circular(2),
        ),
        crossPaint,
      );
    }

    drawCross(size.width * 0.15, size.height * 0.15, 24);
    drawCross(size.width * 0.75, size.height * 0.65, 18);
    drawCross(size.width * 0.9, size.height * 0.85, 14);
    drawCross(size.width * 0.35, size.height * 0.9, 20);
  }

  @override
  bool shouldRepaint(_PatternPainter old) => false;
}
