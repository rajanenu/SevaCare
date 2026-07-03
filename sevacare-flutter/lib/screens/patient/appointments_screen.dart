import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  List<AppointmentView>? _appointments;
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  static const _patientBottomNav = [
    BottomNavItem(
      label: 'Dashboard',
      icon: Icons.grid_view_rounded,
      route: '/patient',
    ),
    BottomNavItem(
      label: 'Booking',
      icon: Icons.add_circle_outline,
      route: '/patient/booking',
    ),
    BottomNavItem(
      label: 'Appointments',
      icon: Icons.calendar_today_outlined,
      route: '/patient/appointments',
    ),
    BottomNavItem(
      label: 'Rx',
      icon: Icons.medication_outlined,
      route: '/patient/prescriptions',
    ),
    BottomNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      route: '/patient/profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final home = await ref
          .read(repositoryProvider)
          .getPatientHome(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            auth.token ?? '',
          );
      setState(() {
        _appointments = home.appointments;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = extractErrorMessage(
          e,
          fallback: 'Failed to load appointments.',
        );
        _loading = false;
      });
    }
  }

  List<AppointmentView> get _filtered {
    final all = _appointments ?? [];
    if (_filter == 'all') return all;
    // Filter on the effective status so past-dated appointments never
    // linger under "Upcoming".
    return all
        .where(
          (a) =>
              AppDateUtils.effectiveApptStatus(
                a.status,
                a.slot,
              ).toLowerCase() ==
              _filter,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hospitalName = ref.watch(hospitalProvider).hospitalName;

    return AppShell(
      hospitalName: hospitalName,
      role: UserRole.patient,
      bottomNavItems: _patientBottomNav,
      currentNavIndex: 2,
      onNavTap: (i) => context.go(_patientBottomNav[i].route),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackBtn(onPressed: () => context.go('/patient')),
          const SizedBox(height: 8),
          PageHeader(
            title: tr(ref, 'My Appointments'),
            subtitle: tr(ref, 'All your scheduled visits'),
          ),
          const SizedBox(height: 12),
          SegmentedControl<String>(
            items: [
              SegmentItem(label: tr(ref, 'All'), value: 'all'),
              SegmentItem(label: tr(ref, 'Upcoming'), value: 'upcoming'),
              SegmentItem(label: tr(ref, 'Completed'), value: 'completed'),
              SegmentItem(label: tr(ref, 'Cancelled'), value: 'cancelled'),
            ],
            selected: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: ShimmerList(count: 4, cardHeight: 96),
            )
          else if (_error != null)
            _ErrorState(error: _error!, onRetry: _load)
          else if (_filtered.isEmpty)
            _EmptyState(filter: _filter)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filtered.length,
              separatorBuilder: (_, idx) => const SizedBox(height: 8),
              itemBuilder: (_, i) => StaggeredItem(
                index: i,
                child: _AppointmentCard(
                  appointment: _filtered[i],
                  onCancelled: _load,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final AppointmentView appointment;
  final VoidCallback onCancelled;

  const _AppointmentCard({
    required this.appointment,
    required this.onCancelled,
  });

  String get _effectiveStatus =>
      AppDateUtils.effectiveApptStatus(appointment.status, appointment.slot);

  bool get _canCancel {
    final s = _effectiveStatus.toLowerCase();
    return s == 'upcoming' || s == 'scheduled';
  }

  MetricVariant get _variant => switch (_effectiveStatus.toLowerCase()) {
    'completed' => MetricVariant.mint,
    'cancelled' => MetricVariant.danger,
    _ => MetricVariant.primary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccentCard(
      variant: _variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appointment.doctorName,
                  style: AppTextStyles.cardTitle(SevaCareColors.text),
                ),
              ),
              StatusBadge(status: _effectiveStatus),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 13,
                color: SevaCareColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                appointment.slot,
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appointment.appointmentPublicId,
            style: AppTextStyles.badgeText(SevaCareColors.textMuted),
          ),
          if (appointment.note != null && appointment.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              appointment.note!,
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          ],
          if (_canCancel) ...[
            const SizedBox(height: 10),
            DangerButton(
              label: tr(ref, 'Cancel Appointment'),
              onPressed: () => _confirmCancel(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(ref, 'Cancel Appointment')),
        content: Text(
          tr(ref, 'Are you sure you want to cancel this appointment?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(ref, 'No')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: SevaCareColors.danger),
            child: Text(tr(ref, 'Yes, Cancel')),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      final auth = ref.read(authProvider);
      await ref
          .read(repositoryProvider)
          .cancelAppointment(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            appointment.appointmentPublicId,
            auth.token ?? '',
          );
      onCancelled();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: SevaCareColors.danger,
          ),
        );
      }
    }
  }
}

class _EmptyState extends ConsumerWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: SevaCareColors.border,
            ),
            const SizedBox(height: 12),
            Text(
              tr(ref, switch (filter) {
                'upcoming' => 'No upcoming appointments',
                'completed' => 'No completed appointments',
                'cancelled' => 'No cancelled appointments',
                _ => 'No appointments yet',
              }),
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            tr(ref, 'Failed to load appointments'),
            style: AppTextStyles.bodyText(SevaCareColors.danger),
          ),
          const SizedBox(height: 12),
          SecondaryButton(label: tr(ref, 'Retry'), onPressed: onRetry),
        ],
      ),
    );
  }
}
