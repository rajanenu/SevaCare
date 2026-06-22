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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // ── Hero card ────────────────────────────────────────────────────────
          _HeroCard(),
          const SizedBox(height: 24),
          // ── Section heading ──────────────────────────────────────────────────
          Text(
            'Quick Actions',
            style: AppTextStyles.sectionTitle(SevaCareColors.text),
          ),
          const SizedBox(height: 12),
          // ── Action card grid ─────────────────────────────────────────────────
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
                title: 'Onboard Your Hospital',
                onTap: () => context.go('/onboarding'),
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
                icon: Icons.bookmark_border,
                title: 'Saved Hospitals',
                subtitle: 'Coming Soon',
                onTap: null,
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 20),
          // CTA row
          Row(
            children: [
              _HeroCta(
                label: 'Find Hospitals',
                onTap: () => context.go('/search'),
              ),
              const SizedBox(width: 12),
              // Decorative stat pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_hospital_outlined,
                      size: 14,
                      color: SevaCareColors.textOnPrimary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Trusted Care',
                      style: AppTextStyles.label(
                        SevaCareColors.textOnPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _HeroCta({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.go('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: SevaCareColors.textOnPrimary,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: AppTextStyles.label(SevaCareColors.primary),
        ),
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
      constraints: const BoxConstraints(minHeight: 100),
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
