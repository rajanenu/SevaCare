import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/widgets.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      hospitalName: 'SevaCare',
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero ──────────────────────────────────────────────────────
              const _HeroCard(),
              const SizedBox(height: 28),

              // ── Primary actions ────────────────────────────────────────────
              StaggeredItem(
                index: 0,
                baseDelay: const Duration(milliseconds: 80),
                child: Text('Quick Actions',
                    style: AppTextStyles.sectionTitle(SevaCareColors.text)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StaggeredItem(
                      index: 1,
                      baseDelay: const Duration(milliseconds: 80),
                      child: _PrimaryCard(
                        icon: Icons.search_rounded,
                        label: 'Search Hospitals',
                        description: 'Find & book nearby',
                        gradient: const LinearGradient(
                          colors: SevaCareColors.buttonGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => context.go('/search'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StaggeredItem(
                      index: 2,
                      baseDelay: const Duration(milliseconds: 80),
                      child: _PrimaryCard(
                        icon: Icons.add_business_rounded,
                        label: 'Onboard Hospital',
                        description: 'Register your clinic',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => context.go('/platform-login'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Coming soon ────────────────────────────────────────────────
              StaggeredItem(
                index: 3,
                baseDelay: const Duration(milliseconds: 80),
                child: Row(
                  children: [
                    Text('Coming Soon',
                        style: AppTextStyles.sectionTitle(
                            SevaCareColors.textMuted)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: SevaCareColors.peachSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('SOON',
                          style: AppTextStyles.labelCaps(
                              SevaCareColors.peachForeground)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StaggeredItem(
                index: 4,
                baseDelay: const Duration(milliseconds: 80),
                child: Row(
                  children: [
                    Expanded(
                        child: _ComingSoonCard(
                            icon: Icons.near_me_rounded, label: 'Nearby')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ComingSoonCard(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scan QR')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ComingSoonCard(
                            icon: Icons.local_pharmacy_outlined,
                            label: 'Pharmacy')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius + 2),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: SevaCareColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // ── Premium 6-layer animation ──────────────────────────────────
            const Positioned.fill(
              child: ClipRect(
                child: PremiumHeroAnimation(),
              ),
            ),
            // ── Depth scrim — subtle dark gradient at bottom edge ──────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.14),
                    ],
                    stops: const [0.0, 0.60, 1.0],
                  ),
                ),
              ),
            ),
            // ── Content ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF4ADE80).withValues(alpha: 0.7),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'SEVACARE',
                          style: AppTextStyles.labelCaps(
                              Colors.white.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Headline
                  Text(
                    'Smart Healthcare,\nSimplified.',
                    style: AppTextStyles.heroTitle(Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Book, consult & heal — in one app.',
                    style: AppTextStyles.bodyText(
                        Colors.white.withValues(alpha: 0.78)),
                  ),
                  const SizedBox(height: 22),
                  // Trust stats row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: const [
                      _StatPill(
                          icon: Icons.local_hospital_rounded,
                          label: '2 Hospitals'),
                      _StatPill(
                          icon: Icons.people_rounded, label: '6+ Doctors'),
                      _StatPill(
                          icon: Icons.bolt_rounded, label: 'Live Queue'),
                    ],
                  ),
                  // Bottom space — EKG trace animates here
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.88)),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelCaps(
                  Colors.white.withValues(alpha: 0.92))),
        ],
      ),
    );
  }
}

// ── Primary Action Card (with press-scale animation) ───────────────────────────

class _PrimaryCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final Gradient gradient;
  final VoidCallback onTap;

  const _PrimaryCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_PrimaryCard> createState() => _PrimaryCardState();
}

class _PrimaryCardState extends State<_PrimaryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = (widget.gradient as LinearGradient).colors.first;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: SevaCareColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: SevaCareColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: iconColor.withValues(alpha: _pressed ? 0.12 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.38),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                widget.label,
                style: AppTextStyles.cardTitle(SevaCareColors.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                widget.description,
                style: AppTextStyles.label(SevaCareColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Open',
                    style: AppTextStyles.label(iconColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: iconColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Coming Soon Card ───────────────────────────────────────────────────────────

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComingSoonCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: SevaCareColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
            color: SevaCareColors.border.withValues(alpha: 0.6), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 22,
              color: SevaCareColors.textMuted.withValues(alpha: 0.50)),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.label(SevaCareColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
