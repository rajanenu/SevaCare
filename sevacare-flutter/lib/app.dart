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
import 'screens/search/explore_doctors_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/patient/booking_screen.dart';
import 'screens/patient/appointments_screen.dart';
import 'screens/patient/medical_history_screen.dart';
import 'screens/prescription/prescriptions_screen.dart';
import 'screens/prescription/prescription_detail_screen.dart';
import 'screens/doctor/doctor_home_screen.dart';
import 'screens/doctor/consultation_screen.dart';
import 'screens/doctor/doctor_prescriptions_screen.dart';
import 'screens/doctor/doctor_requests_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/platform_admin/platform_admin_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/qr/qr_appointment_form_screen.dart';
import 'screens/help/help_support_screen.dart';
import 'screens/notifications/notification_screen.dart';
import 'screens/search/global_search_screen.dart';
import 'screens/staff/staff_dashboard_screen.dart';

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
  const SevaCareApp({super.key});

  @override
  ConsumerState<SevaCareApp> createState() => _SevaCareAppState();
}

class _SevaCareAppState extends ConsumerState<SevaCareApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    // Wire 401 auto-logout: any unauthorised response clears the session and
    // sends the user back to the welcome screen.
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
        final isProtected = isPatientPath || isDoctorPath || path.startsWith('/admin') || isPlatformPath || isStaffPath;

        // Unauthenticated user hitting a protected page → welcome
        if (isProtected && !isAuthed) return '/';

        if (isAuthed) {
          final role = auth.role!;
          final home = _roleHome(role);

          // Authenticated user on a public page → their home
          if (path == '/' || path == '/login' || path == '/platform-login') {
            return home;
          }

          // Wrong role accessing a protected path → their correct home
          if (isPatientPath && role != UserRole.patient) return home;
          if (isDoctorPath && role != UserRole.doctor) return home;
          if (path.startsWith('/admin') && role != UserRole.admin && role != UserRole.staff) return home;
          if (path.startsWith('/staff') && role != UserRole.staff) return home;
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
          pageBuilder: (ctx, state) => _slidePage(ctx, state, const AdminDashboardScreen(initialTab: 5)),
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

  static String _roleHome(UserRole r) => switch (r) {
    UserRole.patient => '/patient',
    UserRole.doctor => '/doctor',
    UserRole.admin => '/admin',
    UserRole.staff => '/staff',
    UserRole.platformAdmin => '/platform-admin',
  };
}
