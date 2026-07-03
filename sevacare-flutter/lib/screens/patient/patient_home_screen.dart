import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/time_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/doctor_name.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// ── Patient bottom nav items (shared) ────────────────────────────────────────

List<BottomNavItem> patientNavItems(BuildContext context) => [
  const BottomNavItem(
    label: 'Dashboard',
    icon: Icons.grid_view_rounded,
    route: '/patient',
  ),
  const BottomNavItem(
    label: 'Doctors',
    icon: Icons.people_outline,
    route: '/patient/doctors',
  ),
  const BottomNavItem(
    label: 'Appointments',
    icon: Icons.calendar_today_outlined,
    route: '/patient/appointments',
  ),
  const BottomNavItem(
    label: 'Rx',
    icon: Icons.medication_outlined,
    route: '/patient/prescriptions',
  ),
  const BottomNavItem(
    label: 'Profile',
    icon: Icons.person_outline,
    route: '/patient/profile',
  ),
];

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
  int _dayOffset = 0;

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
      if (mounted)
        setState(
          () => _error = extractErrorMessage(
            e,
            fallback: 'Failed to load dashboard.',
          ),
        );
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
        final slotDate = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.parse(a.slot).toLocal());
        return slotDate == targetDate;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  int _completedCount(List<AppointmentView> appts) =>
      appts.where((a) => a.status.toLowerCase() == 'completed').length;

  Future<void> _cancelAppointment(AppointmentView appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(ref, 'Cancel Appointment')),
        content: Text(tr(ref, 'Are you sure you want to cancel this appointment?')),
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
    if (confirmed != true || !mounted) return;
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
    final allAppts = _homeData?.appointments ?? [];
    final completedAll = allAppts
        .where((a) => a.status.toLowerCase() == 'completed')
        .length;

    final segmentItems = <SegmentItem<int>>[
      SegmentItem(value: -1, label: tr(ref, 'Yesterday')),
      SegmentItem(value: 0, label: tr(ref, 'Today')),
      SegmentItem(value: 1, label: tr(ref, 'Tomorrow')),
    ];

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
      // Body owns scrolling (RefreshIndicator) — the shell must not add a
      // second scroll view or drags get swallowed and the page can't scroll.
      scrollable: false,
      bottomNavItems: patientNavItems(context),
      currentNavIndex: 0,
      onNavTap: (i) {
        final items = patientNavItems(context);
        if (i < items.length) context.go(items[i].route);
      },
      body: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 4),
              child: ShimmerList(count: 4, cardHeight: 100),
            )
          : _error != null
          ? SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: SevaCareColors.danger,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(label: tr(ref, 'Retry'), onPressed: _load),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── NOVEL: HealthPulse hero banner ──────────────────────
                    _PatientHeroBanner(
                      patientId: ref.read(authProvider).subjectPublicId ?? '',
                      completedAppointments: completedAll,
                      totalAppointments: allAppts.length,
                    ),
                    const SizedBox(height: 12),

                    // ── Countdown to next appointment ───────────────────────
                    _AppointmentCountdownBanner(
                      todayAppointments: _appointmentsForDay(0),
                    ),

                    // ── Live queue position ─────────────────────────────────
                    _LiveQueueBanner(todayAppointments: _appointmentsForDay(0)),
                    const SizedBox(height: 16),

                    // ── #3: Colour-differentiated quick actions ─────────────
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.40,
                      children: [
                        _QuickActionTile(
                          label: tr(ref, 'Book Appointment'),
                          icon: Icons.add_circle_outline,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5148CC), Color(0xFF7C6FE0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.push('/patient/booking'),
                        ),
                        _QuickActionTile(
                          label: tr(ref, 'View Appointments'),
                          icon: Icons.calendar_today_outlined,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF52C499)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.go('/patient/appointments'),
                        ),
                        _QuickActionTile(
                          label: tr(ref, 'View Prescriptions'),
                          icon: Icons.medication_outlined,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF0A86B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.go('/patient/prescriptions'),
                        ),
                        _QuickActionTile(
                          label: tr(ref, 'Medical History'),
                          icon: Icons.history_edu_outlined,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.push('/patient/medical-history'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Day selector ────────────────────────────────────────
                    Row(
                      children: [
                        _DayNavBtn(
                          label: tr(ref, 'Previous'),
                          icon: Icons.chevron_left,
                          onTap: () => setState(() => _dayOffset--),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Timeline: $timelineLabel',
                              style: AppTextStyles.label(
                                SevaCareColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        _DayNavBtn(
                          label: tr(ref, 'Next'),
                          icon: Icons.chevron_right,
                          iconTrailing: true,
                          onTap: () => setState(() => _dayOffset++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          AppDateUtils.dayLabel(_dayOffset),
                          style: AppTextStyles.chipLabel(
                            SevaCareColors.primary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ── Metrics ─────────────────────────────────────────────
                    MetricRow(
                      tiles: [
                        MetricTile(
                          value: '${dayAppts.length}',
                          label: tr(ref, 'APPOINTMENTS'),
                          variant: MetricVariant.primary,
                        ),
                        MetricTile(
                          value: '${_completedCount(dayAppts)}',
                          label: tr(ref, 'COMPLETED'),
                          variant: MetricVariant.mint,
                        ),
                        MetricTile(
                          value: '$totalRx',
                          label: tr(ref, 'PRESCRIPTIONS'),
                          variant: MetricVariant.peach,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── #2: Journey appointment cards ───────────────────────
                    Text(
                      tr(ref, 'Patient Queue'),
                      style: AppTextStyles.sectionTitle(SevaCareColors.text),
                    ),
                    const SizedBox(height: 12),
                    if (dayAppts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: SevaCareColors.textMuted,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${tr(ref, 'No appointments for')} ${AppDateUtils.dayLabel(_dayOffset)}',
                              style: AppTextStyles.bodyText(
                                SevaCareColors.textMuted,
                              ),
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
                          final isCancellable = ![
                            'cancelled',
                            'canceled',
                            'completed',
                          ].contains(
                            AppDateUtils.effectiveApptStatus(
                              appt.status,
                              appt.slot,
                            ).toLowerCase(),
                          );
                          return _JourneyCard(
                            appt: appt,
                            isCancellable: isCancellable,
                            onCancel: () => _cancelAppointment(appt),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── #1 NOVEL: HealthPulse hero banner ─────────────────────────────────────────
// Animated arc ring around the avatar showing appointment completion rate.
// Not present in any other healthcare app.

class _PatientHeroBanner extends ConsumerWidget {
  final String patientId;
  final int completedAppointments;
  final int totalAppointments;

  const _PatientHeroBanner({
    required this.patientId,
    required this.completedAppointments,
    required this.totalAppointments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = currentDayPhase();
    final name = ref.watch(authProvider).subjectName.trim();
    final greeting = name.isNotEmpty
        ? '${tr(ref, phase.greeting)}, $name'
        : tr(ref, phase.greeting);
    final completionRate = totalAppointments == 0
        ? 0.0
        : (completedAppointments / totalAppointments).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF145240), Color(0xFF52C499)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const AnimatedHealthcareBg(
              variant: HealthcareBgVariant.patient,
              height: 120,
            ),
            const Positioned.fill(child: TimeTintOverlay()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  // HealthPulse Ring avatar
                  _HealthPulseRingAvatar(completionRate: completionRate),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              phase.icon,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.80),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label(
                                  Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tr(ref, 'Stay Healthy Today'),
                          style: AppTextStyles.cardTitle(Colors.white),
                        ),
                        const SizedBox(height: 5),
                        if (totalAppointments > 0)
                          Text(
                            '$completedAppointments of $totalAppointments visits complete',
                            style: AppTextStyles.label(
                              Colors.white.withValues(alpha: 0.65),
                            ),
                          )
                        else
                          Text(
                            patientId,
                            style: AppTextStyles.label(
                              Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Text(
                      tr(ref, 'Patient'),
                      style: AppTextStyles.label(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated arc ring that sweeps to the patient's appointment completion rate.
/// First in any healthcare ERP — gamifies health engagement visually.
class _HealthPulseRingAvatar extends StatefulWidget {
  final double completionRate;
  const _HealthPulseRingAvatar({required this.completionRate});

  @override
  State<_HealthPulseRingAvatar> createState() => _HealthPulseRingAvatarState();
}

class _HealthPulseRingAvatarState extends State<_HealthPulseRingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = CurvedAnimation(
          parent: _ctrl,
          curve: Curves.easeOutCubic,
        ).value;
        return CustomPaint(
          size: const Size(60, 60),
          painter: _RingPainter(
            progress: widget.completionRate * t,
            pulseT: _ctrl.value,
          ),
          child: const SizedBox(
            width: 60,
            height: 60,
            child: Center(
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double pulseT;
  const _RingPainter({required this.progress, required this.pulseT});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 3;

    // Track ring (dim)
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        Paint()
          ..color = const Color(0xFF4ADE80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );

      // Glowing tip at arc end
      final tipAngle = -math.pi / 2 + progress * math.pi * 2;
      final tipX = cx + r * math.cos(tipAngle);
      final tipY = cy + r * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        4,
        Paint()
          ..color = const Color(0xFF4ADE80).withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(tipX, tipY),
        2.5,
        Paint()..color = const Color(0xFF4ADE80),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── #2: Care Journey Card ─────────────────────────────────────────────────────
// Replaces plain AccentCard with a 4-step visual progress timeline.
// Patients can instantly see WHERE they are in the care process.

class _JourneyCard extends ConsumerWidget {
  final AppointmentView appt;
  final bool isCancellable;
  final VoidCallback onCancel;

  const _JourneyCard({
    required this.appt,
    required this.isCancellable,
    required this.onCancel,
  });

  static const _steps = ['Booked', 'Confirmed', 'Consulting', 'Done'];
  static const _icons = [
    Icons.bookmark_added_outlined,
    Icons.check_circle_outline,
    Icons.medical_services_outlined,
    Icons.verified_outlined,
  ];

  int get _activeStep {
    final s = AppDateUtils.effectiveApptStatus(
      appt.status,
      appt.slot,
    ).toLowerCase();
    if (s == 'completed') return 4;
    if (s.contains('consult') || s == 'in_progress' || s == 'in progress')
      return 2;
    if (s == 'confirmed') return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = _activeStep;
    final translatedSteps = _steps.map((s) => tr(ref, s)).toList();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor + slot + cancel
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.doctorName.isNotEmpty
                          ? 'Dr. ${stripDoctorPrefix(appt.doctorName)}'
                          : 'Doctor',
                      style: AppTextStyles.cardTitle(SevaCareColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppDateUtils.formatSlot(appt.slot),
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(
                      status: AppDateUtils.effectiveApptStatus(
                        appt.status,
                        appt.slot,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCancellable) ...[
                const SizedBox(width: 8),
                DangerButton(label: tr(ref, 'Cancel'), onPressed: onCancel),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Journey progress timeline
          _JourneyTimeline(
            activeStep: step,
            steps: translatedSteps,
            icons: _icons,
          ),
        ],
      ),
    );
  }
}

class _JourneyTimeline extends StatelessWidget {
  final int activeStep; // 0-4 (4 = all done)
  final List<String> steps;
  final List<IconData> icons;

  const _JourneyTimeline({
    required this.activeStep,
    required this.steps,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line between steps
          final lineIdx = i ~/ 2;
          final done = activeStep > lineIdx + 1;
          final active = activeStep == lineIdx + 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 2,
                decoration: BoxDecoration(
                  gradient: (done || active)
                      ? const LinearGradient(
                          colors: [SevaCareColors.primary, SevaCareColors.mint],
                        )
                      : null,
                  color: (done || active) ? null : SevaCareColors.border,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final done = activeStep > idx;
        final active = activeStep == idx;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done
                    ? const LinearGradient(
                        colors: SevaCareColors.buttonGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: done
                    ? null
                    : (active ? null : SevaCareColors.surfaceMuted),
                border: active
                    ? Border.all(color: SevaCareColors.primary, width: 2)
                    : null,
                boxShadow: done
                    ? [
                        BoxShadow(
                          color: SevaCareColors.primary.withValues(alpha: 0.30),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icons[idx],
                size: 13,
                color: done
                    ? Colors.white
                    : (active
                          ? SevaCareColors.primary
                          : SevaCareColors.textMuted),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 48,
              child: Text(
                steps[idx],
                style: AppTextStyles.body(
                  size: 9,
                  weight: (done || active) ? FontWeight.w700 : FontWeight.w500,
                  color: done
                      ? SevaCareColors.primary
                      : (active
                            ? SevaCareColors.primary
                            : SevaCareColors.textMuted),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── #3: Gradient quick action tile ───────────────────────────────────────────
// Each action has its own unique gradient — no more all-purple tiles.

class _QuickActionTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  Color get _accentColor => (widget.gradient as LinearGradient).colors.first;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: SevaCareColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: _pressed
                  ? _accentColor.withValues(alpha: 0.30)
                  : SevaCareColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              if (_pressed)
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
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
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.label,
                  style: AppTextStyles.label(SevaCareColors.text),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day nav button ─────────────────────────────────────────────────────────────

class _DayNavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool iconTrailing;

  const _DayNavBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEB),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconTrailing
              ? [
                  Text(
                    label,
                    style: AppTextStyles.label(const Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, size: 16, color: const Color(0xFFDC2626)),
                ]
              : [
                  Icon(icon, size: 16, color: const Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppTextStyles.label(const Color(0xFFDC2626)),
                  ),
                ],
        ),
      ),
    );
  }
}

// ── Live Queue Banner ─────────────────────────────────────────────────────────

class _LiveQueueBanner extends StatefulWidget {
  final List<AppointmentView> todayAppointments;
  const _LiveQueueBanner({required this.todayAppointments});

  @override
  State<_LiveQueueBanner> createState() => _LiveQueueBannerState();
}

class _LiveQueueBannerState extends State<_LiveQueueBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  ({int position, int waitMins, String doctorName, String slot})?
  get _queueInfo {
    final now = DateTime.now();
    final upcoming = widget.todayAppointments
        .where(
          (a) => ![
            'completed',
            'cancelled',
            'canceled',
          ].contains(a.status.toLowerCase()),
        )
        .where((a) {
          try {
            return DateTime.parse(a.slot).toLocal().isAfter(now);
          } catch (_) {
            return true;
          }
        })
        .toList();
    if (upcoming.isEmpty) return null;
    final first = upcoming.first;
    return (
      position: 1,
      waitMins: 10,
      doctorName: first.doctorName,
      slot: first.slot,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _queueInfo;
    if (info == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final glow = _pulse.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: SevaCareColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SevaCareColors.primary.withValues(
                alpha: 0.20 + glow * 0.15,
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SevaCareColors.primary.withValues(
                  alpha: 0.06 + glow * 0.06,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 26 + glow * 6,
                    height: 26 + glow * 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SevaCareColors.primary.withValues(
                        alpha: 0.08 + glow * 0.06,
                      ),
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SevaCareColors.primarySoft,
                      border: Border.all(
                        color: SevaCareColors.primary.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '#${info.position}',
                        style: AppTextStyles.body(
                          size: 11,
                          weight: FontWeight.w800,
                          color: SevaCareColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SevaCareColors.mint.withValues(
                              alpha: 0.5 + glow * 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE · Queue Position',
                          style: AppTextStyles.label(SevaCareColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.doctorName.isNotEmpty
                          ? 'Dr. ${stripDoctorPrefix(info.doctorName)}'
                          : 'Upcoming Appointment',
                      style: AppTextStyles.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: SevaCareColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '~${info.waitMins} min',
                    style: AppTextStyles.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: SevaCareColors.primary,
                    ),
                  ),
                  Text(
                    'est. wait',
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Appointment Countdown Banner ──────────────────────────────────────────────

class _AppointmentCountdownBanner extends StatefulWidget {
  final List<AppointmentView> todayAppointments;
  const _AppointmentCountdownBanner({required this.todayAppointments});

  @override
  State<_AppointmentCountdownBanner> createState() =>
      _AppointmentCountdownBannerState();
}

class _AppointmentCountdownBannerState
    extends State<_AppointmentCountdownBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  AppointmentView? _next;

  @override
  void initState() {
    super.initState();
    _computeNext();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick());
    });
  }

  @override
  void didUpdateWidget(_AppointmentCountdownBanner old) {
    super.didUpdateWidget(old);
    _computeNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _computeNext() {
    final now = DateTime.now();
    AppointmentView? nearest;
    Duration nearestDiff = const Duration(days: 999);
    for (final appt in widget.todayAppointments) {
      if ([
        'cancelled',
        'canceled',
        'completed',
      ].contains(appt.status.toLowerCase()))
        continue;
      try {
        final slot = DateTime.parse(appt.slot).toLocal();
        final diff = slot.difference(now);
        if (diff.isNegative) continue;
        if (diff < nearestDiff) {
          nearestDiff = diff;
          nearest = appt;
        }
      } catch (_) {
        continue;
      }
    }
    _next = nearest;
    _remaining = nearestDiff == const Duration(days: 999)
        ? Duration.zero
        : nearestDiff;
  }

  void _tick() {
    if (_remaining.inSeconds > 0) {
      _remaining -= const Duration(seconds: 1);
    } else {
      _computeNext();
    }
  }

  String _fmt(Duration d) {
    if (d.inSeconds <= 0) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color get _urgencyColor {
    if (_remaining.inMinutes <= 15) return SevaCareColors.danger;
    if (_remaining.inMinutes <= 60) return SevaCareColors.peach;
    return SevaCareColors.primary;
  }

  String get _urgencyLabel {
    if (_remaining.inMinutes <= 15) return 'Starting very soon!';
    if (_remaining.inMinutes <= 60) return 'Getting close — get ready';
    return 'Your next appointment today';
  }

  @override
  Widget build(BuildContext context) {
    if (_next == null || _remaining.inSeconds <= 0)
      return const SizedBox.shrink();
    final color = _urgencyColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_outlined, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_urgencyLabel, style: AppTextStyles.label(color)),
                const SizedBox(height: 2),
                Text(
                  _next!.doctorName.isNotEmpty
                      ? 'Dr. ${stripDoctorPrefix(_next!.doctorName)}'
                      : 'Doctor appointment',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: SevaCareColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(_remaining),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'remaining',
                style: AppTextStyles.label(SevaCareColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
