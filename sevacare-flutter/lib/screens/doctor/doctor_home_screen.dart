import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// ── Doctor bottom nav items ───────────────────────────────────────────────────

List<BottomNavItem> _doctorNavItems() => const [
  BottomNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/doctor'),
  BottomNavItem(label: 'Consult', icon: Icons.healing, route: '/doctor/consult'),
  BottomNavItem(label: 'Requests', icon: Icons.inbox_outlined, route: '/doctor/requests'),
  BottomNavItem(label: 'Rx', icon: Icons.medication_outlined, route: '/doctor/prescriptions'),
  BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/doctor/profile'),
];

// ── DoctorHomeScreen ──────────────────────────────────────────────────────────

class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  // Day offset: -1 = Yesterday, 0 = Today, 1 = Tomorrow
  int _dayOffset = 0;
  DoctorQueueDayView? _queueView;
  bool _loading = false;
  String? _error;
  int _queueFilter = 0; // 0=All, 1=Upcoming, 2=Completed

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  String get _selectedDate => AppDateUtils.offsetDay(_dayOffset);

  Future<void> _loadQueue() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final doctorId = auth.subjectPublicId ?? '';
      final view = await repo.getDoctorQueue(
        hospital.tenantPublicId,
        doctorId,
        _selectedDate,
        auth.token ?? '',
      );
      if (mounted) {
        setState(() {
          _queueView = view;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load patient queue.');
          _loading = false;
        });
      }
    }
  }

  void _changeDay(int newOffset) {
    setState(() => _dayOffset = newOffset);
    _loadQueue();
  }

  List<DoctorQueueFacetView> get _filteredFacets {
    final facets = _queueView?.facets ?? [];
    switch (_queueFilter) {
      case 1:
        return facets.where((f) => f.status.toLowerCase() == 'upcoming').toList();
      case 2:
        return facets.where((f) => f.status.toLowerCase() == 'completed').toList();
      default:
        return facets;
    }
  }

  void _handleNavTap(int index) {
    final items = _doctorNavItems();
    if (index < items.length) {
      context.go(items[index].route);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hospital = ref.watch(hospitalProvider);
    final subjectId = auth.subjectPublicId ?? '';

    final daySegments = [
      SegmentItem<int>(value: -1, label: 'Yesterday'),
      SegmentItem<int>(value: 0, label: 'Today'),
      SegmentItem<int>(value: 1, label: 'Tomorrow'),
    ];

    final queueFilterSegments = [
      SegmentItem<int>(value: 0, label: 'All'),
      SegmentItem<int>(value: 1, label: 'Upcoming'),
      SegmentItem<int>(value: 2, label: 'Completed'),
    ];

    final queueView = _queueView;
    final filteredFacets = _filteredFacets;

    return AppShell(
      hospitalName: hospital.hospitalName.isNotEmpty ? hospital.hospitalName : 'SevaCare',
      role: UserRole.doctor,
      bottomNavItems: _doctorNavItems(),
      currentNavIndex: 0,
      onNavTap: _handleNavTap,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Doctor Overview'),
          const SizedBox(height: 12),

          // ── Doctor avatar ────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                AppAvatar(
                  initials: _initials(subjectId.isNotEmpty ? subjectId : 'Dr'),
                  hue: AppAvatar.hueFromString(subjectId),
                  size: 72,
                ),
                const SizedBox(height: 8),
                Text(
                  subjectId,
                  style: AppTextStyles.label(SevaCareColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Day selector ─────────────────────────────────────────────────────
          SegmentedControl<int>(
            items: daySegments,
            selected: _dayOffset,
            onChanged: _changeDay,
          ),
          const SizedBox(height: 8),

          // Previous / Next navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _changeDay(_dayOffset - 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        style: AppTextStyles.label(const Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Timeline: ${_timelineLabel(_selectedDate)}',
                style: AppTextStyles.label(SevaCareColors.textMuted),
              ),
              GestureDetector(
                onTap: () => _changeDay(_dayOffset + 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: AppTextStyles.label(const Color(0xFFDC2626)),
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
          const SizedBox(height: 12),

          // ── Metrics ──────────────────────────────────────────────────────────
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Failed to load queue', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
                  const SizedBox(height: 8),
                  Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Retry', onPressed: _loadQueue),
                ],
              ),
            ),
          ] else ...[
            MetricRow(
              tiles: [
                MetricTile(
                  value: '${queueView?.totalAppointments ?? 0}',
                  label: 'Appointments',
                  variant: MetricVariant.primary,
                ),
                MetricTile(
                  value: '${queueView?.pendingNotes ?? 0}',
                  label: 'Pending Notes',
                  variant: MetricVariant.peach,
                ),
                MetricTile(
                  value: '${queueView?.avgConsultMinutes ?? 0} min',
                  label: 'Avg Consult',
                  variant: MetricVariant.mint,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Patient Queue ────────────────────────────────────────────────
            Text('Patient Queue', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
            const SizedBox(height: 12),
            SegmentedControl<int>(
              items: queueFilterSegments,
              selected: _queueFilter,
              onChanged: (v) => setState(() => _queueFilter = v),
            ),
            const SizedBox(height: 12),

            if (filteredFacets.isEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No appointments found.',
                      style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your queue for this day is clear.',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final facet in filteredFacets) ...[
                    AccentCard(
                      variant: MetricVariant.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      facet.patientName,
                                      style: AppTextStyles.cardTitle(SevaCareColors.text),
                                    ),
                                    Text(
                                      facet.appointmentPublicId,
                                      style: AppTextStyles.label(SevaCareColors.textMuted),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppDateUtils.formatSlot(facet.slot),
                                      style: AppTextStyles.body(
                                        size: 13,
                                        weight: FontWeight.w500,
                                        color: SevaCareColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(status: facet.status),
                            ],
                          ),

                          // Chips row
                          if (facet.medicines.isNotEmpty || facet.followUp) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (facet.medicines.isNotEmpty)
                                  _Chip(
                                    label: '${facet.medicines.length} medicine(s)',
                                    color: SevaCareColors.primarySoft,
                                    textColor: SevaCareColors.primary,
                                  ),
                                if (facet.followUp)
                                  _Chip(
                                    label: 'Follow-up',
                                    color: SevaCareColors.peachSoft,
                                    textColor: SevaCareColors.peachForeground,
                                  ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),
                          if (facet.status.toLowerCase() == 'completed')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: SevaCareColors.successSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: SevaCareColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 16, color: SevaCareColors.success),
                                  const SizedBox(width: 6),
                                  Text('Consultation Completed', style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: SevaCareColors.success)),
                                ],
                              ),
                            )
                          else
                            SecondaryButton(
                              label: 'Start Consult',
                              icon: Icons.healing,
                              onPressed: () {
                                ref.read(doctorSelectedPatientIdProvider.notifier).state =
                                    facet.patientPublicId;
                                ref.read(doctorSelectedAppointmentIdProvider.notifier).state =
                                    facet.appointmentPublicId;
                                context.go('/doctor/consult');
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _timelineLabel(String apiDate) {
    try {
      final dt = DateTime.parse(apiDate);
      // Format: Mon 22 Jun
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final weekday = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      return '$weekday ${dt.day} $month';
    } catch (_) {
      return AppDateUtils.timelineLabel(apiDate);
    }
  }
}

// ── Small chip widget ─────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: AppTextStyles.label(textColor),
      ),
    );
  }
}
