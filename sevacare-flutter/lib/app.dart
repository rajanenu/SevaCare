import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/models/models.dart';
import 'providers/app_state.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/search/hospital_search_screen.dart';
import 'screens/search/pharmacy_store_search_screen.dart';
import 'screens/search/explore_doctors_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pharmacy_login_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/patient/booking_screen.dart';
import 'screens/patient/appointments_screen.dart';
import 'screens/patient/medical_history_screen.dart';
import 'screens/prescription/prescriptions_screen.dart';
import 'screens/prescription/prescription_detail_screen.dart';
import 'screens/doctor/doctor_home_screen.dart';
import 'screens/doctor/queue_board_screen.dart';
import 'screens/queue/queue_control_screen.dart';
import 'screens/doctor/consultation_screen.dart';
import 'screens/doctor/doctor_prescriptions_screen.dart';
import 'screens/doctor/doctor_requests_screen.dart';
import 'screens/doctor/doctor_appointment_requests_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/platform_admin/platform_admin_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/qr/qr_appointment_form_screen.dart';
import 'screens/help/help_support_screen.dart';
import 'screens/notifications/notification_screen.dart';
import 'screens/search/global_search_screen.dart';
import 'screens/staff/staff_dashboard_screen.dart';
import 'screens/terms/terms_screen.dart';
import 'screens/pharmacy/pharmacy_help_screen.dart';
import 'screens/pharmacy/pharmacy_profile_screen.dart';
import 'screens/pharmacy/pharmacy_search_screen.dart';
import 'screens/pharmacy/pharmacy_shell_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/cinematic_intro.dart';

/// Shared slide+fade page transition used by every GoRoute.
CustomTransitionPage<void> _slidePage(
    BuildContext ctx, GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

class SevaCareApp extends ConsumerStatefulWidget {
  /// Whether to play the cinematic intro this launch. False when the app was
  /// cold-restarted shortly after being used (see main.dart intro cooldown), so
  /// resuming from the background drops the user straight onto their page.
  final bool showIntro;

  const SevaCareApp({super.key, this.showIntro = true});

  @override
  ConsumerState<SevaCareApp> createState() => _SevaCareAppState();
}

class _SevaCareAppState extends ConsumerState<SevaCareApp> {
  late final GoRouter _router;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    // Cinematic intro plays on a fresh launch — but never in front of a scanned
    // QR deep link (user expects the form immediately), and not when main.dart
    // decided this is a quick resume within the cooldown window.
    final initialPath = _router.routeInformationProvider.value.uri.path;
    _showIntro = widget.showIntro && !initialPath.startsWith('/qrcode');
    // Stamp the time the intro is shown so quick cold-restarts skip it.
    if (_showIntro) {
      SharedPreferences.getInstance().then(
        (p) => p.setInt(
            'intro_last_shown_ms', DateTime.now().millisecondsSinceEpoch),
      );
    }
    // Wire the silent session refresh: on a 401 the ApiClient asks here for a
    // new access token before giving up. Success is invisible to the user —
    // the failed call is retried with the fresh token.
    apiClient.onTokenRefresh = () async {
      final notifier = ref.read(authProvider.notifier);
      final refresh = notifier.refreshToken;
      if (refresh == null || refresh.isEmpty) return null;
      try {
        final rotated = await ref.read(repositoryProvider).refreshSession(refresh);
        await notifier.updateTokens(rotated.token, rotated.refreshToken);
        return rotated.token;
      } catch (_) {
        return null; // Session truly over → onUnauthorized signs the user out.
      }
    };
    // Wire 401 auto-logout: an unauthorised response that a refresh could not
    // rescue clears the session and sends the user back to the welcome screen.
    apiClient.onUnauthorized = () {
      if (mounted) {
        // 401 = token is genuinely expired — always wipe storage
        ref.read(authProvider.notifier).clearSession(wipeStorage: true);
        _router.go('/');
      }
    };
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hospitalState = ref.watch(hospitalProvider);
    final isDark = ref.watch(darkModeProvider);
    final theme = AppTheme.buildTheme(hospitalState.theme);
    final darkTheme = AppTheme.buildDarkTheme();

    return MaterialApp.router(
      title: 'SevaCare',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (_showIntro)
            CinematicIntro(
              onFinished: () => setState(() => _showIntro = false),
            ),
        ],
      ),
    );
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      // ── Role-based redirect (single source of truth) ────────────────────────
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final path = state.uri.path;
        final isAuthed = auth.isAuthenticated && auth.role != null;

        // Protected path groups
        final isPatientPath = path.startsWith('/patient');
        final isDoctorPath = path.startsWith('/doctor');
        final isPlatformPath = path.startsWith('/platform-admin');
        final isStaffPath = path.startsWith('/staff');
        // NOT startsWith('/pharmacy') — that would swallow the public
        // '/pharmacy-login' page and bounce every visitor back to welcome.
        final isPharmacyPath = path == '/pharmacy' || path.startsWith('/pharmacy/');
        final isProtected = isPatientPath || isDoctorPath || path.startsWith('/admin') || isPlatformPath || isStaffPath || isPharmacyPath;

        // Unauthenticated user hitting a protected page → welcome
        if (isProtected && !isAuthed) return '/';

        if (isAuthed) {
          final role = auth.role!;
          final home = _roleHome(auth);

          // Authenticated user on a public page → their home
          if (path == '/' || path == '/login' || path == '/platform-login' ||
              path == '/pharmacy-login' || path == '/pharmacy-search') {
            return home;
          }

          // Wrong role accessing a protected path → their correct home
          if (isPatientPath && role != UserRole.patient) return home;
          if (isDoctorPath && role != UserRole.doctor) return home;
          // A pharmacy-only tenant's admin/staff hold the same UserRole as a
          // hospital's, but no hospital page is theirs — anything (a stale
          // link, a shared widget's fallback route) that aims them at the
          // hospital shell lands back on the counter instead.
          if (auth.isPharmacyOnly && (path.startsWith('/admin') || path.startsWith('/staff'))) {
            return '/pharmacy';
          }
          if (path.startsWith('/admin') && role != UserRole.admin && role != UserRole.staff) return home;
          if (path.startsWith('/staff') && role != UserRole.staff) return home;
          // The pharmacy counter is run by the tenant's owner (admin) and staff.
          if (isPharmacyPath && role != UserRole.admin && role != UserRole.staff) return home;
          if (isPlatformPath && role != UserRole.platformAdmin) return home;
        }

        return null;
      },
      routes: [
        // ── Public ────────────────────────────────────────────────────────────
        GoRoute(
          path: '/',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const WelcomeScreen()),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const HospitalSearchScreen()),
        ),
        GoRoute(
          path: '/explore/:tenantId',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, ExploreDoctorsScreen(
            tenantId: state.pathParameters['tenantId'] ?? '',
            hospitalName: (state.extra as String?) ?? '',
          )),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const LoginScreen()),
        ),
        GoRoute(
          path: '/platform-login',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const LoginScreen(platformAdminMode: true)),
        ),
        // Search Pharmacies → pick a store → sign in. The mirror of
        // /search → /login for hospitals; both doors into a login stay public.
        GoRoute(
          path: '/pharmacy-search',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PharmacyStoreSearchScreen()),
        ),
        GoRoute(
          path: '/pharmacy-login',
          pageBuilder: (ctx, state) => _slidePage(
            ctx,
            state,
            PharmacyLoginScreen(store: state.extra as TenantSummary?),
          ),
        ),
        GoRoute(path: '/onboarding', redirect: (ctx, _) => '/platform-login'),
        GoRoute(
          path: '/qrcode/:uuid/appointment-form',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, QrAppointmentFormScreen(
            qrcodeUuid: state.pathParameters['uuid'] ?? '',
          )),
        ),

        // ── Patient ───────────────────────────────────────────────────────────
        GoRoute(
          path: '/patient',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PatientHomeScreen()),
        ),
        GoRoute(
          path: '/patient/booking',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const BookingScreen()),
        ),
        GoRoute(
          path: '/patient/appointments',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const AppointmentsScreen()),
        ),
        GoRoute(
          path: '/patient/medical-history',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const MedicalHistoryScreen()),
        ),
        GoRoute(
          path: '/patient/prescriptions',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PrescriptionsScreen()),
        ),
        GoRoute(
          path: '/patient/prescriptions/:id',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, PrescriptionDetailScreen(
            prescriptionId: state.pathParameters['id'] ?? '',
          )),
        ),
        GoRoute(
          path: '/patient/profile',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const ProfileScreen(role: UserRole.patient)),
        ),
        // Doctors listing — redirect to booking where doctors are shown
        GoRoute(path: '/patient/doctors', redirect: (ctx, _) => '/patient/booking'),

        // ── Doctor ────────────────────────────────────────────────────────────
        GoRoute(
          path: '/doctor',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const DoctorHomeScreen()),
        ),
        GoRoute(
          path: '/doctor/consult',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const ConsultationScreen()),
        ),
        GoRoute(
          path: '/doctor/prescriptions',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const DoctorPrescriptionsScreen()),
        ),
        GoRoute(
          path: '/doctor/profile',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const ProfileScreen(role: UserRole.doctor)),
        ),
        GoRoute(
          path: '/doctor/requests',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const DoctorRequestsScreen()),
        ),
        GoRoute(
          path: '/doctor/booking-requests',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const DoctorAppointmentRequestsScreen()),
        ),
        GoRoute(
          path: '/doctor/queue-board',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const QueueBoardScreen()),
        ),
        GoRoute(
          path: '/queue/control',
          pageBuilder: (ctx, state) {
            final extra = (state.extra as Map<String, String>?) ?? const {};
            return _slidePage(
              ctx,
              state,
              QueueControlScreen(
                doctorPublicId: extra['doctorPublicId'] ?? '',
                doctorName: extra['doctorName'] ?? 'Doctor',
              ),
            );
          },
        ),

        // ── Admin ─────────────────────────────────────────────────────────────
        GoRoute(
          path: '/admin',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const AdminDashboardScreen()),
        ),
        GoRoute(
          path: '/admin/users',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const AdminDashboardScreen(initialTab: 2)),
        ),
        GoRoute(
          path: '/admin/doctors',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const AdminDashboardScreen(initialTab: 3)),
        ),
        GoRoute(
          path: '/admin/staff',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const AdminDashboardScreen(initialTab: 3, initialTeamSegment: 1)),
        ),
        GoRoute(
          path: '/admin/reports',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const AdminDashboardScreen(initialTab: 4)),
        ),
        GoRoute(
          path: '/admin/profile',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const ProfileScreen(role: UserRole.admin)),
        ),

        // ── Staff (IP-Staff) ──────────────────────────────────────────────────
        GoRoute(
          path: '/staff',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const StaffDashboardScreen()),
        ),
        GoRoute(
          path: '/staff/profile',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const ProfileScreen(role: UserRole.staff)),
        ),

        // ── Pharmacy (counter) ────────────────────────────────────────────────
        GoRoute(
          path: '/pharmacy',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PharmacyShellScreen()),
        ),
        GoRoute(
          path: '/pharmacy/profile',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PharmacyProfileScreen()),
        ),
        GoRoute(
          path: '/pharmacy/help',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PharmacyHelpScreen()),
        ),
        GoRoute(
          path: '/pharmacy/search',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PharmacySearchScreen()),
        ),

        // ── Platform Admin ────────────────────────────────────────────────────
        GoRoute(
          path: '/platform-admin',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const PlatformAdminScreen()),
        ),
        GoRoute(
          path: '/platform-admin/profile',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const ProfileScreen(role: UserRole.platformAdmin)),
        ),

        // ── Shared ────────────────────────────────────────────────────────────
        GoRoute(
          path: '/settings',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const SettingsScreen()),
        ),
        GoRoute(
          path: '/help',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const HelpSupportScreen()),
        ),
        GoRoute(
          path: '/notifications',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const NotificationScreen()),
        ),
        GoRoute(
          path: '/global-search',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const GlobalSearchScreen()),
        ),
        // Readable by anyone, signed in or not — a hospital deciding whether to join,
        // and a store checking a year later what it agreed to.
        GoRoute(
          path: '/terms',
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const TermsScreen()),
        ),
      ],
      errorBuilder: (ctx, state) => Scaffold(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: SevaCareColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Page not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: SevaCareColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                state.uri.path,
                style: const TextStyle(color: SevaCareColors.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ctx.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pharmacy reuses UserRole.admin/staff (no distinct enum value), so a role
  // switch alone can't tell a pharmacy-only tenant's owner/staff from a
  // hospital's — check auth.isPharmacyOnly first or this redirect keeps
  // bouncing them to the hospital admin/staff dashboard instead.
  static String _roleHome(AuthState auth) {
    if (auth.isPharmacyOnly) return '/pharmacy';
    return switch (auth.role!) {
      UserRole.patient => '/patient',
      UserRole.doctor => '/doctor',
      UserRole.admin => '/admin',
      UserRole.staff => '/staff',
      UserRole.platformAdmin => '/platform-admin',
    };
  }
}
