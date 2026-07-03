import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/role_style.dart';
import '../data/models/models.dart';
import '../providers/app_state.dart';
import 'bottom_nav.dart';
import 'connectivity_banner.dart';
import 'orb_background.dart';

const double _kMaxContentWidth = 520;

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

  /// When false the shell does NOT wrap [body] in its own scroll view —
  /// the body owns scrolling (needed for RefreshIndicator screens; nesting
  /// two scroll views makes the inner one swallow drags and blocks the page).
  final bool scrollable;

  /// Optional controller for the shell's scroll view — lets tabbed screens
  /// jump back to top when switching tabs so the frame doesn't jump around.
  final ScrollController? scrollController;

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
    this.scrollable = true,
    this.scrollController,
  });

  String _homeFor(UserRole r) => switch (r) {
    UserRole.patient => '/patient',
    UserRole.doctor => '/doctor',
    UserRole.admin => '/admin',
    UserRole.staff => '/staff',
    UserRole.platformAdmin => '/platform-admin',
  };

  @override
  Widget build(BuildContext context) {
    final hasBottomNav = bottomNavItems != null && bottomNavItems!.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (role != null) {
          final home = _homeFor(role!);
          final currentPath = GoRouterState.of(context).uri.path;
          if (currentPath != home) {
            router.go(home);
            return;
          }
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: OrbBackground(
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kMaxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(
                          hospitalName: hospitalName,
                          role: role,
                          actions: headerActions,
                          showBackButton: showBackButton,
                          onBack: onBack,
                        ),
                        const ConnectivityBanner(),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kMaxContentWidth,
                    ),
                    child: scrollable
                        ? SingleChildScrollView(
                            controller: scrollController,
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
                          )
                        : Padding(
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
              ),
              if (hasBottomNav)
                SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _kMaxContentWidth,
                      ),
                      child: AppBottomNav(
                        items: bottomNavItems!,
                        currentIndex: currentNavIndex ?? 0,
                        onTap: onNavTap ?? (_) {},
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final String hospitalName;
  final UserRole? role;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;

  const _TopBar({
    required this.hospitalName,
    this.role,
    this.actions,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoLetter = hospitalName.isNotEmpty
        ? hospitalName[0].toUpperCase()
        : 'S';
    final showBell = role != null && role != UserRole.platformAdmin;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B).withValues(alpha: 0.95)
            : SevaCareColors.glassSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : SevaCareColors.glassBorder,
          width: 1.5,
        ),
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
          if (showBackButton) ...[
            Semantics(
              label: 'Go back',
              button: true,
              child: SizedBox(
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap:
                      onBack ??
                      () {
                        final nav = Navigator.of(context);
                        if (nav.canPop()) nav.pop();
                      },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: SevaCareColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: SevaCareColors.border,
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 13,
                          color: SevaCareColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
          ],
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
                logoLetter,
                style: AppTextStyles.display(
                  size: 16,
                  weight: FontWeight.w800,
                  color: SevaCareColors.textOnPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hospitalName,
              style: AppTextStyles.body(
                size: 13,
                weight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : SevaCareColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null && actions!.isNotEmpty)
            ...actions!
          else if (role != null)
            Semantics(
              label: '${role!.label} account',
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: role!.bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: role!.fgColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(role!.icon, size: 14, color: role!.fgColor),
              ),
            ),
          // Search — available for all authenticated roles
          if (role != null && role != UserRole.platformAdmin) ...[
            const SizedBox(width: 2),
            Semantics(
              label: 'Search doctors and patients',
              button: true,
              child: SizedBox(
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => context.push('/global-search'),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: SevaCareColors.surfaceMuted,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: SevaCareColors.border,
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.search_rounded,
                          size: 14,
                          color: SevaCareColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (showBell) ...[
            const SizedBox(width: 2),
            Semantics(
              label: 'Notifications',
              button: true,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(child: _NotificationBell()),
              ),
            ),
          ],
          const SizedBox(width: 2),
          Semantics(
            label: 'Help and support',
            button: true,
            child: SizedBox(
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => context.go('/help'),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: SevaCareColors.surfaceMuted,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SevaCareColors.border,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: SevaCareColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification bell with unread badge ───────────────────────────────────────

class _NotificationBell extends ConsumerStatefulWidget {
  const _NotificationBell();

  @override
  ConsumerState<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<_NotificationBell> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  String get _recipientType {
    final role = ref.read(authProvider).role;
    return switch (role) {
      UserRole.doctor => 'DOCTOR',
      UserRole.admin => 'ADMIN',
      UserRole.staff => 'STAFF',
      _ => 'PATIENT',
    };
  }

  Future<void> _loadCount() async {
    try {
      final auth = ref.read(authProvider);
      if (auth.tenantPublicId == null ||
          auth.subjectPublicId == null ||
          auth.token == null) {
        return;
      }
      final data = await ref
          .read(repositoryProvider)
          .getNotifications(
            auth.tenantPublicId!,
            auth.subjectPublicId!,
            _recipientType,
            auth.token!,
          );
      if (mounted) setState(() => _unreadCount = data.unreadCount);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await context.push('/notifications');
        _loadCount();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _unreadCount > 0
                  ? SevaCareColors.primary.withValues(alpha: 0.10)
                  : SevaCareColors.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(
                color: _unreadCount > 0
                    ? SevaCareColors.primary.withValues(alpha: 0.35)
                    : SevaCareColors.border,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                _unreadCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
                size: 14,
                color: _unreadCount > 0
                    ? SevaCareColors.primary
                    : SevaCareColors.textMuted,
              ),
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: SevaCareColors.danger,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
