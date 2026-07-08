import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/time_theme.dart';
import '../../core/utils/auto_refresh.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';
import 'queue_board_screen.dart';

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

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen>
    with AutoRefreshMixin {
  // Day offset: -1 = Yesterday, 0 = Today, 1 = Tomorrow
  int _dayOffset = 0;
  DoctorQueueDayView? _queueView;
  bool _loading = false;
  String? _error;
  int _queueFilter = 1; // 1=Upcoming (default), 2=Completed, 0=All
  int _pendingBookingRequests = 0;
  final _scrollCtrl = ScrollController();

  // Caches each day's queue by offset so hopping between Yesterday/Today/
  // Tomorrow doesn't re-fetch (and re-flash a loading spinner) every time —
  // only a day that's never been successfully loaded triggers a fetch.
  final Map<int, DoctorQueueDayView> _queueCache = {};

  @override
  void initState() {
    super.initState();
    _loadQueue();
    _loadBookingRequestCount();
    // Near-real-time queue: silently refetch the visible day + request badge.
    startAutoRefresh(() async {
      _queueCache.remove(_dayOffset);
      await _loadQueue(silent: true);
      await _loadBookingRequestCount();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Fetches the count of pending QR booking requests for the badge. Best-effort:
  /// failures are swallowed so the dashboard never breaks over the badge.
  Future<void> _loadBookingRequestCount() async {
    try {
      final auth = ref.read(authProvider);
      final data = await ref.read(repositoryProvider).getDoctorAppointmentRequests(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            auth.token ?? '',
          );
      if (mounted) setState(() => _pendingBookingRequests = data.pendingCount);
    } catch (_) {
      // ignore — badge simply won't show
    }
  }

  String get _selectedDate => AppDateUtils.offsetDay(_dayOffset);

  Future<void> _loadQueue({bool silent = false}) async {
    final requestedOffset = _dayOffset;
    final cached = silent ? null : _queueCache[requestedOffset];
    if (cached != null) {
      // Already fetched this day this session — swap instantly, no spinner.
      setState(() {
        _queueView = cached;
        _loading = false;
        _error = null;
      });
      return;
    }
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
      final doctorId = auth.subjectPublicId ?? '';
      final view = await repo.getDoctorQueue(
        hospital.tenantPublicId,
        doctorId,
        _selectedDate,
        auth.token ?? '',
      );
      _queueCache[requestedOffset] = view;
      // Ignore if the user already switched to a different day while this
      // fetch was in flight — don't clobber the day they're now looking at.
      if (mounted && _dayOffset == requestedOffset) {
        setState(() {
          _queueView = view;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && _dayOffset == requestedOffset && !silent) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load patient queue.');
          _loading = false;
        });
      }
    }
  }

  void _changeDay(int newOffset) {
    setState(() => _dayOffset = newOffset);
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    _loadQueue();
  }

  // Upcoming (and next-up) surfaces above completed, ordered by token/slot —
  // so whoever's next is always the first card, regardless of tab.
  static int _statusRank(DoctorQueueFacetView f) {
    final s = f.status.toLowerCase();
    if (s == 'upcoming') return 0;
    if (s == 'completed') return 1;
    return 2;
  }

  List<DoctorQueueFacetView> get _filteredFacets {
    final facets = _queueView?.facets ?? [];
    List<DoctorQueueFacetView> base;
    switch (_queueFilter) {
      case 1:
        base = facets.where((f) => f.status.toLowerCase() == 'upcoming').toList();
        break;
      case 2:
        base = facets.where((f) => f.status.toLowerCase() == 'completed').toList();
        break;
      default:
        base = List<DoctorQueueFacetView>.from(facets);
    }
    base.sort((a, b) {
      final rankDiff = _statusRank(a).compareTo(_statusRank(b));
      if (rankDiff != 0) return rankDiff;
      if (a.bookingType == 'TOKEN' && b.bookingType == 'TOKEN') {
        return (a.tokenNumber ?? 0).compareTo(b.tokenNumber ?? 0);
      }
      return a.slot.compareTo(b.slot);
    });
    return base;
  }

  void _handleNavTap(int index) {
    final items = _doctorNavItems();
    if (index < items.length) {
      context.go(items[index].route);
    }
  }

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
      SegmentItem<int>(value: -1, label: tr(ref, 'Yesterday')),
      SegmentItem<int>(value: 0, label: tr(ref, 'Today')),
      SegmentItem<int>(value: 1, label: tr(ref, 'Tomorrow')),
    ];

    final queueFilterSegments = [
      SegmentItem<int>(value: 1, label: tr(ref, 'Upcoming')),
      SegmentItem<int>(value: 2, label: tr(ref, 'Completed')),
      SegmentItem<int>(value: 0, label: tr(ref, 'All')),
    ];

    final queueView = _queueView;
    final filteredFacets = _filteredFacets;

    return AppShell(
      hospitalName: hospital.hospitalName.isNotEmpty ? hospital.hospitalName : 'SevaCare',
      role: UserRole.doctor,
      bottomNavItems: _doctorNavItems(),
      currentNavIndex: 0,
      onNavTap: _handleNavTap,
      // Fixed-frame layout: hero, day selector and Previous/Next stay pinned;
      // only the metrics + queue region below scrolls. Switching days or
      // queue filters swaps that region in place — the frame never moves.
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Animated doctor hero banner ──────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: SevaCareColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  const AnimatedHealthcareBg(
                    variant: HealthcareBgVariant.doctor,
                    height: 130,
                  ),
                  const Positioned.fill(child: TimeTintOverlay()),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        AppAvatar(
                          initials: _initials(subjectId.isNotEmpty ? subjectId : 'Dr'),
                          hue: AppAvatar.hueFromString(subjectId),
                          size: 60,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${tr(ref, _greetingKey())}, Doctor',
                                style: AppTextStyles.label(
                                  SevaCareColors.textOnPrimary.withValues(alpha: 0.80),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subjectId,
                                style: AppTextStyles.cardTitle(SevaCareColors.textOnPrimary),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: SevaCareColors.mint.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6, height: 6,
                                          decoration: const BoxDecoration(
                                            color: SevaCareColors.mint,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          tr(ref, 'Available'),
                                          style: AppTextStyles.label(SevaCareColors.mint),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => showSlotBlockSheet(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.event_busy_rounded,
                                              size: 11, color: Colors.white),
                                          const SizedBox(width: 5),
                                          Text(
                                            tr(ref, 'Block slots'),
                                            style: AppTextStyles.label(Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push('/doctor/queue-board'),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: const Icon(Icons.tv_rounded,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
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
          const SizedBox(height: 20),

          // ── QR Booking Requests entry (only when there's something new) ─────
          if (_pendingBookingRequests > 0) ...[
            _BookingRequestsCard(
              pendingCount: _pendingBookingRequests,
              onTap: () async {
                await context.push('/doctor/booking-requests');
                _loadBookingRequestCount();
              },
            ),
            const SizedBox(height: 16),
          ],

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
                        tr(ref, 'Previous'),
                        style: AppTextStyles.label(const Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _timelineLabel(_selectedDate),
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
                        tr(ref, 'Next'),
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

          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // ── Metrics ──────────────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(_loading ? 'loading' : (_error ?? 'data-$_dayOffset')),
              child: _loading
                  ? const ShimmerList(count: 3, cardHeight: 80)
                  : const SizedBox.shrink(),
            ),
          ),
          if (!_loading && _error != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(ref, 'Failed to load queue'), style: AppTextStyles.cardTitle(SevaCareColors.danger)),
                  const SizedBox(height: 8),
                  Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                  const SizedBox(height: 12),
                  PrimaryButton(label: tr(ref, 'Retry'), onPressed: _loadQueue),
                ],
              ),
            ),
          ],
          if (!_loading && _error == null) ...[
            if (queueView != null && computeQueueStates(queueView.facets).isNotEmpty) ...[
              _NowServingStrip(states: computeQueueStates(queueView.facets)),
              const SizedBox(height: 16),
            ],
            MetricRow(
              tiles: [
                MetricTile(
                  value: '${queueView?.totalAppointments ?? 0}',
                  label: tr(ref, 'Appointments'),
                  variant: MetricVariant.primary,
                ),
                MetricTile(
                  value: '${queueView?.pendingNotes ?? 0}',
                  label: tr(ref, 'Pending'),
                  variant: MetricVariant.peach,
                ),
                MetricTile(
                  value: '${queueView?.avgConsultMinutes ?? 0}m',
                  label: tr(ref, 'Avg'),
                  variant: MetricVariant.mint,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Patient Queue ────────────────────────────────────────────────
            Text(tr(ref, 'Patient Queue'), style: AppTextStyles.sectionTitle(SevaCareColors.text)),
            const SizedBox(height: 12),
            SegmentedControl<int>(
              items: queueFilterSegments,
              selected: _queueFilter,
              onChanged: (v) {
                setState(() => _queueFilter = v);
                if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
              },
            ),
            const SizedBox(height: 12),

            if (filteredFacets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.self_improvement_rounded, size: 32, color: SevaCareColors.border),
                      const SizedBox(height: 10),
                      Text(
                        tr(ref, "You're free! Lighter day today"),
                        style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final (index, facet) in filteredFacets.indexed) ...[
                    Builder(builder: (context) {
                      final isUpNext = facet.status.toLowerCase() == 'upcoming' &&
                          (index == 0 || filteredFacets[index - 1].status.toLowerCase() != 'upcoming');
                      return AccentCard(
                      variant: MetricVariant.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isUpNext) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: SevaCareColors.mint,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('UP NEXT', style: AppTextStyles.label(Colors.white).copyWith(fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
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
                                      facet.tokenNumber != null
                                          ? (facet.bookingType == 'TOKEN'
                                              ? 'Token #${facet.tokenNumber} · ${facet.tokenSession == 'EVENING' ? 'Evening' : 'Morning'}'
                                              : 'Token #${facet.tokenNumber} · ${AppDateUtils.formatSlot(facet.slot)}')
                                          : AppDateUtils.formatSlot(facet.slot),
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
                          if (facet.medicines.isNotEmpty || facet.followUp ||
                              facet.bookingSource == 'IP_STAFF' || facet.isQrBooking) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (facet.bookingSource == 'IP_STAFF')
                                  _Chip(
                                    label: tr(ref, 'IP-Staff Booking'),
                                    color: const Color(0xFFFFF4EE),
                                    textColor: SevaCareColors.peachForeground,
                                  ),
                                if (facet.isQrBooking)
                                  _Chip(
                                    label: tr(ref, 'QR Booking'),
                                    color: SevaCareColors.primarySoft,
                                    textColor: SevaCareColors.primary,
                                  ),
                                if (facet.medicines.isNotEmpty)
                                  _Chip(
                                    label: '${facet.medicines.length} medicine(s)',
                                    color: SevaCareColors.primarySoft,
                                    textColor: SevaCareColors.primary,
                                  ),
                                if (facet.followUp)
                                  _Chip(
                                    label: tr(ref, 'Follow-up'),
                                    color: SevaCareColors.peachSoft,
                                    textColor: SevaCareColors.peachForeground,
                                  ),
                              ],
                            ),
                          ],

                          if (facet.status.toLowerCase() != 'completed') ...[
                            const SizedBox(height: 12),
                            SecondaryButton(
                              label: tr(ref, 'Start Consult'),
                              icon: Icons.healing,
                              onPressed: () {
                                ref.read(doctorSelectedPatientIdProvider.notifier).state =
                                    facet.patientPublicId;
                                ref.read(doctorSelectedAppointmentIdProvider.notifier).state =
                                    facet.appointmentPublicId;
                                ref.read(doctorSelectedFacetProvider.notifier).state = facet;
                                context.go('/doctor/consult');
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                    }),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
                ],
              ),
            ),
          ),
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

// ── QR Booking Requests entry card ──────────────────────────────────────────────

class _BookingRequestsCard extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;

  const _BookingRequestsCard({required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SevaCareColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: SevaCareColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '$pendingCount new QR booking${pendingCount == 1 ? '' : 's'}',
                style: AppTextStyles.cardTitle(SevaCareColors.text),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$pendingCount', style: AppTextStyles.badgeText(Colors.white)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: SevaCareColors.textMuted, size: 20),
          ],
        ),
      ),
    );
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

// ── Now Serving strip (compact preview of the live queue board) ───────────────

class _NowServingStrip extends ConsumerWidget {
  final List<SessionQueueState> states;
  const _NowServingStrip({required this.states});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return GestureDetector(
      onTap: () => context.push('/queue/control', extra: {
        'doctorPublicId': auth.subjectPublicId ?? '',
        'doctorName': auth.subjectName.isNotEmpty ? auth.subjectName : 'My queue',
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: SevaCareColors.heroGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.tv_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(ref, 'NOW SERVING'),
                      style: AppTextStyles.label(Colors.white.withValues(alpha: 0.75))),
                  const SizedBox(height: 2),
                  Text(
                    states
                        .map((s) => '#${s.nowServing ?? '-'} ${s.session == 'EVENING' ? '(Eve)' : '(Morn)'}')
                        .join('  ·  '),
                    style: AppTextStyles.cardTitle(Colors.white),
                  ),
                ],
              ),
            ),
            Text(tr(ref, 'Open board'), style: AppTextStyles.label(Colors.white.withValues(alpha: 0.85))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
