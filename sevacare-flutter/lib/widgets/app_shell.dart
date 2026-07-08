import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/responsive/breakpoints.dart';
import '../core/utils/auto_refresh.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import '../providers/app_state.dart';
import 'app_nav_rail.dart';
import 'bottom_nav.dart';
import 'connectivity_banner.dart';
import 'faq_bot_sheet.dart';
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

  /// When false the shell does NOT wrap [body] in its own scroll view —
  /// the body owns scrolling (needed for RefreshIndicator screens; nesting
  /// two scroll views makes the inner one swallow drags and blocks the page).
  final bool scrollable;

  /// Optional controller for the shell's scroll view — lets tabbed screens
  /// jump back to top when switching tabs so the frame doesn't jump around.
  final ScrollController? scrollController;

  /// Optional hospital hero image rendered as a glassmorphism backdrop behind
  /// the whole page (blurred + frosted gradient) — used by the login screen
  /// once a hospital is selected.
  final Uint8List? backgroundImageBytes;

  /// Overrides the breakpoint-derived content max width (see
  /// [contentMaxWidthFor]) for screens that want a wider content column on
  /// tablet/desktop than the shell's default (e.g. data-heavy dashboards).
  final double? maxContentWidthOverride;

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
    this.backgroundImageBytes,
    this.maxContentWidthOverride,
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
        // Pre-login screens (role == null) already define onBack for their
        // visible back-arrow icon (search → welcome, login → search, etc.) —
        // reuse it for hardware/gesture back too instead of exiting the app.
        if (onBack != null) {
          onBack!();
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: OrbBackground(
          child: Stack(
            children: [
              // Glassmorphism hospital backdrop — fades in once the image loads
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  child: backgroundImageBytes == null
                      ? const SizedBox.shrink(key: ValueKey('no-hero-bg'))
                      : _GlassImageBackdrop(
                          key: const ValueKey('hero-bg'),
                          bytes: backgroundImageBytes!,
                        ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = MediaQuery.sizeOf(context).width;
                  final maxContentWidth =
                      maxContentWidthOverride ?? contentMaxWidthFor(width);
                  // Rail replaces the bottom nav on tablet/desktop widths —
                  // mobile keeps the exact original bottom-nav Column layout.
                  final useRail =
                      hasBottomNav && screenSizeOf(width) != ScreenSize.mobile;
                  // With the keyboard open the bottom nav would ride up above
                  // it and cover the field being typed into — hide it until
                  // the keyboard is dismissed.
                  final keyboardOpen =
                      MediaQuery.viewInsetsOf(context).bottom > 0;

                  final mainColumn = Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
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
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
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
                                        hasBottomNav && !useRail ? 8 : 32,
                                      ),
                                      child: body,
                                    ),
                                  )
                                : Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      hasBottomNav && !useRail ? 8 : 32,
                                    ),
                                    child: body,
                                  ),
                          ),
                        ),
                      ),
                      if (hasBottomNav && !useRail && !keyboardOpen)
                        SafeArea(
                          top: false,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
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
                  );

                  if (!useRail) return mainColumn;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SafeArea(
                        right: false,
                        child: AppNavRail(
                          items: bottomNavItems!,
                          currentIndex: currentNavIndex ?? 0,
                          onTap: onNavTap ?? (_) {},
                          role: role,
                        ),
                      ),
                      Expanded(child: mainColumn),
                    ],
                  );
                },
              ),
              // Floating assistant bubble — bottom-right, like a website chat
              // widget. Only shown pre-login (role == null): on Welcome/login/
              // onboarding it helps new users, but once signed in it would be
              // noisy on every page, so it's removed after login (web + mobile).
              if (role == null)
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    child: _ChatFab(role: role),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating assistant bubble ──────────────────────────────────────────────────

class _ChatFab extends StatelessWidget {
  final UserRole? role;
  const _ChatFab({this.role});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chat with the SevaCare Assistant',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showFaqBot(context, role),
          customBorder: const CircleBorder(),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: SevaCareColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SevaCareColors.primary.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

// ── Glassmorphism hospital backdrop ────────────────────────────────────────────
// Blurred hero image with a frosted gradient that stays recognizable at the
// top and fades into the scaffold background toward the form area, keeping
// the foreground cards readable.
class _GlassImageBackdrop extends StatelessWidget {
  final Uint8List bytes;
  const _GlassImageBackdrop({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bg.withValues(alpha: 0.28),
                      bg.withValues(alpha: 0.72),
                      bg.withValues(alpha: 0.96),
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
          ],
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
          if (actions != null && actions!.isNotEmpty) ...actions!,
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

class _NotificationBellState extends ConsumerState<_NotificationBell>
    with AutoRefreshMixin {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
    startAutoRefresh(_loadCount, interval: const Duration(seconds: 30));
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
