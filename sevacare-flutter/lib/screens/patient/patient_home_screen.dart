import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// ── Patient bottom nav items (shared) ────────────────────────────────────────

List<BottomNavItem> patientNavItems(BuildContext context) => [
      const BottomNavItem(label: 'Dashboard', icon: Icons.grid_view_rounded, route: '/patient'),
      const BottomNavItem(label: 'Doctors', icon: Icons.people_outline, route: '/patient/doctors'),
      const BottomNavItem(
          label: 'Appointments', icon: Icons.calendar_today_outlined, route: '/patient/appointments'),
      const BottomNavItem(label: 'Rx', icon: Icons.medication_outlined, route: '/patient/prescriptions'),
      const BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/patient/profile'),
    ];

// ── Quick action tile ─────────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: SevaCareColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: SevaCareColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: SevaCareColors.primary, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTextStyles.label(SevaCareColors.text),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient Home Screen ───────────────────────────────────────────────────────

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  PatientHomeView? _homeData;
  bool _loading = true;
  String? _error;
  int _dayOffset = 0; // -1 = yesterday, 0 = today, 1 = tomorrow

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
      final repo = ref.read(repositoryProvider);
      final data = await repo.getPatientHome(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
      );
      if (mounted) setState(() => _homeData = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppointmentView> _appointmentsForDay(int offset) {
    final data = _homeData;
    if (data == null) return [];
    final targetDate = AppDateUtils.offsetDay(offset);
    return data.appointments.where((a) {
      try {
        final slotDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(a.slot).toLocal());
        return slotDate == targetDate;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  int _completedCount(List<AppointmentView> appts) =>
      appts.where((a) => a.status.toLowerCase() == 'completed').length;

  Future<void> _cancelAppointment(AppointmentView appt) async {
    final auth = ref.read(authProvider);
    final repo = ref.read(repositoryProvider);
    try {
      await repo.cancelAppointment(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        appt.appointmentPublicId,
        auth.token ?? '',
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: SevaCareColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);
    final dayAppts = _appointmentsForDay(_dayOffset);
    final totalRx = _homeData?.prescriptions.length ?? 0;

    final segmentItems = <SegmentItem<int>>[
      const SegmentItem(value: -1, label: 'Yesterday'),
      const SegmentItem(value: 0, label: 'Today'),
      const SegmentItem(value: 1, label: 'Tomorrow'),
    ];

    // Timeline label
    final timelineDateStr = AppDateUtils.offsetDay(_dayOffset);
    String timelineLabel;
    try {
      final dt = DateTime.parse(timelineDateStr).toLocal();
      timelineLabel = DateFormat('EEE d MMM').format(dt);
    } catch (_) {
      timelineLabel = timelineDateStr;
    }

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: UserRole.patient,
      bottomNavItems: patientNavItems(context),
      currentNavIndex: 0,
      onNavTap: (i) {
        final items = patientNavItems(context);
        if (i < items.length) context.go(items[i].route);
      },
      body: _loading
          ? const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: SevaCareColors.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                        const SizedBox(height: 16),
                        PrimaryButton(label: 'Retry', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Page header
                      const PageHeader(title: 'Patient Overview'),
                      const SizedBox(height: 8),

                      // ── Quick actions grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _QuickActionTile(
                            label: 'Book Appointment',
                            icon: Icons.add_circle_outline,
                            onTap: () => context.push('/patient/booking'),
                          ),
                          _QuickActionTile(
                            label: 'View Appointments',
                            icon: Icons.calendar_today_outlined,
                            onTap: () => context.go('/patient/appointments'),
                          ),
                          _QuickActionTile(
                            label: 'View Prescriptions',
                            icon: Icons.medication_outlined,
                            onTap: () => context.go('/patient/prescriptions'),
                          ),
                          _QuickActionTile(
                            label: 'Medical History',
                            icon: Icons.history_edu_outlined,
                            onTap: () => context.push('/patient/medical-history'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Day selector
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _dayOffset--),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEB),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chevron_left,
                                      size: 16, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Previous',
                                    style: AppTextStyles.label(
                                        const Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Timeline: $timelineLabel',
                                style:
                                    AppTextStyles.label(SevaCareColors.textMuted),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _dayOffset++),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEB),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Next',
                                    style: AppTextStyles.label(
                                        const Color(0xFFDC2626)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right,
                                      size: 16, color: Color(0xFFDC2626)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── Segment control (Yesterday / Today / Tomorrow)
                      if (_dayOffset >= -1 && _dayOffset <= 1)
                        SegmentedControl<int>(
                          items: segmentItems,
                          selected: _dayOffset,
                          onChanged: (v) => setState(() => _dayOffset = v),
                        )
                      else
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: SevaCareColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: Text(
                            AppDateUtils.dayLabel(_dayOffset),
                            style: AppTextStyles.chipLabel(SevaCareColors.primary),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // ── Metric row
                      MetricRow(
                        tiles: [
                          MetricTile(
                            value: '${dayAppts.length}',
                            label: 'APPOINTMENTS',
                            variant: MetricVariant.primary,
                          ),
                          MetricTile(
                            value: '${_completedCount(dayAppts)}',
                            label: 'COMPLETED',
                            variant: MetricVariant.mint,
                          ),
                          MetricTile(
                            value: '$totalRx',
                            label: 'PRESCRIPTIONS',
                            variant: MetricVariant.peach,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Patient Queue
                      Text('Patient Queue', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                      const SizedBox(height: 12),
                      if (dayAppts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  color: SevaCareColors.textMuted, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                'No appointments for ${AppDateUtils.dayLabel(_dayOffset)}',
                                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dayAppts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final appt = dayAppts[index];
                            final isCancellable = !['cancelled', 'canceled', 'completed']
                                .contains(appt.status.toLowerCase());
                            return AccentCard(
                              variant: MetricVariant.primary,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appt.doctorName.isNotEmpty
                                              ? 'Dr. ${appt.doctorName}'
                                              : 'Doctor',
                                          style: AppTextStyles.cardTitle(SevaCareColors.text),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppDateUtils.formatSlot(appt.slot),
                                          style: AppTextStyles.label(SevaCareColors.textMuted),
                                        ),
                                        const SizedBox(height: 8),
                                        StatusBadge(status: appt.status),
                                      ],
                                    ),
                                  ),
                                  if (isCancellable) ...[
                                    const SizedBox(width: 8),
                                    DangerButton(
                                      label: 'Cancel',
                                      onPressed: () => _cancelAppointment(appt),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
