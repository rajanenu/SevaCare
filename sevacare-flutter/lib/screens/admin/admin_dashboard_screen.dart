import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/time_theme.dart';
import '../../core/utils/auto_refresh.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';
import 'admin_requests_screen.dart';

// ── Admin bottom nav items ────────────────────────────────────────────────────

List<BottomNavItem> _adminNavItems() => const [
  BottomNavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/admin',
  ),
  BottomNavItem(
    label: 'Admins',
    icon: Icons.manage_accounts_outlined,
    route: '/admin/users',
  ),
  BottomNavItem(
    label: 'Doctors',
    icon: Icons.medical_services_outlined,
    route: '/admin/doctors',
  ),
  BottomNavItem(
    label: 'Staff',
    icon: Icons.badge_outlined,
    route: '/admin/staff',
  ),
  BottomNavItem(
    label: 'Profile',
    icon: Icons.person_outline,
    route: '/admin/profile',
  ),
];

// ── Root screen with tab controller ──────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final int initialTab;
  final int initialTeamSegment;
  const AdminDashboardScreen({
    super.key,
    this.initialTab = 0,
    this.initialTeamSegment = 0,
  });

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late int _tabIndex = widget.initialTab;

  void _handleNavTap(int index) {
    final items = _adminNavItems();
    if (index < items.length) {
      context.go(items[index].route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);
    final width = MediaQuery.sizeOf(context).width;

    // Full dashboard for every admin (generic/temp-admin restricted view removed)
    const tabDefs = [
      (0, Icons.dashboard_outlined, 'Dashboard'),
      (3, Icons.groups_outlined, 'Team'),
      (1, Icons.inbox_outlined, 'Requests'),
      (4, Icons.bar_chart_outlined, 'Reports'),
      (2, Icons.manage_accounts_outlined, 'Admins'),
    ];

    return AppShell(
      hospitalName: hospital.hospitalName.isNotEmpty
          ? hospital.hospitalName
          : 'SevaCare',
      role: UserRole.admin,
      bottomNavItems: _adminNavItems(),
      currentNavIndex: _tabIndex == 3
          ? (widget.initialTeamSegment == 1 ? 3 : 2)
          : (const {0: 0, 1: 0, 2: 1, 4: 3}[_tabIndex] ?? 0),
      onNavTap: _handleNavTap,
      // This dashboard's data tables (Team/Admins/Reports) benefit from more
      // room than the app's default 1040px content column, so on tablet/
      // desktop widths let it use most of the viewport instead.
      maxContentWidthOverride: screenSizeOf(width) == ScreenSize.mobile
          ? null
          : (width * 0.94).clamp(760.0, 1600.0),
      // Fixed-frame layout: the hero banner and tab bar are pinned; each tab
      // owns its scroll area below, so switching tabs never moves the frame.
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Admin hero banner ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3F39A8), Color(0xFFF0A86B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  const AnimatedHealthcareBg(
                    variant: HealthcareBgVariant.admin,
                    height: 130,
                  ),
                  const Positioned.fill(child: TimeTintOverlay()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospital.hospitalName.isNotEmpty
                                    ? hospital.hospitalName
                                    : 'Hospital',
                                style: AppTextStyles.cardTitle(Colors.white),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Operations Dashboard',
                                style: AppTextStyles.label(
                                  Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Icon + label tab bar ────────────────────────────────────────────
          // Mobile keeps the original horizontally-scrolling chip row; on
          // tablet/desktop the tabs stretch to fill the now-wider bar evenly
          // instead of hugging the left edge with empty space to the right.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: SevaCareColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SevaCareColors.border),
            ),
            child: screenSizeOf(width) == ScreenSize.mobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: tabDefs
                          .map((def) => _AdminTabButton(
                                def: def,
                                active: _tabIndex == def.$1,
                                onTap: () => setState(() => _tabIndex = def.$1),
                              ))
                          .toList(),
                    ),
                  )
                : Row(
                    children: tabDefs
                        .map((def) => Expanded(
                              child: _AdminTabButton(
                                def: def,
                                active: _tabIndex == def.$1,
                                onTap: () => setState(() => _tabIndex = def.$1),
                                expand: true,
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // All tabs stay mounted (IndexedStack) so switching is instant —
          // no refetch, no shimmer flash — and each tab keeps its own scroll
          // position inside the fixed frame.
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              sizing: StackFit.expand,
              children: [
                _tabPage(const _DashboardTab()),
                // Manages its own pinned sub-tab bar + scroll areas.
                const AdminRequestsScreen(),
                _tabPage(const _AdminUsersTab()),
                _tabPage(_TeamManagementTab(
                  initialSegment: widget.initialTeamSegment,
                )),
                _tabPage(const _ReportsTab()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Scrollable content region for one tab — lives below the pinned frame.
  Widget _tabPage(Widget child) {
    return SingleChildScrollView(
      primary: false,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: child,
    );
  }
}

class _AdminTabButton extends StatelessWidget {
  final (int, IconData, String) def;
  final bool active;
  final VoidCallback onTap;
  final bool expand;

  const _AdminTabButton({
    required this.def,
    required this.active,
    required this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final (_, icon, label) = def;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: SevaCareColors.buttonGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: SevaCareColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : SevaCareColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : SevaCareColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TAB 0: Dashboard ──────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerStatefulWidget {
  const _DashboardTab();

  @override
  ConsumerState<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<_DashboardTab>
    with AutoRefreshMixin {
  AdminOverview? _overview;
  List<DoctorRecord> _doctors = [];
  BookingChannelStats? _channelStats;
  bool _loading = true;
  String? _error;
  int _visitSegment = 1; // 0=Today, 1=Week, 2=Month, 3=Year

  @override
  void initState() {
    super.initState();
    _load();
    startAutoRefresh(() => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final token = auth.token ?? '';
      final tenantId = hospital.tenantPublicId;

      final results = await Future.wait([
        repo.getAdminOverview(tenantId, token),
        repo.listDoctorRecords(tenantId, token),
        repo.getBookingChannelStats(tenantId, token),
      ]);

      if (mounted) {
        setState(() {
          _overview = results[0] as AdminOverview;
          _doctors = results[1] as List<DoctorRecord>;
          _channelStats = results[2] as BookingChannelStats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = extractErrorMessage(
            e,
            fallback: 'Failed to load dashboard overview.',
          );
          _loading = false;
        });
      }
    }
  }

  Map<String, int> _groupBySpecialty() {
    final map = <String, int>{};
    for (final d in _doctors) {
      map[d.specialty] = (map[d.specialty] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(
        children: [
          const ShimmerMetricRow(),
          const SizedBox(height: 10),
          const ShimmerMetricRow(),
          const SizedBox(height: 10),
          const ShimmerList(count: 2, cardHeight: 70),
        ],
      );
    }

    if (_error != null) {
      return AppCard(
        child: Column(
          children: [
            Text(
              'Failed to load overview',
              style: AppTextStyles.cardTitle(SevaCareColors.danger),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Retry', onPressed: _load),
          ],
        ),
      );
    }

    final overview = _overview;
    final specialtyCounts = _groupBySpecialty();

    // Patient visits segment labels
    final visitSegments = [
      SegmentItem<int>(value: 0, label: 'Today'),
      SegmentItem<int>(value: 1, label: 'This Week'),
      SegmentItem<int>(value: 2, label: 'This Month'),
      SegmentItem<int>(value: 3, label: 'This Year'),
    ];

    // Derive "Today at a glance" numbers from metrics
    final todayVisits =
        int.tryParse(
          overview?.metrics.isNotEmpty == true
              ? overview!.metrics[0].value
              : '0',
        ) ??
        0;
    final upcomingBooked =
        int.tryParse(
          overview != null && overview.metrics.length > 1
              ? overview.metrics[1].value
              : '0',
        ) ??
        0;
    final activeDoctors = _doctors.where((d) => d.active).length;
    // Pending leaves come from AdminRequests — approximate from overview if available
    // (backend can expose this; we show 0 if not present yet)
    const pendingLeaves = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TODAY AT A GLANCE (actionable, shown first) ────────────────────────
        _TodayGlanceSection(
          todayVisits: todayVisits,
          upcomingBooked: upcomingBooked,
          activeDoctors: activeDoctors,
          pendingLeaves: pendingLeaves,
          onViewRequests: () {
            // Navigate to Requests tab (tab index 1)
            context.go('/admin');
          },
        ),
        const SizedBox(height: 24),

        // ── Doctors by Department ─────────────────────────────────────────────
        Text(
          'Doctors by Department',
          style: AppTextStyles.sectionTitle(SevaCareColors.text),
        ),
        const SizedBox(height: 12),
        if (specialtyCounts.isEmpty)
          AppCard(
            child: Text(
              'No doctors on record.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < specialtyCounts.entries.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MetricRow(
                    tiles: [
                      MetricTile(
                        value: '${specialtyCounts.entries.elementAt(i).value}',
                        label: specialtyCounts.entries.elementAt(i).key,
                        variant: MetricVariant.primary,
                      ),
                      if (i + 1 < specialtyCounts.entries.length)
                        MetricTile(
                          value:
                              '${specialtyCounts.entries.elementAt(i + 1).value}',
                          label: specialtyCounts.entries.elementAt(i + 1).key,
                          variant: MetricVariant.primary,
                        )
                      else
                        MetricTile(
                          value: '',
                          label: '',
                          variant: MetricVariant.primary,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),

        // ── Patient Sources (how patients are arriving) ────────────────────────
        Text(
          'Patient Sources',
          style: AppTextStyles.sectionTitle(SevaCareColors.text),
        ),
        const SizedBox(height: 12),
        SegmentedControl<int>(
          items: visitSegments,
          selected: _visitSegment,
          onChanged: (v) => setState(() => _visitSegment = v),
        ),
        const SizedBox(height: 12),
        MetricRow(
          tiles: [
            MetricTile(
              value: '${_countForSegment('PATIENT_APP')}',
              label: 'Patient App',
              variant: MetricVariant.primary,
            ),
            MetricTile(
              value: '${_countForSegment('QR_CODE')}',
              label: 'QR Code',
              variant: MetricVariant.mint,
            ),
          ],
        ),
        const SizedBox(height: 8),
        MetricRow(
          tiles: [
            MetricTile(
              value: '${_countForSegment('IP_STAFF')}',
              label: 'IP-Staff',
              variant: MetricVariant.peach,
            ),
            MetricTile(
              value: '${_countForSegment('CHATBOT')}',
              label: 'Chatbot',
              variant: MetricVariant.primary,
            ),
          ],
        ),
        if ((_channelStats?.qrPendingRequests ?? 0) > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SevaCareColors.warningSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SevaCareColors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_outlined,
                  color: SevaCareColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_channelStats!.qrPendingRequests} booking request${_channelStats!.qrPendingRequests == 1 ? '' : 's'} could not be auto-confirmed — doctor action needed',
                    style: AppTextStyles.bodyText(SevaCareColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  int _countForSegment(String source) {
    final match =
        _channelStats?.sources.where((s) => s.source == source).toList() ??
        const [];
    if (match.isEmpty) return 0;
    final s = match.first;
    switch (_visitSegment) {
      case 0:
        return s.today;
      case 2:
        return s.month;
      case 3:
        return s.year;
      default:
        return s.week;
    }
  }
}

// ── Today at a Glance ────────────────────────────────────────────────────────

class _TodayGlanceSection extends StatelessWidget {
  final int todayVisits;
  final int upcomingBooked;
  final int activeDoctors;
  final int pendingLeaves;
  final VoidCallback onViewRequests;

  const _TodayGlanceSection({
    required this.todayVisits,
    required this.upcomingBooked,
    required this.activeDoctors,
    required this.pendingLeaves,
    required this.onViewRequests,
  });

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingLeaves > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Today at a Glance',
              style: AppTextStyles.sectionTitle(SevaCareColors.text),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'LIVE',
                style: TextStyle(
                  color: SevaCareColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Action-needed alert (pending leaves) ──────────────────────────────
        if (hasPending) ...[
          Semantics(
            label: '$pendingLeaves pending leave requests need your attention',
            button: true,
            child: GestureDetector(
              onTap: onViewRequests,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SevaCareColors.warningSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SevaCareColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: SevaCareColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pendingLeaves leave request${pendingLeaves == 1 ? '' : 's'} awaiting approval',
                        style: AppTextStyles.bodyText(SevaCareColors.warning),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: SevaCareColors.warning,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Primary stat row ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _GlanceTile(
                icon: Icons.people_alt_rounded,
                label: "Today's Patients",
                value: '$todayVisits',
                color: SevaCareColors.primary,
                bg: SevaCareColors.primarySoft,
                isActionable: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlanceTile(
                icon: Icons.schedule_rounded,
                label: 'Upcoming',
                value: '$upcomingBooked',
                color: const Color(0xFFD97706),
                bg: SevaCareColors.warningSurface,
                isActionable: upcomingBooked > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GlanceTile(
                icon: Icons.medical_services_rounded,
                label: 'Active Doctors',
                value: '$activeDoctors',
                color: SevaCareColors.mintForeground,
                bg: SevaCareColors.mintSoft,
                isActionable: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlanceTile(
                icon: Icons.inbox_outlined,
                label: 'Pending Leaves',
                value: '$pendingLeaves',
                color: pendingLeaves > 0
                    ? SevaCareColors.danger
                    : SevaCareColors.textMuted,
                bg: pendingLeaves > 0
                    ? SevaCareColors.errorSurface
                    : SevaCareColors.surfaceMuted,
                isActionable: pendingLeaves > 0,
                onTap: pendingLeaves > 0 ? onViewRequests : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GlanceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool isActionable;
  final VoidCallback? onTap;

  const _GlanceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.isActionable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${isActionable ? ', tap to view' : ''}',
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isActionable ? 0.35 : 0.15),
              width: isActionable ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  if (isActionable) ...[
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: color.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient stat micro-card (used by the Reports tab) ───────────────────────

class _MicroCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Gradient gradient;

  const _MicroCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── TAB 1: Admin Users ────────────────────────────────────────────────────────

class _AdminUsersTab extends ConsumerStatefulWidget {
  const _AdminUsersTab();

  @override
  ConsumerState<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<_AdminUsersTab> {
  List<AdminUserRecord> _admins = [];
  bool _loading = false;
  String? _error;
  int _filterIndex = 0; // 0=All, 1=Active only
  bool _showAddForm = false;
  String? _nextAdminId;
  int _page = 0;
  static const int _pageSize = 5;

  // Add form controllers
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _formError;
  String? _formSuccess;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdmins());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final list = await repo.listAdminUsers(
        hospital.tenantPublicId,
        auth.token ?? '',
        activeOnly: _filterIndex == 1,
      );
      if (mounted) {
        list.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
        setState(() {
          _admins = list;
          _page = 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(
            e,
            fallback: 'Failed to load admin users.',
          );
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNextId() async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final id = await repo.getNextAdminId(
        hospital.tenantPublicId,
        auth.token ?? '',
      );
      if (mounted) setState(() => _nextAdminId = id);
    } catch (_) {}
  }

  void _toggleAddForm() {
    setState(() {
      _showAddForm = !_showAddForm;
      _formError = null;
      _formSuccess = null;
      if (_showAddForm) {
        _nameCtrl.clear();
        _mobileCtrl.clear();
        _emailCtrl.clear();
        _loadNextId();
      }
    });
  }

  Future<void> _createAdmin() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Full name is required.');
      return;
    }
    if (mobile.isEmpty) {
      setState(() => _formError = 'Mobile number is required.');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Add Admin User',
      message: 'Add "$name" as an admin user for this hospital?',
      confirmLabel: 'Add',
      isDanger: false,
    );
    if (!confirmed) return;
    setState(() {
      _saving = true;
      _formError = null;
      _formSuccess = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.createAdminUser(
        hospital.tenantPublicId,
        auth.token ?? '',
        AdminUserUpsertRequest(
          fullName: name,
          mobileNumber: mobile.isNotEmpty ? mobile : null,
          email: _emailCtrl.text.trim().isNotEmpty
              ? _emailCtrl.text.trim()
              : null,
        ),
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _formSuccess = 'Admin user created successfully.';
          _showAddForm = false;
        });
        await _loadAdmins();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = extractErrorMessage(
            e,
            fallback: 'Failed to create admin user.',
          );
        });
      }
    }
  }

  Future<void> _deleteAdmin(String adminId, String adminName) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Admin User',
      message: 'Remove "$adminName" from admin users? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.deleteAdminUser(
        hospital.tenantPublicId,
        adminId,
        auth.token ?? '',
      );
      await _loadAdmins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: SevaCareColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _deactivateAdmin(String adminId) async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.deactivateAdminUser(
        hospital.tenantPublicId,
        adminId,
        auth.token ?? '',
      );
      await _loadAdmins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deactivate failed: $e'),
            backgroundColor: SevaCareColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterSegments = [
      SegmentItem<int>(value: 0, label: 'All'),
      SegmentItem<int>(value: 1, label: 'Active only'),
    ];

    final totalPages = _admins.isEmpty
        ? 1
        : (_admins.length / _pageSize).ceil();
    final paged = _admins.skip(_page * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workspace card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin workspace',
                style: AppTextStyles.sectionTitle(SevaCareColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage hospital administrator accounts.',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PrimaryButton(
                    label: _showAddForm ? 'Cancel' : 'Add Admin',
                    icon: _showAddForm ? Icons.close : Icons.add,
                    compact: true,
                    onPressed: _toggleAddForm,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.download_outlined,
                    tooltip: 'Load Admin Users',
                    onPressed: _loading ? null : _loadAdmins,
                  ),
                  if (_admins.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconBtn(
                      icon: Icons.refresh,
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : _loadAdmins,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Add form
        if (_showAddForm) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Admin User',
                  style: AppTextStyles.sectionTitle(SevaCareColors.text),
                ),
                if (_nextAdminId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ID: $_nextAdminId',
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
                ],
                const SizedBox(height: 12),
                AppFormField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  required: true,
                  placeholder: 'Enter full name',
                ),
                AppFormField(
                  label: 'Mobile Number',
                  controller: _mobileCtrl,
                  required: true,
                  placeholder: '+91 XXXXXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                AppFormField(
                  label: 'Email',
                  controller: _emailCtrl,
                  placeholder: 'admin@hospital.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SevaCareColors.errorSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formError!,
                      style: AppTextStyles.bodyText(SevaCareColors.danger),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_formSuccess != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SevaCareColors.successSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formSuccess!,
                      style: AppTextStyles.bodyText(
                        SevaCareColors.mintForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  label: 'Create Admin User',
                  isLoading: _saving,
                  onPressed: _saving ? null : _createAdmin,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Filter
        SegmentedControl<int>(
          items: filterSegments,
          selected: _filterIndex,
          onChanged: (v) {
            setState(() => _filterIndex = v);
            _loadAdmins();
          },
        ),
        const SizedBox(height: 12),

        // List
        if (_loading)
          const ShimmerList(count: 3)
        else if (_error != null)
          AppCard(
            child: Column(
              children: [
                Text(
                  'Error loading admins',
                  style: AppTextStyles.cardTitle(SevaCareColors.danger),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Retry', onPressed: _loadAdmins),
              ],
            ),
          )
        else if (_admins.isEmpty)
          AppCard(
            child: Text(
              'No admin users found.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          )
        else
          Column(
            children: [
              for (final admin in paged) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StaffPhoto.circle(
                            userId: admin.adminPublicId,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  admin.fullName,
                                  style: AppTextStyles.cardTitle(
                                    SevaCareColors.text,
                                  ),
                                ),
                                Text(
                                  admin.adminPublicId,
                                  style: AppTextStyles.label(
                                    SevaCareColors.textMuted,
                                  ),
                                ),
                                if (admin.mobileNumber != null &&
                                    admin.mobileNumber!.isNotEmpty)
                                  Text(
                                    admin.mobileNumber!,
                                    style: AppTextStyles.bodyText(
                                      SevaCareColors.textMuted,
                                    ),
                                  ),
                                if (admin.email != null &&
                                    admin.email!.isNotEmpty)
                                  Text(
                                    admin.email!,
                                    style: AppTextStyles.bodyText(
                                      SevaCareColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            status: admin.active ? 'active' : 'inactive',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconBtn(
                            icon: Icons.delete_outline,
                            iconColor: SevaCareColors.danger,
                            bgColor: SevaCareColors.errorSurface,
                            tooltip: 'Delete',
                            onPressed: () => _deleteAdmin(
                              admin.adminPublicId,
                              admin.fullName,
                            ),
                          ),
                          if (admin.active) ...[
                            const SizedBox(width: 8),
                            IconBtn(
                              icon: Icons.pause_circle_outline,
                              iconColor: SevaCareColors.peachForeground,
                              bgColor: SevaCareColors.peachSoft,
                              tooltip: 'Deactivate',
                              onPressed: () =>
                                  _deactivateAdmin(admin.adminPublicId),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // ── Pagination controls ──────────────────────────────────────
              if (totalPages > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _page > 0 ? () => setState(() => _page--) : null,
                      child: Opacity(
                        opacity: _page > 0 ? 1.0 : 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chevron_left,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Previous',
                                style: AppTextStyles.label(
                                  const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Page ${_page + 1} of $totalPages',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _page < totalPages - 1
                          ? () => setState(() => _page++)
                          : null,
                      child: Opacity(
                        opacity: _page < totalPages - 1 ? 1.0 : 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
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
                                  const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── TAB 3: Team Management (Doctor + Staff merged) ────────────────────────────

class _TeamManagementTab extends StatefulWidget {
  final int initialSegment;
  const _TeamManagementTab({this.initialSegment = 0});

  @override
  State<_TeamManagementTab> createState() => _TeamManagementTabState();
}

class _TeamManagementTabState extends State<_TeamManagementTab> {
  late int _segment = widget.initialSegment; // 0 = Doctors, 1 = Staff

  @override
  Widget build(BuildContext context) {
    final segments = [
      SegmentItem<int>(value: 0, label: 'Doctors'),
      SegmentItem<int>(value: 1, label: 'Staff'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedControl<int>(
          items: segments,
          selected: _segment,
          onChanged: (v) => setState(() => _segment = v),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _segment == 0
              ? const KeyedSubtree(
                  key: ValueKey('doc'),
                  child: _DoctorManagementTab(),
                )
              : const KeyedSubtree(
                  key: ValueKey('staff'),
                  child: _StaffManagementTab(),
                ),
        ),
      ],
    );
  }
}

// ── Doctor Management (inner tab) ─────────────────────────────────────────────

class _DoctorManagementTab extends ConsumerStatefulWidget {
  const _DoctorManagementTab();

  @override
  ConsumerState<_DoctorManagementTab> createState() =>
      _DoctorManagementTabState();
}

class _DoctorManagementTabState extends ConsumerState<_DoctorManagementTab> {
  List<DoctorRecord> _doctors = [];
  bool _loading = false;
  String? _error;
  int _doctorSubTab = 1; // 0 = Add Doctor, 1 = View Doctors
  String? _nextDoctorId;
  String? _selectedSpecialtyFilter;

  // Add form state
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  String _selectedSpecialty = 'General Physician';
  String _selectedAvailability = 'Available';
  String _selectedBookingMode = 'BOTH';
  List<AvailabilityRule> _availabilityRules = AvailabilityRule.defaultRules();
  bool _saving = false;
  String? _formError;
  String? _formSuccess;

  static const List<MapEntry<String, String>> _bookingModeOptions = [
    MapEntry('BOTH', 'Slot + Token'),
    MapEntry('SLOT', 'Slot only'),
    MapEntry('TOKEN', 'Token only'),
  ];

  static const List<String> _specialties = [
    'Cardiologist',
    'Neurologist',
    'Orthopedic',
    'Gynecologist',
    'General Physician',
    'Dermatologist',
    'ENT',
    'Ophthalmologist',
    'Psychiatrist',
    'Pediatrician',
    'Urologist',
    'Pulmonologist',
    'Gastroenterologist',
    'Endocrinologist',
    'Oncologist',
    'Radiologist',
    'Anesthesiologist',
    'Pathologist',
    'Rheumatologist',
    'Nephrologist',
    'Skin Specialist',
    'Dentist',
  ];

  static const List<String> _availabilityOptions = [
    'Available',
    'Busy',
    'On Leave',
    'Today',
    'Mon-Fri',
    'Weekends',
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadNextDoctorId();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _feeCtrl.dispose();
    _experienceCtrl.dispose();
    _qualificationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final list = await repo.listDoctorRecords(
        hospital.tenantPublicId,
        auth.token ?? '',
      );
      if (mounted) {
        setState(() {
          _doctors = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load doctors.');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNextDoctorId() async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final id = await repo.getNextDoctorId(
        hospital.tenantPublicId,
        auth.token ?? '',
      );
      if (mounted) setState(() => _nextDoctorId = id);
    } catch (_) {}
  }

  void _resetAddForm() {
    setState(() {
      _formError = null;
      _formSuccess = null;
      _nameCtrl.clear();
      _mobileCtrl.clear();
      _feeCtrl.clear();
      _experienceCtrl.clear();
      _qualificationCtrl.clear();
      _selectedSpecialty = 'General Physician';
      _selectedAvailability = 'Available';
      _selectedBookingMode = 'BOTH';
      _availabilityRules = AvailabilityRule.defaultRules();
      _loadNextDoctorId();
    });
  }

  Future<void> _saveDoctor() async {
    final name = _nameCtrl.text.trim();
    final fee = _feeCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Doctor full name is required.');
      return;
    }
    if (mobile.isEmpty || mobile.length != 10 || int.tryParse(mobile) == null) {
      setState(
        () => _formError =
            'A valid 10-digit mobile number is required. Doctors use it to login.',
      );
      return;
    }
    if (fee.isEmpty) {
      setState(() => _formError = 'Fee is required.');
      return;
    }
    final availabilityError = AvailabilityEditor.validate(_availabilityRules);
    if (availabilityError != null) {
      setState(() => _formError = availabilityError);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Add Doctor',
      message: 'Add "Dr. $name" to this hospital?',
      confirmLabel: 'Add',
      isDanger: false,
    );
    if (!confirmed) return;
    setState(() {
      _saving = true;
      _formError = null;
      _formSuccess = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final created = await repo.createDoctorRecord(
        hospital.tenantPublicId,
        auth.token ?? '',
        DoctorUpsertRequest(
          fullName: name,
          specialty: _selectedSpecialty,
          availability: _selectedAvailability,
          fee: fee,
          active: true,
          mobileNumber: _mobileCtrl.text.trim().isNotEmpty
              ? _mobileCtrl.text.trim()
              : null,
          bookingMode: _selectedBookingMode,
          experienceYears: int.tryParse(_experienceCtrl.text.trim()),
          qualification: _qualificationCtrl.text.trim().isEmpty
              ? null
              : _qualificationCtrl.text.trim(),
        ),
      );
      try {
        await repo.updateDoctorWorkingHours(
          hospital.tenantPublicId,
          created.doctorPublicId,
          auth.token ?? '',
          _availabilityRules.map((r) => r.toJson()).toList(),
        );
      } catch (_) {
        // Non-fatal — the doctor already has the backend's default working
        // hours backfilled; they (or admin) can adjust later from Profile.
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _formSuccess = 'Doctor record created successfully.';
          _doctorSubTab = 1;
          _selectedSpecialtyFilter = _selectedSpecialty;
        });
        await _loadDoctors();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = extractErrorMessage(
            e,
            fallback: 'Failed to create doctor record.',
          );
        });
      }
    }
  }

  Future<void> _deleteDoctor(String doctorId, String doctorName) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Doctor',
      message:
          'Remove "Dr. $doctorName" from this hospital? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.deleteDoctorRecord(
        hospital.tenantPublicId,
        doctorId,
        auth.token ?? '',
      );
      await _loadDoctors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: SevaCareColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _updateDoctorAvailability(
    DoctorRecord doctor,
    String newAvailability,
  ) async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.upsertDoctorRecord(
        hospital.tenantPublicId,
        doctor.doctorPublicId,
        auth.token ?? '',
        DoctorUpsertRequest(
          fullName: doctor.fullName,
          specialty: doctor.specialty,
          availability: newAvailability,
          fee: doctor.fee,
          active: doctor.active,
          age: doctor.age,
          address: doctor.address,
          aboutMe: doctor.aboutMe,
          experience: doctor.experience,
          mobileNumber: doctor.mobileNumber,
          email: doctor.email,
          bookingMode: doctor.bookingMode,
          experienceYears: doctor.experienceYears,
          qualification: doctor.qualification,
        ),
      );
      await _loadDoctors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doctor.fullName} marked as $newAvailability.'),
            backgroundColor: newAvailability == 'On Leave'
                ? SevaCareColors.peach
                : SevaCareColors.mint,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: SevaCareColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _cycleBookingMode(DoctorRecord doctor) async {
    const cycle = ['BOTH', 'SLOT', 'TOKEN'];
    final next = cycle[(cycle.indexOf(doctor.bookingMode) + 1) % cycle.length];
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.upsertDoctorRecord(
        hospital.tenantPublicId,
        doctor.doctorPublicId,
        auth.token ?? '',
        DoctorUpsertRequest(
          fullName: doctor.fullName,
          specialty: doctor.specialty,
          availability: doctor.availability,
          fee: doctor.fee,
          active: doctor.active,
          age: doctor.age,
          address: doctor.address,
          aboutMe: doctor.aboutMe,
          experience: doctor.experience,
          mobileNumber: doctor.mobileNumber,
          email: doctor.email,
          bookingMode: next,
          experienceYears: doctor.experienceYears,
          qualification: doctor.qualification,
        ),
      );
      await _loadDoctors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${doctor.fullName} booking mode set to ${_bookingModeLabel(next)}.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: SevaCareColors.danger,
          ),
        );
      }
    }
  }

  String _bookingModeLabel(String mode) => switch (mode) {
    'SLOT' => 'Slot only',
    'TOKEN' => 'Token only',
    _ => 'Slot + Token',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedControl<int>(
          items: const [
            SegmentItem<int>(
              value: 0,
              label: 'Add Doctor',
              icon: Icons.person_add_outlined,
            ),
            SegmentItem<int>(
              value: 1,
              label: 'View Doctors',
              icon: Icons.groups_outlined,
            ),
          ],
          selected: _doctorSubTab,
          onChanged: (v) {
            setState(() => _doctorSubTab = v);
            if (v == 0) _resetAddForm();
          },
        ),
        const SizedBox(height: 16),
        if (_doctorSubTab == 0) _buildAddDoctorForm() else _buildViewDoctors(),
      ],
    );
  }

  Widget _buildAddDoctorForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Doctor',
            style: AppTextStyles.sectionTitle(SevaCareColors.text),
          ),
          if (_nextDoctorId != null) ...[
            const SizedBox(height: 4),
            Text(
              'ID: $_nextDoctorId',
              style: AppTextStyles.label(SevaCareColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          AppFormField(
            label: 'Doctor Full Name',
            controller: _nameCtrl,
            required: true,
            placeholder: 'Dr. Full Name',
          ),
          AppDropdown<String>(
            label: 'Specialty',
            value: _selectedSpecialty,
            required: true,
            items: _specialties
                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedSpecialty = v);
            },
          ),
          AppFormField(
            label: 'Mobile Number',
            controller: _mobileCtrl,
            required: true,
            placeholder: '10-digit mobile (used for doctor login)',
            keyboardType: TextInputType.phone,
          ),
          AppFormField(
            label: 'Fee',
            controller: _feeCtrl,
            required: true,
            placeholder: '₹500',
          ),
          AppDropdown<String>(
            label: 'Availability',
            value: _selectedAvailability,
            items: _availabilityOptions
                .map((a) => DropdownMenuItem<String>(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedAvailability = v);
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppFormField(
                  label: 'Years of Experience',
                  controller: _experienceCtrl,
                  placeholder: 'e.g. 10',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          AppFormField(
            label: 'Qualification',
            controller: _qualificationCtrl,
            placeholder: 'e.g. MS Cardiology, USA',
          ),
          AppDropdown<String>(
            label: 'Booking Mode',
            value: _selectedBookingMode,
            items: _bookingModeOptions
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedBookingMode = v);
            },
          ),
          const SizedBox(height: 8),
          Text('Availability', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
          const SizedBox(height: 4),
          Text(
            'Default working hours — the doctor can adjust these later from their own Profile.',
            style: AppTextStyles.label(SevaCareColors.textMuted),
          ),
          const SizedBox(height: 10),
          AvailabilityEditor(
            initialRules: _availabilityRules,
            onChanged: (rules) => setState(() => _availabilityRules = rules),
          ),
          if (_formError != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SevaCareColors.errorSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formError!,
                style: AppTextStyles.bodyText(SevaCareColors.danger),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_formSuccess != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SevaCareColors.successSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formSuccess!,
                style: AppTextStyles.bodyText(SevaCareColors.mintForeground),
              ),
            ),
            const SizedBox(height: 8),
          ],
          PrimaryButton(
            label: 'Save Doctor',
            isLoading: _saving,
            onPressed: _saving ? null : _saveDoctor,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildViewDoctors() {
    if (_loading && _doctors.isEmpty) return const ShimmerList(count: 3);

    if (_error != null) {
      return AppCard(
        child: Column(
          children: [
            Text(
              'Error loading doctors',
              style: AppTextStyles.cardTitle(SevaCareColors.danger),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Retry', onPressed: _loadDoctors),
          ],
        ),
      );
    }

    if (_selectedSpecialtyFilter == null) {
      final counts = <String, int>{};
      for (final d in _doctors) {
        counts[d.specialty] = (counts[d.specialty] ?? 0) + 1;
      }
      final specialties = counts.keys.toList()..sort();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Browse by specialty',
                  style: AppTextStyles.sectionTitle(SevaCareColors.text),
                ),
              ),
              IconBtn(
                icon: Icons.refresh,
                tooltip: 'Refresh',
                onPressed: _loading ? null : _loadDoctors,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (specialties.isEmpty)
            AppCard(
              child: Text(
                'No doctors found. Use "Add Doctor" to create one.',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: specialties.map((s) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedSpecialtyFilter = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: SevaCareColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SevaCareColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          size: 16,
                          color: SevaCareColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s,
                          style: AppTextStyles.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: SevaCareColors.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SevaCareColors.primarySoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${counts[s]}',
                            style: AppTextStyles.label(SevaCareColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      );
    }

    final filteredDoctors = _doctors
        .where((d) => d.specialty == _selectedSpecialtyFilter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedSpecialtyFilter = null),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: SevaCareColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'All specialties',
                    style: AppTextStyles.label(SevaCareColors.primary),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconBtn(
              icon: Icons.refresh,
              tooltip: 'Refresh',
              onPressed: _loading ? null : _loadDoctors,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selectedSpecialtyFilter!,
          style: AppTextStyles.sectionTitle(SevaCareColors.text),
        ),
        const SizedBox(height: 12),
        if (filteredDoctors.isEmpty)
          AppCard(
            child: Text(
              'No doctors found for this specialty.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          )
        else
          Column(
            children: [
              for (final doctor in filteredDoctors) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DoctorPhoto.circle(
                            doctorId: doctor.doctorPublicId,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.doctorPublicId,
                                  style: AppTextStyles.label(
                                    SevaCareColors.textMuted,
                                  ),
                                ),
                                Text(
                                  doctor.fullName,
                                  style: AppTextStyles.cardTitle(
                                    SevaCareColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SevaCareColors.primarySoft,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        doctor.specialty,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.label(
                                          SevaCareColors.primary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      doctor.fee,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.body(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: SevaCareColors.peachForeground,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Availability: ${doctor.availability}',
                                  style: AppTextStyles.bodyText(
                                    SevaCareColors.textMuted,
                                  ),
                                ),
                                Text(
                                  'Mobile: ${doctor.mobileNumber ?? 'Not set'}',
                                  style: AppTextStyles.bodyText(
                                    SevaCareColors.textMuted,
                                  ),
                                ),
                                if (doctor.experienceYears != null ||
                                    (doctor.qualification?.isNotEmpty ?? false))
                                  Text(
                                    [
                                      if (doctor.experienceYears != null)
                                        '${doctor.experienceYears}y Exp',
                                      if (doctor.qualification?.isNotEmpty ??
                                          false)
                                        doctor.qualification,
                                    ].join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyText(
                                      SevaCareColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            status: doctor.active ? 'active' : 'inactive',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Quick availability toggle
                          if (doctor.availability != 'On Leave')
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _updateDoctorAvailability(
                                  doctor,
                                  'On Leave',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4EE),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: SevaCareColors.peach.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.event_busy_outlined,
                                        size: 13,
                                        color: SevaCareColors.peach,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Mark Leave',
                                        style: AppTextStyles.label(
                                          SevaCareColors.peach,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _updateDoctorAvailability(
                                  doctor,
                                  'Available',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SevaCareColors.mintSoft,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: SevaCareColors.mint.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.event_available_outlined,
                                        size: 13,
                                        color: SevaCareColors.mint,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Mark Available',
                                        style: AppTextStyles.label(
                                          SevaCareColors.mintForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: () => _cycleBookingMode(doctor),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: SevaCareColors.primarySoft,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: SevaCareColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.confirmation_number_outlined,
                                    size: 13,
                                    color: SevaCareColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _bookingModeLabel(doctor.bookingMode),
                                    style: AppTextStyles.label(
                                      SevaCareColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconBtn(
                            icon: Icons.delete_outline,
                            iconColor: SevaCareColors.danger,
                            bgColor: SevaCareColors.errorSurface,
                            tooltip: 'Delete doctor',
                            onPressed: () => _deleteDoctor(
                              doctor.doctorPublicId,
                              doctor.fullName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

// ── TAB 3: Reports ────────────────────────────────────────────────────────────

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  AdminOverview? _overview;
  bool _loading = true;
  String? _error;
  int _timeFilter = 1; // 0=Today, 1=Week, 2=Month, 3=Year

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
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final overview = await repo.getAdminOverview(
        hospital.tenantPublicId,
        auth.token ?? '',
      );
      if (mounted) {
        setState(() {
          _overview = overview;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load reports.');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return AppCard(
        child: Column(
          children: [
            Text(
              'Failed to load reports',
              style: AppTextStyles.cardTitle(SevaCareColors.danger),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Retry', onPressed: _load),
          ],
        ),
      );
    }

    final ov = _overview;
    final totalVisits =
        int.tryParse(
          ov?.metrics.isNotEmpty == true ? ov!.metrics[0].value : '0',
        ) ??
        0;
    final upcoming =
        int.tryParse(
          ov != null && ov.metrics.length > 1 ? ov.metrics[1].value : '0',
        ) ??
        0;
    final completed =
        int.tryParse(
          ov != null && ov.metrics.length > 2 ? ov.metrics[2].value : '0',
        ) ??
        0;

    // Estimate revenue: completed visits × average fee (₹500 baseline)
    const avgFee = 500;
    final estRevenue = completed * avgFee;
    final revenueLabel = estRevenue >= 1000
        ? '₹${(estRevenue / 1000).toStringAsFixed(1)}K'
        : '₹$estRevenue';

    final periods = ['Today', 'This Week', 'This Month', 'This Year'];
    final filterSegments = periods
        .asMap()
        .entries
        .map((e) => SegmentItem<int>(value: e.key, label: e.value))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clinic Performance',
          style: AppTextStyles.sectionTitle(SevaCareColors.text),
        ),
        const SizedBox(height: 12),
        SegmentedControl<int>(
          items: filterSegments,
          selected: _timeFilter,
          onChanged: (v) => setState(() => _timeFilter = v),
        ),
        const SizedBox(height: 16),

        // Revenue highlight card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4A42CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Est. Revenue',
                      style: AppTextStyles.label(
                        Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      revenueLabel,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${periods[_timeFilter]}  ·  $completed completed visits × ₹$avgFee avg',
                      style: AppTextStyles.label(
                        Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.currency_rupee,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Appointment metrics
        GridView.count(
          crossAxisCount: columnsForWidth(
            MediaQuery.sizeOf(context).width,
            mobileCols: 2,
            tabletCols: 4,
            desktopCols: 4,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            _MicroCard(
              icon: Icons.people_alt_rounded,
              label: 'Total Visits',
              value: totalVisits.toString(),
              sub: periods[_timeFilter].toLowerCase(),
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            _MicroCard(
              icon: Icons.schedule_rounded,
              label: 'Upcoming',
              value: upcoming.toString(),
              sub: 'booked ahead',
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            _MicroCard(
              icon: Icons.check_circle_rounded,
              label: 'Completed',
              value: completed.toString(),
              sub: 'visits done',
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            _MicroCard(
              icon: Icons.pie_chart_rounded,
              label: 'Completion',
              value:
                  '${totalVisits > 0 ? ((completed / totalVisits) * 100).toStringAsFixed(0) : 0}%',
              sub: 'of total visits',
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Clinic health tips section
        Text(
          'Clinic Insights · ${periods[_timeFilter]}',
          style: AppTextStyles.sectionTitle(SevaCareColors.text),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: _AppointmentBreakdownChart(
            total: totalVisits,
            upcoming: upcoming,
            completed: completed,
          ),
        ),
        const SizedBox(height: 12),

        // Tip card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SevaCareColors.mintSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SevaCareColors.mint.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: SevaCareColors.mint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Revenue shown is an estimate. Update each doctor\'s fee in the Doctors tab for accurate reporting.',
                  style: AppTextStyles.bodyText(SevaCareColors.mintForeground),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Visual appointment breakdown (donut) — replaces the old text table ───────

class _AppointmentBreakdownChart extends StatelessWidget {
  final int total;
  final int upcoming;
  final int completed;
  const _AppointmentBreakdownChart({
    required this.total,
    required this.upcoming,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final other = (total - upcoming - completed).clamp(0, total);
    final pct = total > 0 ? ((completed / total) * 100).round() : 0;

    if (total == 0) {
      return Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 32, color: SevaCareColors.border),
          const SizedBox(height: 10),
          Text(
            'No appointments in this period yet',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 38,
                  sections: [
                    PieChartSectionData(
                      value: completed.toDouble(),
                      color: SevaCareColors.mint,
                      title: '',
                      radius: 20,
                    ),
                    PieChartSectionData(
                      value: upcoming.toDouble(),
                      color: SevaCareColors.primary,
                      title: '',
                      radius: 20,
                    ),
                    if (other > 0)
                      PieChartSectionData(
                        value: other.toDouble(),
                        color: SevaCareColors.border,
                        title: '',
                        radius: 20,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pct%',
                    style: AppTextStyles.display(
                      size: 22,
                      weight: FontWeight.w800,
                      color: SevaCareColors.text,
                    ),
                  ),
                  Text(
                    'done',
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendRow(
                color: SevaCareColors.mint,
                label: 'Completed',
                value: completed,
              ),
              const SizedBox(height: 10),
              _LegendRow(
                color: SevaCareColors.primary,
                label: 'Upcoming',
                value: upcoming,
              ),
              if (other > 0) ...[
                const SizedBox(height: 10),
                _LegendRow(
                  color: SevaCareColors.border,
                  label: 'Cancelled / other',
                  value: other,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
          ),
        ),
        Text('$value', style: AppTextStyles.cardTitle(SevaCareColors.text)),
      ],
    );
  }
}

// ── TAB 4: Staff Management ───────────────────────────────────────────────────

class _StaffManagementTab extends ConsumerStatefulWidget {
  const _StaffManagementTab();

  @override
  ConsumerState<_StaffManagementTab> createState() =>
      _StaffManagementTabState();
}

class _StaffManagementTabState extends ConsumerState<_StaffManagementTab> {
  List<AdminUserRecord> _staff = [];
  List<StaffBookingStat> _stats = [];
  bool _loading = false;
  bool _loadingStats = false;
  String? _error;
  bool _showAddForm = false;
  bool _saving = false;
  String? _formError;
  String? _formSuccess;
  int _statsPeriod = 1; // 0=Today 1=Week 2=Month 3=Year

  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStaff();
      _loadStats();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final list = await ref
          .read(repositoryProvider)
          .listStaff(hospital.tenantPublicId, auth.token ?? '');
      if (mounted) {
        list.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
        setState(() {
          _staff = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load staff.');
          _loading = false;
        });
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final stats = await ref
          .read(repositoryProvider)
          .getStaffBookingStats(hospital.tenantPublicId, auth.token ?? '');
      if (mounted)
        setState(() {
          _stats = stats;
          _loadingStats = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _saveStaff() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Name is required.');
      return;
    }
    if (mobile.isEmpty || mobile.length < 10) {
      setState(() => _formError = 'Valid 10-digit mobile number is required.');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Add Staff',
      message:
          'Add "$name" as IP-Staff? They will be able to log in with mobile $mobile.',
      confirmLabel: 'Add',
      isDanger: false,
    );
    if (!confirmed) return;

    setState(() {
      _saving = true;
      _formError = null;
      _formSuccess = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      await ref
          .read(repositoryProvider)
          .createStaff(
            hospital.tenantPublicId,
            auth.token ?? '',
            AdminUserUpsertRequest(
              fullName: name,
              mobileNumber: mobile,
              userType: 'STAFF',
            ),
          );
      if (mounted) {
        _nameCtrl.clear();
        _mobileCtrl.clear();
        setState(() {
          _formSuccess =
              'Staff member "$name" added. They can now log in with mobile $mobile.';
          _showAddForm = false;
          _saving = false;
        });
        await _loadStaff();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _formError = extractErrorMessage(e, fallback: 'Failed to add staff.');
          _saving = false;
        });
    }
  }

  Future<void> _deactivate(AdminUserRecord s) async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      await ref
          .read(repositoryProvider)
          .deactivateStaff(
            hospital.tenantPublicId,
            s.adminPublicId,
            auth.token ?? '',
          );
      if (mounted) await _loadStaff();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = extractErrorMessage(
            e,
            fallback: 'Failed to deactivate.',
          ),
        );
    }
  }

  Future<void> _delete(AdminUserRecord s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text(
          'Remove "${s.fullName}" (${s.mobileNumber ?? ''}) from staff? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      await ref
          .read(repositoryProvider)
          .deleteStaff(
            hospital.tenantPublicId,
            s.adminPublicId,
            auth.token ?? '',
          );
      if (mounted) await _loadStaff();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = extractErrorMessage(
            e,
            fallback: 'Failed to remove staff.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'IP-Staff',
          subtitle:
              'Manage hospital staff who can register patients and book appointments.',
        ),
        const SizedBox(height: 16),

        // Success / error banners
        if (_formSuccess != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SevaCareColors.mintSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: SevaCareColors.mint.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: SevaCareColors.mint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formSuccess!,
                    style: AppTextStyles.label(SevaCareColors.mintForeground),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _formSuccess = null),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: SevaCareColors.mintForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SevaCareColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: SevaCareColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _error!,
              style: AppTextStyles.label(SevaCareColors.danger),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Add Staff button / form
        if (!_showAddForm)
          PrimaryButton(
            label: 'Add Staff Member',
            icon: Icons.person_add_outlined,
            fullWidth: true,
            onPressed: () => setState(() {
              _showAddForm = true;
              _formError = null;
            }),
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: SevaCareColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Staff Member',
                      style: AppTextStyles.sectionTitle(SevaCareColors.text),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() {
                        _showAddForm = false;
                        _formError = null;
                        _nameCtrl.clear();
                        _mobileCtrl.clear();
                      }),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: SevaCareColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  placeholder: 'e.g. Ravi Kumar',
                ),
                AppFormField(
                  label: 'Mobile Number',
                  controller: _mobileCtrl,
                  placeholder: '10-digit mobile',
                  keyboardType: TextInputType.phone,
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formError!,
                    style: AppTextStyles.label(SevaCareColors.danger),
                  ),
                ],
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Add Staff',
                  icon: Icons.check_rounded,
                  isLoading: _saving,
                  fullWidth: true,
                  onPressed: _saving ? null : _saveStaff,
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // ── Booking Metrics Section ────────────────────────────────────────
        if (_loadingStats)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_stats.isNotEmpty) ...[
          Text(
            'Staff Booking Metrics',
            style: AppTextStyles.sectionTitle(SevaCareColors.text),
          ),
          const SizedBox(height: 8),
          SegmentedControl<int>(
            items: const [
              SegmentItem(value: 0, label: 'Today'),
              SegmentItem(value: 1, label: 'Week'),
              SegmentItem(value: 2, label: 'Month'),
              SegmentItem(value: 3, label: 'Year'),
            ],
            selected: _statsPeriod,
            onChanged: (v) => setState(() => _statsPeriod = v),
          ),
          const SizedBox(height: 10),
          ..._stats.map((stat) {
            final count = switch (_statsPeriod) {
              0 => stat.todayCount,
              1 => stat.weekCount,
              2 => stat.monthCount,
              _ => stat.yearCount,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: SevaCareColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          stat.staffName.isNotEmpty
                              ? stat.staffName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: SevaCareColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.staffName,
                            style: AppTextStyles.cardTitle(SevaCareColors.text),
                          ),
                          if (stat.mobileNumber != null)
                            Text(
                              stat.mobileNumber!,
                              style: AppTextStyles.label(
                                SevaCareColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: count > 0
                                ? SevaCareColors.primary
                                : SevaCareColors.textMuted,
                          ),
                        ),
                        Text(
                          'bookings',
                          style: AppTextStyles.label(SevaCareColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Staff list
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_staff.isEmpty)
          AppCard(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Icon(
                  Icons.badge_outlined,
                  size: 48,
                  color: SevaCareColors.textMuted.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'No staff registered yet',
                  style: AppTextStyles.sectionTitle(SevaCareColors.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add a staff member above so they can log in as IP-Staff and help patients book appointments.',
                  style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          )
        else ...[
          Text(
            '${_staff.length} staff member${_staff.length == 1 ? '' : 's'}',
            style: AppTextStyles.label(SevaCareColors.textMuted),
          ),
          const SizedBox(height: 8),
          ..._staff.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StaffTile(
                staff: s,
                onDeactivate: () => _deactivate(s),
                onDelete: () => _delete(s),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StaffTile extends StatelessWidget {
  final AdminUserRecord staff;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;

  const _StaffTile({
    required this.staff,
    required this.onDeactivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Opacity(
            opacity: staff.active ? 1.0 : 0.45,
            child: StaffPhoto.circle(
              userId: staff.adminPublicId,
              size: 42,
              isStaff: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.fullName,
                  style: AppTextStyles.cardTitle(SevaCareColors.text),
                ),
                if (staff.mobileNumber != null &&
                    staff.mobileNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    staff.mobileNumber!,
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: staff.active
                        ? SevaCareColors.mint.withValues(alpha: 0.15)
                        : SevaCareColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    staff.active ? 'Active · Can login' : 'Inactive',
                    style: AppTextStyles.badgeText(
                      staff.active
                          ? SevaCareColors.mintForeground
                          : SevaCareColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (staff.active)
                GestureDetector(
                  onTap: onDeactivate,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.block_outlined,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: SevaCareColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: SevaCareColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
