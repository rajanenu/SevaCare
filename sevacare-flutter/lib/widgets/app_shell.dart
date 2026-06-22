import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import 'app_avatar.dart';
import 'bottom_nav.dart';
import 'orb_background.dart';

class AppShell extends StatelessWidget {
  final Widget body;
  final String hospitalName;
  final UserRole? role;
  final List<BottomNavItem>? bottomNavItems;
  final int? currentNavIndex;
  final ValueChanged<int>? onNavTap;
  final List<Widget>? headerActions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool compactScroll;

  const AppShell({
    super.key,
    required this.body,
    this.hospitalName = 'SevaCare',
    this.role,
    this.bottomNavItems,
    this.currentNavIndex,
    this.onNavTap,
    this.headerActions,
    this.showBackButton = false,
    this.onBack,
    this.compactScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasBottomNav = bottomNavItems != null && bottomNavItems!.isNotEmpty;

    return Scaffold(
      backgroundColor: SevaCareColors.background,
      body: OrbBackground(
        child: Column(
          children: [
            // ── Glass top bar ─────────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: _TopBar(
                hospitalName: hospitalName,
                role: role,
                actions: headerActions,
              ),
            ),
            // ── Scrollable content ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    hasBottomNav ? 8 : 32,
                  ),
                  child: body,
                ),
              ),
            ),
            // ── Bottom nav ───────────────────────────────────────────────────
            if (hasBottomNav)
              SafeArea(
                top: false,
                child: AppBottomNav(
                  items: bottomNavItems!,
                  currentIndex: currentNavIndex ?? 0,
                  onTap: onNavTap ?? (_) {},
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String hospitalName;
  final UserRole? role;
  final List<Widget>? actions;

  const _TopBar({
    required this.hospitalName,
    this.role,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: SevaCareColors.glassSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: SevaCareColors.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SevaCareColors.shadowColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // "S" gradient logomark
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: SevaCareColors.buttonGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: SevaCareColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'S',
                style: AppTextStyles.display(
                  size: 16,
                  weight: FontWeight.w800,
                  color: SevaCareColors.textOnPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Hospital name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospitalName,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: SevaCareColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Healthcare Platform',
                  style: AppTextStyles.body(
                    size: 10,
                    color: SevaCareColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Role persona chip / header actions
          if (actions != null && actions!.isNotEmpty)
            ...actions!
          else if (role != null)
            PersonaChip(
              label: role!.label,
              backgroundColor: _roleBg(role!),
              foregroundColor: _roleFg(role!),
              icon: _roleIcon(role!),
            ),
        ],
      ),
    );
  }

  Color _roleBg(UserRole r) => switch (r) {
    UserRole.patient => SevaCareColors.primarySoft,
    UserRole.doctor => SevaCareColors.mintSoft,
    UserRole.admin => SevaCareColors.peachSoft,
    UserRole.platformAdmin => SevaCareColors.surfaceMuted,
  };

  Color _roleFg(UserRole r) => switch (r) {
    UserRole.patient => SevaCareColors.primary,
    UserRole.doctor => SevaCareColors.mintForeground,
    UserRole.admin => SevaCareColors.peachForeground,
    UserRole.platformAdmin => SevaCareColors.textMuted,
  };

  IconData? _roleIcon(UserRole r) => switch (r) {
    UserRole.patient => Icons.person_outline,
    UserRole.doctor => Icons.medical_services_outlined,
    UserRole.admin => Icons.admin_panel_settings_outlined,
    UserRole.platformAdmin => Icons.settings_outlined,
  };
}
