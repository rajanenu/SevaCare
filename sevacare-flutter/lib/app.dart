import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/models/models.dart';
import 'providers/app_state.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/search/hospital_search_screen.dart';
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
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/platform_admin/platform_admin_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

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
        final isProtected = isPatientPath || isDoctorPath || path.startsWith('/admin') || isPlatformPath;

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
          if (path.startsWith('/admin') && role != UserRole.admin) return home;
          if (isPlatformPath && role != UserRole.platformAdmin) return home;
        }

        return null;
      },
      routes: [
        // ── Public ────────────────────────────────────────────────────────────
        GoRoute(path: '/', builder: (ctx, _) => const WelcomeScreen()),
        GoRoute(path: '/search', builder: (ctx, _) => const HospitalSearchScreen()),
        GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
        GoRoute(path: '/platform-login', builder: (ctx, _) => const LoginScreen(platformAdminMode: true)),
        GoRoute(path: '/onboarding', builder: (ctx, _) => const OnboardingScreen()),

        // ── Patient ───────────────────────────────────────────────────────────
        GoRoute(path: '/patient', builder: (ctx, _) => const PatientHomeScreen()),
        GoRoute(path: '/patient/booking', builder: (ctx, _) => const BookingScreen()),
        GoRoute(path: '/patient/appointments', builder: (ctx, _) => const AppointmentsScreen()),
        GoRoute(path: '/patient/medical-history', builder: (ctx, _) => const MedicalHistoryScreen()),
        GoRoute(path: '/patient/prescriptions', builder: (ctx, _) => const PrescriptionsScreen()),
        GoRoute(
          path: '/patient/prescriptions/:id',
          builder: (ctx, state) => PrescriptionDetailScreen(
            prescriptionId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(path: '/patient/profile', builder: (ctx, _) => const ProfileScreen(role: UserRole.patient)),
        // Doctors listing — redirect to booking where doctors are shown
        GoRoute(path: '/patient/doctors', redirect: (ctx, _) => '/patient/booking'),

        // ── Doctor ────────────────────────────────────────────────────────────
        GoRoute(path: '/doctor', builder: (ctx, _) => const DoctorHomeScreen()),
        GoRoute(path: '/doctor/consult', builder: (ctx, _) => const ConsultationScreen()),
        GoRoute(path: '/doctor/prescriptions', builder: (ctx, _) => const DoctorPrescriptionsScreen()),
        GoRoute(path: '/doctor/profile', builder: (ctx, _) => const ProfileScreen(role: UserRole.doctor)),
        // Requests tab — redirect to doctor home (queue is shown there)
        GoRoute(path: '/doctor/requests', redirect: (ctx, _) => '/doctor'),

        // ── Admin ─────────────────────────────────────────────────────────────
        GoRoute(path: '/admin', builder: (ctx, _) => const AdminDashboardScreen()),
        GoRoute(path: '/admin/users', builder: (ctx, _) => const AdminDashboardScreen(initialTab: 1)),
        GoRoute(path: '/admin/doctors', builder: (ctx, _) => const AdminDashboardScreen(initialTab: 2)),
        GoRoute(path: '/admin/reports', builder: (ctx, _) => const AdminDashboardScreen(initialTab: 3)),
        GoRoute(path: '/admin/profile', builder: (ctx, _) => const ProfileScreen(role: UserRole.admin)),

        // ── Platform Admin ────────────────────────────────────────────────────
        GoRoute(path: '/platform-admin', builder: (ctx, _) => const PlatformAdminScreen()),
        GoRoute(path: '/platform-admin/profile', builder: (ctx, _) => const ProfileScreen(role: UserRole.platformAdmin)),

        // ── Shared ────────────────────────────────────────────────────────────
        GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
      ],
      errorBuilder: (ctx, state) => Scaffold(
        backgroundColor: SevaCareColors.background,
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
    UserRole.platformAdmin => '/platform-admin',
  };
}
