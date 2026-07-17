import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/time_theme.dart';
import '../../core/utils/app_snack.dart';
import '../../core/utils/auto_refresh.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../repositories/sevacare_repository.dart' show newIdempotencyKey;
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// ── Root screen ───────────────────────────────────────────────────────────────

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  int _tab = 0;

  // When staff taps "Book" on a patient card, pre-fill booking form
  PatientRecord? _prefillPatient;

  static const _bottomNav = [
    BottomNavItem(
      label: 'Portal',
      icon: Icons.dashboard_outlined,
      route: '/staff',
    ),
    BottomNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      route: '/staff/profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureCapabilities);
  }

  /// Learn what this tenant is, so the Pharmacy shortcut shows for a store's
  /// staff and a pharmacy-only tenant reached after a biometric restore hands
  /// straight over to the counter.
  Future<void> _ensureCapabilities() async {
    final auth = ref.read(authProvider);
    if (auth.capabilities != null || auth.token == null || auth.tenantPublicId == null) return;
    try {
      final caps = await ref.read(repositoryProvider).getCapabilities(auth.tenantPublicId!, auth.token!);
      if (!mounted) return;
      ref.read(authProvider.notifier).setCapabilities(caps);
      if (caps.isPharmacyOnly) context.go('/pharmacy');
    } catch (_) {/* shortcut stays hidden */}
  }

  void _bookForExistingPatient(PatientRecord p) {
    setState(() {
      _prefillPatient = p;
      _tab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hospital = ref.watch(hospitalProvider);

    // Fixed-frame layout: the hero banner and tab bar are pinned; each tab
    // owns its scroll area below, so switching tabs never moves the frame.
    return AppShell(
      hospitalName: hospital.hospitalName,
      role: auth.role,
      scrollable: false,
      bottomNavItems: _bottomNav,
      currentNavIndex: 0,
      onNavTap: (i) {
        if (i < _bottomNav.length) context.go(_bottomNav[i].route);
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StaffHeroBanner(
            name: auth.subjectName.isNotEmpty ? auth.subjectName : 'Staff',
            userId: auth.subjectPublicId ?? '',
            showPharmacy: auth.hasPharmacy,
            onPharmacy: () => context.push('/pharmacy'),
          ),
          const SizedBox(height: 16),
          _TabBar(
            selected: _tab,
            onSelect: (i) {
              setState(() {
                _tab = i;
                if (i != 0) _prefillPatient = null;
              });
            },
          ),
          const SizedBox(height: 16),
          // All tabs stay mounted (IndexedStack) so switching doesn't refetch
          // or flash loading states, and each keeps its own scroll position.
          Expanded(
            child: TabStack(
              index: _tab,
              children: [
                _tabPage(_BookTab(
                  key: ValueKey(_prefillPatient?.patientPublicId ?? '__new__'),
                  prefill: _prefillPatient,
                  onClearPrefill: () => setState(() => _prefillPatient = null),
                )),
                _tabPage(const _DoctorsTab()),
                _tabPage(_PatientsTab(onBookForPatient: _bookForExistingPatient)),
                _tabPage(const _StaffRequestsTab()),
                _tabPage(const _RoomsTab()),
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

// ── Staff hero banner ─────────────────────────────────────────────────────────

class _StaffHeroBanner extends StatelessWidget {
  final String name;
  final String userId;
  final bool showPharmacy;
  final VoidCallback? onPharmacy;
  const _StaffHeroBanner({
    required this.name,
    required this.userId,
    this.showPharmacy = false,
    this.onPharmacy,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: SevaCareColors.skyGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const AnimatedHealthcareBg(
              variant: HealthcareBgVariant.staff,
              height: 120,
            ),
            const Positioned.fill(child: TimeTintOverlay()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 2,
                      ),
                    ),
                    child: StaffPhoto.circle(
                      userId: userId,
                      size: 52,
                      isStaff: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_greeting()}',
                          style: AppTextStyles.label(
                            SevaCareColors.textOnPrimary.withValues(
                              alpha: 0.80,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: AppTextStyles.cardTitle(
                            SevaCareColors.textOnPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'IP-Staff Portal',
                            style: AppTextStyles.label(
                              SevaCareColors.textOnPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showPharmacy)
                    Tooltip(
                      message: 'Open the pharmacy counter',
                      child: InkWell(
                        onTap: onPharmacy,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.local_pharmacy_outlined, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Pharmacy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ]),
                        ),
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

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (icon: Icons.calendar_month_outlined, label: 'Book'),
      (icon: Icons.medical_services_outlined, label: 'Doctors'),
      (icon: Icons.people_outline, label: 'Patients'),
      (icon: Icons.event_note_outlined, label: 'Requests'),
      (icon: Icons.king_bed_outlined, label: 'Rooms'),
    ];
    return Row(
      children: List.generate(tabs.length, (i) {
        final active = i == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              decoration: BoxDecoration(
                color: active ? SevaCareColors.primary : SevaCareColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: active
                      ? SevaCareColors.primary
                      : SevaCareColors.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tabs[i].icon,
                    size: 14,
                    color: active
                        ? SevaCareColors.textOnPrimary
                        : SevaCareColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      tabs[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(
                        active
                            ? SevaCareColors.textOnPrimary
                            : SevaCareColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Doctors Tab — availability checker for phone enquiries ────────────────────
// IP-Staff picks specialty → doctor → date and sees leave status, blocked
// windows and the exact free slots — before promising anything to a caller.

class _DoctorsTab extends ConsumerStatefulWidget {
  const _DoctorsTab();

  @override
  ConsumerState<_DoctorsTab> createState() => _DoctorsTabState();
}

class _DoctorsTabState extends ConsumerState<_DoctorsTab> {
  BookingSetupView? _setup;
  List<DoctorSummary> _doctors = [];
  List<DoctorAvailabilityView> _availability = [];
  bool _loading = true;
  String? _error;

  String _specialty = '';
  String _doctorId = '';
  String _doctorName = '';
  String _date = '';

  SlotStatusView? _status;
  bool _loadingStatus = false;
  List<String>? _doctorMorningSlots;
  List<String>? _doctorEveningSlots;
  List<String> get _morningSlots => _doctorMorningSlots ?? _setup?.morningSlots ?? [];
  List<String> get _eveningSlots => _doctorEveningSlots ?? _setup?.eveningSlots ?? [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final tenantId = auth.tenantPublicId ?? '';
      final results = await Future.wait([
        repo.getBookingSetup(tenantId, auth.subjectPublicId ?? 'STAFF', auth.token ?? ''),
        repo.listPublicDoctors(tenantId),
      ]);
      if (!mounted) return;
      setState(() {
        _setup = results[0] as BookingSetupView;
        _doctors = results[1] as List<DoctorSummary>;
        _specialty = _setup!.specialties.isNotEmpty ? _setup!.specialties.first : '';
        _date = _setup!.availableDates.isNotEmpty ? _setup!.availableDates.first : '';
        _loading = false;
      });
      _loadAvailability();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load doctors.');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadAvailability() async {
    if (_date.isEmpty) return;
    try {
      final auth = ref.read(authProvider);
      final availability = await ref.read(repositoryProvider).getDoctorAvailability(
        auth.tenantPublicId ?? '', _date, auth.token ?? '',
      );
      if (mounted) setState(() => _availability = availability);
    } catch (_) {}
  }

  Future<void> _loadStatus() async {
    if (_doctorId.isEmpty || _date.isEmpty) return;
    setState(() {
      _loadingStatus = true;
      _status = null;
      _doctorMorningSlots = null;
      _doctorEveningSlots = null;
    });
    final auth = ref.read(authProvider);
    try {
      final status = await ref.read(repositoryProvider).getSlotStatus(
        auth.tenantPublicId ?? '', _doctorId, _date, auth.token ?? '',
      );
      if (mounted) setState(() => _status = status);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
    try {
      final slots = await ref.read(repositoryProvider).getDoctorSlots(
        auth.tenantPublicId ?? '', _doctorId, _date, auth.token ?? '',
      );
      if (mounted) {
        setState(() {
          _doctorMorningSlots = List<String>.from(slots['morningSlots'] as List? ?? const []);
          _doctorEveningSlots = List<String>.from(slots['eveningSlots'] as List? ?? const []);
        });
      }
    } catch (_) {}
  }

  DoctorAvailabilityView? _availabilityFor(String doctorId) {
    for (final a in _availability) {
      if (a.doctorPublicId == doctorId) return a;
    }
    return null;
  }

  List<DoctorSummary> get _filteredDoctors => _specialty.isEmpty
      ? _doctors
      : _doctors.where((d) => d.specialty == _specialty).toList();

  int get _freeSlotCount {
    if (_setup == null || _status == null) return 0;
    final all = [..._morningSlots, ..._eveningSlots];
    return all
        .where((s) =>
            !_status!.bookedSlots.contains(s) && !_status!.blockedSlots.contains(s))
        .length;
  }

  String _wd(int w) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _mo(int m) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: ShimmerList(count: 3, cardHeight: 90),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: _RetryRow(msg: _error!, onRetry: _load),
      );
    }
    final totalSlots = _morningSlots.length + _eveningSlots.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Specialty & doctor picker ─────────────────────────────────────────
        _Card(
          icon: Icons.medical_services_outlined,
          title: 'Find a Doctor',
          trailing: IconButton(
            icon: const Icon(Icons.refresh, size: 16, color: SevaCareColors.textMuted),
            onPressed: () {
              _load();
              if (_doctorId.isNotEmpty) _loadStatus();
            },
            tooltip: 'Refresh',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((_setup?.specialties ?? []).isEmpty)
                Text('No specialties configured.',
                    style: AppTextStyles.bodyText(SevaCareColors.textMuted))
              else
                AppDropdown<String>(
                  label: 'Specialty',
                  value: _setup!.specialties.contains(_specialty)
                      ? _specialty
                      : _setup!.specialties.first,
                  items: _setup!.specialties
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _specialty = v;
                        _doctorId = '';
                        _doctorName = '';
                        _status = null;
                      });
                    }
                  },
                ),
              const SizedBox(height: 10),
              if (_filteredDoctors.isEmpty)
                Text('No doctors for this specialty.',
                    style: AppTextStyles.bodyText(SevaCareColors.textMuted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filteredDoctors.map((doc) {
                    final sel = _doctorId == doc.doctorPublicId;
                    final avail = _availabilityFor(doc.doctorPublicId);
                    final onLeave = avail?.onLeave ?? false;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _doctorId = doc.doctorPublicId;
                          _doctorName = doc.name;
                        });
                        _loadStatus();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? SevaCareColors.primary : SevaCareColors.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          border: Border.all(
                            color: sel ? SevaCareColors.primary : SevaCareColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DoctorPhoto.circle(doctorId: doc.doctorPublicId, size: 20),
                            const SizedBox(width: 6),
                            if (onLeave) ...[
                              const Icon(Icons.event_busy, size: 12, color: SevaCareColors.danger),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              doc.name,
                              style: AppTextStyles.body(
                                size: 13,
                                weight: FontWeight.w600,
                                color: sel ? SevaCareColors.textOnPrimary : SevaCareColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        // ── Live queue control ────────────────────────────────────────────────
        if (_doctorId.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/queue/control', extra: {
              'doctorPublicId': _doctorId,
              'doctorName': _doctorName,
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  const Icon(Icons.queue_play_next_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Queue Control',
                            style: AppTextStyles.buttonLabel(Colors.white)),
                        Text('Call next · mark done · no-show for $_doctorName',
                            style: AppTextStyles.label(
                                Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],

        // ── Date strip ────────────────────────────────────────────────────────
        if (_doctorId.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Card(
            icon: Icons.calendar_today_outlined,
            title: 'Check Date',
            child: SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _setup?.availableDates.length ?? 0,
                separatorBuilder: (_, i2) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = _setup!.availableDates[i];
                  final sel = _date == d;
                  final dt = DateTime.tryParse(d);
                  final lbl = dt != null ? '${_wd(dt.weekday)}\n${dt.day} ${_mo(dt.month)}' : d;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _date = d);
                      _loadAvailability();
                      _loadStatus();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? SevaCareColors.primary : SevaCareColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? SevaCareColors.primary : SevaCareColors.border,
                        ),
                      ),
                      child: Text(
                        lbl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: sel ? Colors.white : SevaCareColors.text,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Availability result ─────────────────────────────────────────────
          const SizedBox(height: 12),
          _Card(
            icon: Icons.event_available_outlined,
            title: 'Availability — $_doctorName',
            child: _loadingStatus
                ? const _Spinner(label: 'Checking availability…')
                : _status == null
                    ? Text('Select a doctor and date to check availability.',
                        style: AppTextStyles.bodyText(SevaCareColors.textMuted))
                    : _status!.doctorOnLeave
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SevaCareColors.errorSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_busy, size: 16, color: SevaCareColors.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_doctorName is on approved leave on $_date — not available for appointments. Suggest another date or doctor to the caller.',
                                    style: AppTextStyles.label(SevaCareColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary banner
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: SevaCareColors.successSurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 15, color: SevaCareColors.success),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$_freeSlotCount of $totalSlots slots free on $_date'
                                        '${_status!.blockedSlots.isNotEmpty ? ' · doctor busy for some hours (amber)' : ''}',
                                        style: AppTextStyles.label(SevaCareColors.success),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_morningSlots.isNotEmpty) ...[
                                Text('Morning  ${_morningSlots.first} – ${_morningSlots.last}',
                                    style: AppTextStyles.label(SevaCareColors.textMuted)),
                                const SizedBox(height: 6),
                                _SlotGrid(
                                  slots: _morningSlots,
                                  booked: _status!.bookedSlots,
                                  blocked: _status!.blockedSlots,
                                  selected: '',
                                  onSelect: (_) {},
                                ),
                              ],
                              if (_eveningSlots.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Evening  ${_eveningSlots.first} – ${_eveningSlots.last}',
                                    style: AppTextStyles.label(SevaCareColors.textMuted)),
                                const SizedBox(height: 6),
                                _SlotGrid(
                                  slots: _eveningSlots,
                                  booked: _status!.bookedSlots,
                                  blocked: _status!.blockedSlots,
                                  selected: '',
                                  onSelect: (_) {},
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _LegendDot(color: SevaCareColors.surface, label: 'Free', bordered: true),
                                  const SizedBox(width: 12),
                                  _LegendDot(color: SevaCareColors.border, label: 'Booked'),
                                  const SizedBox(width: 12),
                                  _LegendDot(color: SevaCareColors.warningSurface, label: 'Doctor busy'),
                                ],
                              ),
                            ],
                          ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool bordered;
  const _LegendDot({required this.color, required this.label, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: bordered ? Border.all(color: SevaCareColors.border) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.label(SevaCareColors.textMuted)),
      ],
    );
  }
}

// ── Staff Requests Tab — leave requests to the hospital admin ─────────────────

class _StaffRequestsTab extends ConsumerStatefulWidget {
  const _StaffRequestsTab();

  @override
  ConsumerState<_StaffRequestsTab> createState() => _StaffRequestsTabState();
}

class _StaffRequestsTabState extends ConsumerState<_StaffRequestsTab> {
  final _reasonCtrl = TextEditingController();
  final _fromDateCtrl = TextEditingController();
  final _toDateCtrl = TextEditingController();
  String _leaveType = 'SICK';
  bool _hourlyLeave = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _submitting = false;
  String? _successMsg;

  LeaveRequestCollection? _history;
  bool _loadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _fromDateCtrl.dispose();
    _toDateCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final auth = ref.read(authProvider);
      final data = await ref.read(repositoryProvider).getStaffLeaveRequests(
        auth.tenantPublicId ?? '', auth.subjectPublicId ?? '', auth.token ?? '',
      );
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _historyError = extractErrorMessage(e, fallback: 'Failed to load requests.'));
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null && mounted) {
      ctrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 12, minute: 0)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_fromDateCtrl.text.isEmpty || _toDateCtrl.text.isEmpty) {
      AppSnack.info(context, 'Please select from and to dates.');
      return;
    }
    if (_hourlyLeave) {
      if (_startTime == null || _endTime == null) {
        AppSnack.info(context, 'Please select start and end time for hourly leave.');
        return;
      }
      final startMins = _startTime!.hour * 60 + _startTime!.minute;
      final endMins = _endTime!.hour * 60 + _endTime!.minute;
      if (endMins <= startMins) {
        AppSnack.info(context, 'End time must be after start time.');
        return;
      }
    }
    setState(() {
      _submitting = true;
      _successMsg = null;
    });
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).createStaffLeaveRequest(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
        {
          'leaveType': _leaveType,
          'fromDate': _fromDateCtrl.text,
          'toDate': _toDateCtrl.text,
          'message': _reasonCtrl.text.trim(),
          if (_hourlyLeave) 'startTime': _fmtTime(_startTime!),
          if (_hourlyLeave) 'endTime': _fmtTime(_endTime!),
        },
      );
      if (mounted) {
        _fromDateCtrl.clear();
        _toDateCtrl.clear();
        _reasonCtrl.clear();
        setState(() {
          _startTime = null;
          _endTime = null;
          _hourlyLeave = false;
          _successMsg =
              'Leave request submitted! The hospital admin will review and respond.';
        });
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        AppSnack.error(
            context, extractErrorMessage(e, fallback: 'Failed to submit request.'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_successMsg != null) ...[
          _Banner(msg: _successMsg!, isError: false),
          const SizedBox(height: 12),
        ],

        // ── Apply for leave ───────────────────────────────────────────────────
        _Card(
          icon: Icons.event_note_outlined,
          title: 'Apply for Leave',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDropdown<String>(
                label: 'Leave Type',
                value: _leaveType,
                items: const [
                  DropdownMenuItem(value: 'SICK', child: Text('Sick Leave')),
                  DropdownMenuItem(value: 'VACATION', child: Text('Vacation / Planned')),
                  DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _leaveType = v);
                },
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(_fromDateCtrl),
                      child: AbsorbPointer(
                        child: AppFormField(
                          label: 'From Date',
                          controller: _fromDateCtrl,
                          placeholder: 'YYYY-MM-DD',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(_toDateCtrl),
                      child: AbsorbPointer(
                        child: AppFormField(
                          label: 'To Date',
                          controller: _toDateCtrl,
                          placeholder: 'YYYY-MM-DD',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Duration', style: AppTextStyles.label(SevaCareColors.textMuted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ToggleChip(
                      label: 'Full Day(s)',
                      selected: !_hourlyLeave,
                      onTap: () => setState(() => _hourlyLeave = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToggleChip(
                      label: 'Specific Hours',
                      selected: _hourlyLeave,
                      onTap: () => setState(() => _hourlyLeave = true),
                    ),
                  ),
                ],
              ),
              if (_hourlyLeave) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StaffTimePickTile(
                        label: 'From Time',
                        value: _startTime == null ? 'Pick time' : _fmtTime(_startTime!),
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StaffTimePickTile(
                        label: 'To Time',
                        value: _endTime == null ? 'Pick time' : _fmtTime(_endTime!),
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              AppFormField(
                label: 'Reason / Notes (optional)',
                controller: _reasonCtrl,
                placeholder: 'Briefly describe the reason…',
                maxLines: 3,
              ),
              const SizedBox(height: 4),
              PrimaryButton(
                label: 'Submit Leave Request',
                icon: Icons.send_rounded,
                isLoading: _submitting,
                fullWidth: true,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),

        // ── My requests ───────────────────────────────────────────────────────
        const SizedBox(height: 16),
        Text('My Requests', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        const SizedBox(height: 10),
        if (_loadingHistory)
          const Center(
            child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_historyError != null)
          _RetryRow(msg: _historyError!, onRetry: _loadHistory)
        else if ((_history?.requests ?? []).isEmpty)
          _Card(
            icon: Icons.inbox_outlined,
            title: 'No requests yet',
            child: Text(
              'Your leave requests and the admin\'s responses appear here.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          )
        else
          Column(
            children: _history!.requests
                .map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StaffRequestTile(request: r),
                    ))
                .toList(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StaffTimePickTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _StaffTimePickTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final placeholder = value == 'Pick time';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(SevaCareColors.textMuted)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: SevaCareColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SevaCareColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 15, color: SevaCareColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: placeholder ? FontWeight.w400 : FontWeight.w600,
                    color: placeholder ? SevaCareColors.textMuted : SevaCareColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffRequestTile extends StatelessWidget {
  final LeaveRequestRecord request;
  const _StaffRequestTile({required this.request});

  Color get _statusColor => switch (request.status) {
        'PENDING' => const Color(0xFFD97706),
        'APPROVED' || 'AUTO_APPROVED' => SevaCareColors.mint,
        'DECLINED' => SevaCareColors.danger,
        _ => SevaCareColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  switch (request.leaveType.toUpperCase()) {
                    'SICK' => 'Sick Leave',
                    'VACATION' => 'Vacation / Planned',
                    'EMERGENCY' => 'Emergency Leave',
                    _ => 'Other Leave',
                  },
                  style: AppTextStyles.cardTitle(SevaCareColors.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.status == 'AUTO_APPROVED' ? 'Auto-Approved' : request.status,
                  style: AppTextStyles.badgeText(_statusColor),
                ),
              ),
            ],
          ),
          if (request.fromDate != null) ...[
            const SizedBox(height: 4),
            Text(
              '${request.fromDate}  →  ${request.toDate}'
              '${request.isHourly ? '  ·  ${request.startTime}–${request.endTime}' : ''}',
              style: AppTextStyles.label(SevaCareColors.textMuted),
            ),
          ],
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(request.message,
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (request.adminResponse != null && request.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SevaCareColors.primary.withValues(alpha: 0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined,
                      size: 14, color: SevaCareColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Admin: ${request.adminResponse!}',
                        style: AppTextStyles.label(SevaCareColors.primary)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Book Appointment Tab ───────────────────────────────────────────────────────

class _BookTab extends ConsumerStatefulWidget {
  final PatientRecord? prefill;
  final VoidCallback onClearPrefill;

  const _BookTab({super.key, this.prefill, required this.onClearPrefill});

  @override
  ConsumerState<_BookTab> createState() => _BookTabState();
}

class _BookTabState extends ConsumerState<_BookTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _ageCtrl;
  String _gender = 'male';

  // Intake vitals (recorded by IP-Staff, shown to the doctor at consult time)
  // Same field set/format as the doctor's consultation vitals section.
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _vitalsExpanded = false; // optional — collapsed by default

  // Booking options
  BookingSetupView? _setup;
  List<DoctorSummary> _doctors = [];
  bool _loadingSetup = true;
  String? _setupError;

  // Doctor availability for the selected date (leave + blocked windows)
  List<DoctorAvailabilityView> _availability = [];

  // Selections
  String _specialty = '';
  String _doctorId = '';
  String _doctorName = '';
  String _date = '';
  String _slot = '';
  List<String> _bookedSlots = [];
  List<String> _blockedSlots = [];
  bool _doctorOnLeave = false;
  bool _loadingSlots = false;
  List<String>? _doctorMorningSlots;
  List<String>? _doctorEveningSlots;
  List<String> get _morningSlots => _doctorMorningSlots ?? _setup?.morningSlots ?? [];
  List<String> get _eveningSlots => _doctorEveningSlots ?? _setup?.eveningSlots ?? [];

  // Token booking
  String _bookingType = 'SLOT'; // 'SLOT' or 'TOKEN'
  String? _tokenSession; // 'MORNING' or 'EVENING'
  int? _tokenPreviewNumber;
  bool _loadingTokenPreview = false;
  bool _resettingTokenCounter = false;

  // Slot accordion (Morning/Evening) — single section open at a time
  String _expandedSlotSession = 'MORNING';

  // Prescription attachments
  List<PickedPrescriptionFile> _attachments = [];
  int _attachmentsResetKey = 0;

  // Registration-only mode: create/refresh the patient record without booking
  // an appointment (walk-ins whose consultation is already done, or pure
  // registration visits). They can be booked later from the Patients tab.
  bool _registerOnly = false;

  // Submit
  bool _booking = false;
  String? _error;
  String? _success;

  // One key per booking attempt: a retry after a timeout reuses it, so the
  // server dedupes instead of issuing a second token. Cleared only on success.
  String? _bookingIdemKey;

  bool get _hasPrefill => widget.prefill != null;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _mobileCtrl = TextEditingController(text: p?.mobileNumber ?? '');
    _ageCtrl = TextEditingController(text: p?.age?.toString() ?? '');
    _gender = p?.gender ?? 'male';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSetup());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _ageCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _sugarCtrl.dispose();
    _pulseCtrl.dispose();
    _tempCtrl.dispose();
    _spo2Ctrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loadingSetup = true;
      _setupError = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final tenantId = auth.tenantPublicId ?? '';
      final staffId = auth.subjectPublicId ?? 'STAFF';

      final results = await Future.wait([
        repo.getBookingSetup(tenantId, staffId, auth.token ?? ''),
        repo.listPublicDoctors(tenantId),
      ]);

      final setup = results[0] as BookingSetupView;
      final docs = (results[1] as List<DoctorSummary>)
          .where((d) => d.availability != 'On Leave')
          .toList();

      if (mounted) {
        setState(() {
          _setup = setup;
          _doctors = docs;
          _specialty = setup.specialties.isNotEmpty
              ? setup.specialties.first
              : '';
          _date = setup.availableDates.isNotEmpty
              ? setup.availableDates.first
              : '';
          _loadingSetup = false;
        });
        _loadAvailability();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _setupError = extractErrorMessage(
            e,
            fallback: 'Failed to load booking options.',
          );
          _loadingSetup = false;
        });
      }
    }
  }

  /// Availability overview (leave + blocked windows) for the selected date.
  Future<void> _loadAvailability() async {
    if (_date.isEmpty) return;
    try {
      final auth = ref.read(authProvider);
      final availability = await ref
          .read(repositoryProvider)
          .getDoctorAvailability(
            auth.tenantPublicId ?? '',
            _date,
            auth.token ?? '',
          );
      if (mounted) {
        setState(() {
          _availability = availability;
        });
      }
    } catch (_) {}
  }

  DoctorAvailabilityView? _availabilityFor(String doctorId) {
    for (final a in _availability) {
      if (a.doctorPublicId == doctorId) return a;
    }
    return null;
  }

  Future<void> _loadBookedSlots() async {
    if (_doctorId.isEmpty || _date.isEmpty) return;
    setState(() {
      _loadingSlots = true;
      _bookedSlots = [];
      _blockedSlots = [];
      _doctorOnLeave = false;
      _slot = '';
      _doctorMorningSlots = null;
      _doctorEveningSlots = null;
    });
    final auth = ref.read(authProvider);
    try {
      final status = await ref
          .read(repositoryProvider)
          .getSlotStatus(
            auth.tenantPublicId ?? '',
            _doctorId,
            _date,
            auth.token ?? '',
          );
      if (mounted) {
        setState(() {
          _bookedSlots = status.bookedSlots;
          _blockedSlots = status.blockedSlots;
          _doctorOnLeave = status.doctorOnLeave;
          _loadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
    }
    try {
      final slots = await ref.read(repositoryProvider).getDoctorSlots(
            auth.tenantPublicId ?? '',
            _doctorId,
            _date,
            auth.token ?? '',
          );
      if (mounted) {
        setState(() {
          _doctorMorningSlots = List<String>.from(slots['morningSlots'] as List? ?? const []);
          _doctorEveningSlots = List<String>.from(slots['eveningSlots'] as List? ?? const []);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTokenPreview() async {
    if (_doctorId.isEmpty || _date.isEmpty || _tokenSession == null) return;
    setState(() {
      _loadingTokenPreview = true;
      _tokenPreviewNumber = null;
    });
    try {
      final auth = ref.read(authProvider);
      final preview = await ref.read(repositoryProvider).getTokenPreview(
            auth.tenantPublicId ?? '',
            _doctorId,
            _date,
            _tokenSession!,
            auth.token ?? '',
          );
      if (mounted) {
        setState(() {
          _tokenPreviewNumber = preview.nextTokenNumber;
          _loadingTokenPreview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTokenPreview = false);
    }
  }

  Future<void> _resetTokenCounter() async {
    if (_doctorId.isEmpty || _date.isEmpty || _tokenSession == null) return;
    final sessionLabel = _tokenSession == 'EVENING' ? 'Evening' : 'Morning';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset token counter?'),
        content: Text(
          "Reset today's $sessionLabel token counter for $_doctorName to 0 on $_date? Already-issued tokens are unaffected.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _resettingTokenCounter = true);
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).resetTokenCounter(
            auth.tenantPublicId ?? '',
            _doctorId,
            _date,
            _tokenSession!,
            auth.token ?? '',
          );
      if (mounted) {
        AppSnack.success(context, 'Token counter reset.');
        _loadTokenPreview();
      }
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, extractErrorMessage(e, fallback: 'Reset failed.'));
      }
    } finally {
      if (mounted) setState(() => _resettingTokenCounter = false);
    }
  }

  /// Compact vitals summary from whatever the staff filled in.
  String _composeVitals() {
    final parts = <String>[];
    final sys = _systolicCtrl.text.trim();
    final dia = _diastolicCtrl.text.trim();
    if (sys.isNotEmpty || dia.isNotEmpty) {
      parts.add('BP ${sys.isEmpty ? '-' : sys}/${dia.isEmpty ? '-' : dia} mmHg');
    }
    if (_sugarCtrl.text.trim().isNotEmpty) {
      parts.add('Sugar ${_sugarCtrl.text.trim()} mg/dL');
    }
    if (_pulseCtrl.text.trim().isNotEmpty) {
      parts.add('Pulse ${_pulseCtrl.text.trim()} bpm');
    }
    if (_tempCtrl.text.trim().isNotEmpty) {
      parts.add('Temp ${_tempCtrl.text.trim()}°C');
    }
    if (_spo2Ctrl.text.trim().isNotEmpty) {
      parts.add('SpO2 ${_spo2Ctrl.text.trim()}%');
    }
    if (_weightCtrl.text.trim().isNotEmpty) {
      parts.add('Wt ${_weightCtrl.text.trim()} kg');
    }
    return parts.join(' · ');
  }

  /// Registration without an appointment. Same idempotent register call the
  /// booking flow uses, plus an upsert so age/gender land on the record.
  Future<void> _registerPatientOnly(String name, String mobile) async {
    setState(() {
      _booking = true;
      _error = null;
      _success = null;
    });
    try {
      final auth = ref.read(authProvider);
      final tenantId = auth.tenantPublicId ?? '';
      final resp = await apiClient.post<Map<String, dynamic>>(
        '/admin/patients',
        body: {
          'tenantPublicId': tenantId,
          'name': name,
          'mobileNumber': mobile,
          'specialtyOrAgeBand': '',
        },
        fromJson: (d) => d as Map<String, dynamic>,
        extraHeaders: {
          'Authorization': 'Bearer ${auth.token}',
          'X-Tenant-Id': tenantId,
        },
      );
      final patientId = resp['publicId'] as String? ?? '';
      if (patientId.isNotEmpty) {
        await ref.read(repositoryProvider).upsertPatientRecord(
              tenantId,
              patientId,
              auth.token ?? '',
              PatientUpsertRequest(
                fullName: name,
                mobileNumber: mobile,
                status: 'active',
                gender: _gender,
                age: int.tryParse(_ageCtrl.text.trim()),
              ),
            );
      }
      if (mounted) {
        setState(() {
          _success =
              '$name registered — no appointment booked.\nFind them in the Patients tab to book a consultation later.';
          _nameCtrl.clear();
          _mobileCtrl.clear();
          _ageCtrl.clear();
          _gender = 'male';
          _booking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to register patient.');
          _booking = false;
        });
      }
    }
  }

  Future<void> _book() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Patient name is required');
      return;
    }
    if (mobile.length < 10) {
      setState(() => _error = 'Enter valid 10-digit mobile');
      return;
    }
    if (_registerOnly) {
      await _registerPatientOnly(name, mobile);
      return;
    }
    if (_specialty.isEmpty) {
      setState(() => _error = 'Please select a specialty');
      return;
    }
    if (_doctorId.isEmpty) {
      setState(() => _error = 'Please select a doctor');
      return;
    }
    if (_date.isEmpty) {
      setState(() => _error = 'Please select a date');
      return;
    }
    final isToken = _bookingType == 'TOKEN';
    if (isToken) {
      if (_tokenSession == null) {
        setState(() => _error = 'Please select Morning or Evening token');
        return;
      }
    } else if (_slot.isEmpty) {
      setState(() => _error = 'Please select a time slot');
      return;
    }

    setState(() {
      _booking = true;
      _error = null;
      _success = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final tenantId = auth.tenantPublicId ?? '';
      final staffId = auth.subjectPublicId ?? 'STAFF';

      // If pre-filling from an existing patient, reuse their ID directly
      String patientId = widget.prefill?.patientPublicId ?? '';
      if (patientId.isEmpty) {
        // New patient — register first (idempotent; if already exists, use returned ID)
        try {
          final resp = await apiClient.post<Map<String, dynamic>>(
            '/admin/patients',
            body: {
              'tenantPublicId': tenantId,
              'name': name,
              'mobileNumber': mobile,
              'specialtyOrAgeBand': '',
            },
            fromJson: (d) => d as Map<String, dynamic>,
            extraHeaders: {
              'Authorization': 'Bearer ${auth.token}',
              'X-Tenant-Id': tenantId,
            },
          );
          patientId = resp['publicId'] as String? ?? mobile;
        } catch (_) {
          patientId = mobile;
        }
      }

      _bookingIdemKey ??= newIdempotencyKey();
      await repo.bookAppointment(
        tenantId,
        patientId,
        auth.token ?? '',
        idempotencyKey: _bookingIdemKey,
        AppointmentBookingRequest(
          tenantPublicId: tenantId,
          patientPublicId: patientId,
          patientName: name,
          gender: _gender,
          age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
          mobileNumber: mobile,
          address: '',
          specialty: _specialty,
          doctorPublicId: _doctorId,
          slot: isToken ? _date : '$_date $_slot',
          bookingType: _bookingType,
          tokenSession: isToken ? _tokenSession : null,
          note: 'Booked by IP-Staff: $staffId',
          vitals: _composeVitals(),
          bookingSource: 'IP_STAFF',
          attachments: _attachments.isEmpty
              ? null
              : _attachments
                  .map((f) => AttachmentUploadRequest(
                        fileName: f.fileName,
                        mimeType: f.mimeType,
                        dataBase64: base64Encode(f.bytes),
                      ))
                  .toList(),
        ),
      );

      _bookingIdemKey = null; // consumed — the next booking is a new attempt
      if (mounted) {
        widget.onClearPrefill();
        final sessionLabel = _tokenSession == 'EVENING' ? 'Evening' : 'Morning';
        setState(() {
          _success = isToken
              ? 'Appointment booked with $_doctorName on $_date — Token #${_tokenPreviewNumber ?? '-'} ($sessionLabel).\nAdded to doctor\'s queue.'
              : 'Appointment booked with $_doctorName on $_date at $_slot.\nAdded to doctor\'s queue.';
          _nameCtrl.clear();
          _mobileCtrl.clear();
          _ageCtrl.clear();
          _systolicCtrl.clear();
          _diastolicCtrl.clear();
          _sugarCtrl.clear();
          _pulseCtrl.clear();
          _tempCtrl.clear();
          _spo2Ctrl.clear();
          _weightCtrl.clear();
          _vitalsExpanded = false;
          _gender = 'male';
          _doctorId = '';
          _doctorName = '';
          _slot = '';
          _bookingType = 'SLOT';
          _tokenSession = null;
          _tokenPreviewNumber = null;
          _attachments = [];
          _attachmentsResetKey++;
          _booking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(
            e,
            fallback: 'Booking failed. Please retry.',
          );
          _booking = false;
        });
      }
    }
  }

  List<DoctorSummary> get _filteredDoctors => _specialty.isEmpty
      ? _doctors
      : _doctors.where((d) => d.specialty == _specialty).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pre-fill banner ────────────────────────────────────────────────────
          if (_hasPrefill) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SevaCareColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin_outlined,
                    size: 16,
                    color: SevaCareColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking for existing patient: ${widget.prefill!.fullName}',
                      style: AppTextStyles.label(SevaCareColors.primary),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClearPrefill,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: SevaCareColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Mode: full booking vs registration only ───────────────────────────
          if (!_hasPrefill) ...[
            SegmentedControl<bool>(
              selected: _registerOnly,
              items: const [
                SegmentItem(value: false, label: 'Register & Book', icon: Icons.event_available_outlined),
                SegmentItem(value: true, label: 'Register Only', icon: Icons.person_add_alt_outlined),
              ],
              onChanged: (v) => setState(() {
                _registerOnly = v;
                _error = null;
                _success = null;
              }),
            ),
            if (_registerOnly) ...[
              const SizedBox(height: 8),
              Text(
                'Creates the patient record without an appointment — for walk-ins already consulted or registration-only visits. Book later from the Patients tab.',
                style: AppTextStyles.label(SevaCareColors.textMuted),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // ── Booking details: patient, vitals, prescriptions, specialty ────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(icon: Icons.person_outline, title: 'Patient Details'),
                const SizedBox(height: 12),
                Column(
                  children: [
                    AppFormField(
                      label: 'Patient Name',
                      placeholder: 'Full name',
                      controller: _nameCtrl,
                      required: true,
                      readOnly: _hasPrefill,
                    ),
                    AppFormField(
                      label: 'Mobile Number',
                      placeholder: '10-digit mobile',
                      controller: _mobileCtrl,
                      required: true,
                      keyboardType: TextInputType.phone,
                      readOnly: _hasPrefill,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    AppFormField(
                      label: 'Age',
                      placeholder: 'Age in years',
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Gender:',
                          style: AppTextStyles.label(SevaCareColors.textMuted),
                        ),
                        const SizedBox(width: 12),
                        _ToggleChip(
                          label: 'Male',
                          selected: _gender == 'male',
                          onTap: () => setState(() => _gender = 'male'),
                        ),
                        const SizedBox(width: 8),
                        _ToggleChip(
                          label: 'Female',
                          selected: _gender == 'female',
                          onTap: () => setState(() => _gender = 'female'),
                        ),
                        const SizedBox(width: 8),
                        _ToggleChip(
                          label: 'Other',
                          selected: _gender == 'other',
                          onTap: () => setState(() => _gender = 'other'),
                        ),
                      ],
                    ),
                  ],
                ),

                if (!_registerOnly) ...[
                const SizedBox(height: 16),
                const SectionDivider(),
                const SizedBox(height: 12),

                // Same collapsed-accordion format as the doctor's vitals section.
                _StaffVitalsSection(
                  expanded: _vitalsExpanded,
                  onToggle: () => setState(() => _vitalsExpanded = !_vitalsExpanded),
                  systolicCtrl: _systolicCtrl,
                  diastolicCtrl: _diastolicCtrl,
                  tempCtrl: _tempCtrl,
                  pulseCtrl: _pulseCtrl,
                  weightCtrl: _weightCtrl,
                  spo2Ctrl: _spo2Ctrl,
                  sugarCtrl: _sugarCtrl,
                ),

                const SizedBox(height: 12),
                const SectionDivider(),
                const SizedBox(height: 12),

                PrescriptionAttachmentPicker(
                  key: ValueKey(_attachmentsResetKey),
                  onChanged: (files) => setState(() => _attachments = files),
                ),

                const SizedBox(height: 16),
                const SectionDivider(),
                const SizedBox(height: 12),

                _SectionHeader(
                  icon: Icons.medical_services_outlined,
                  title: 'Specialty & Doctor',
                  trailing: _loadingSetup
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 16,
                            color: SevaCareColors.textMuted,
                          ),
                          onPressed: _loadSetup,
                          tooltip: 'Reload',
                        ),
                ),
                const SizedBox(height: 12),
                _loadingSetup
                    ? const _Spinner(label: 'Loading specialties & doctors…')
                    : _setupError != null
                    ? _RetryRow(msg: _setupError!, onRetry: _loadSetup)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_setup!.specialties.isEmpty)
                            Text(
                              'No specialties configured.',
                              style: AppTextStyles.bodyText(
                                SevaCareColors.textMuted,
                              ),
                            )
                          else ...[
                            AppDropdown<String>(
                              label: 'Specialty',
                              value: _setup!.specialties.contains(_specialty)
                                  ? _specialty
                                  : _setup!.specialties.first,
                              items: _setup!.specialties
                                  .map(
                                    (s) =>
                                        DropdownMenuItem(value: s, child: Text(s)),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _specialty = v;
                                    _doctorId = '';
                                    _doctorName = '';
                                    _slot = '';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Choose Doctor',
                              style: AppTextStyles.label(SevaCareColors.textMuted),
                            ),
                            const SizedBox(height: 8),
                            if (_filteredDoctors.isEmpty)
                              Text(
                                'No doctors available for this specialty.',
                                style: AppTextStyles.bodyText(
                                  SevaCareColors.textMuted,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _filteredDoctors.map((doc) {
                                  final sel = _doctorId == doc.doctorPublicId;
                                  final avail = _availabilityFor(
                                    doc.doctorPublicId,
                                  );
                                  final onLeave = avail?.onLeave ?? false;
                                  final partial =
                                      avail?.status == 'PARTIALLY_AVAILABLE';
                                  return GestureDetector(
                                    onTap: onLeave
                                        ? null
                                        : () {
                                            setState(() {
                                              _doctorId = doc.doctorPublicId;
                                              _doctorName = doc.name;
                                              _slot = '';
                                              _bookingType = doc.bookingMode == 'TOKEN' ? 'TOKEN' : 'SLOT';
                                              _tokenSession = null;
                                              _tokenPreviewNumber = null;
                                            });
                                            _loadBookedSlots();
                                          },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 140),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: onLeave
                                            ? SevaCareColors.surfaceMuted
                                            : sel
                                            ? SevaCareColors.primary
                                            : SevaCareColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusPill,
                                        ),
                                        border: Border.all(
                                          color: sel && !onLeave
                                              ? SevaCareColors.primary
                                              : SevaCareColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DoctorPhoto.circle(doctorId: doc.doctorPublicId, size: 20),
                                              const SizedBox(width: 6),
                                              Text(
                                                doc.name,
                                                style: AppTextStyles.body(
                                                  size: 13,
                                                  weight: FontWeight.w600,
                                                  color: onLeave
                                                      ? SevaCareColors.textMuted
                                                      : sel
                                                      ? SevaCareColors.textOnPrimary
                                                      : SevaCareColors.text,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            onLeave
                                                ? 'On leave · $_date'
                                                : partial
                                                ? '${doc.specialty} · partly busy'
                                                : doc.experienceYears != null
                                                ? '${doc.specialty} · ${doc.experienceYears}y Exp'
                                                : doc.specialty,
                                            style: AppTextStyles.label(
                                              onLeave
                                                  ? SevaCareColors.danger
                                                  : sel
                                                  ? SevaCareColors.textOnPrimary
                                                        .withValues(alpha: 0.75)
                                                  : SevaCareColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ],
                      ),
                ],
              ],
            ),
          ),

          // ── Slot / Token mode toggle ─────────────────────────────────────────
          if (!_registerOnly && !_loadingSetup && _setupError == null && _doctorId.isNotEmpty &&
              (_doctors.where((d) => d.doctorPublicId == _doctorId).firstOrNull?.bookingMode ?? 'BOTH') == 'BOTH') ...[
            const SizedBox(height: 12),
            SegmentedControl<String>(
              selected: _bookingType,
              items: const [
                SegmentItem(value: 'SLOT', label: 'Slot Booking', icon: Icons.schedule),
                SegmentItem(value: 'TOKEN', label: 'Token Booking', icon: Icons.confirmation_number_outlined),
              ],
              onChanged: (v) {
                setState(() {
                  _bookingType = v;
                  _tokenPreviewNumber = null;
                });
                if (v == 'TOKEN' && _tokenSession != null) _loadTokenPreview();
              },
            ),
          ],

          // ── Date ──────────────────────────────────────────────────────────────
          if (!_registerOnly &&
              !_loadingSetup &&
              _setupError == null &&
              _doctorId.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              icon: Icons.calendar_today_outlined,
              title: 'Select Date',
              child: SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _setup!.availableDates.length,
                  separatorBuilder: (context2, i2) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = _setup!.availableDates[i];
                    final sel = _date == d;
                    final dt = DateTime.tryParse(d);
                    final lbl = dt != null
                        ? '${_wd(dt.weekday)}\n${dt.day} ${_mo(dt.month)}'
                        : d;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _date = d;
                          _slot = '';
                        });
                        _loadBookedSlots();
                        _loadAvailability();
                        if (_bookingType == 'TOKEN' && _tokenSession != null) _loadTokenPreview();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? SevaCareColors.primary
                              : SevaCareColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? SevaCareColors.primary
                                : SevaCareColors.border,
                          ),
                        ),
                        child: Text(
                          lbl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: sel ? Colors.white : SevaCareColors.text,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // ── Time Slots ────────────────────────────────────────────────────────
          if (!_loadingSetup &&
              _setupError == null &&
              _doctorId.isNotEmpty &&
              _date.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              icon: _bookingType == 'TOKEN' ? Icons.confirmation_number_outlined : Icons.access_time_outlined,
              title: _bookingType == 'TOKEN' ? 'Select Token Session' : 'Select Time Slot',
              trailing: _bookingType == 'TOKEN' && _tokenSession != null && !_doctorOnLeave
                  ? TextButton(
                      onPressed: _resettingTokenCounter ? null : _resetTokenCounter,
                      child: Text(
                        _resettingTokenCounter ? 'Resetting…' : 'Reset counter',
                        style: AppTextStyles.label(SevaCareColors.primary),
                      ),
                    )
                  : null,
              child: _loadingSlots
                  ? const _Spinner(label: 'Loading available slots…')
                  : _doctorOnLeave
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SevaCareColors.errorSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_busy,
                            size: 16,
                            color: SevaCareColors.danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_doctorName is on leave on $_date. Pick another date or doctor.',
                              style: AppTextStyles.label(SevaCareColors.danger),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _bookingType == 'TOKEN'
                  ? TokenSessionPicker(
                      selectedSession: _tokenSession,
                      loadingPreview: _loadingTokenPreview,
                      nextTokenNumber: _tokenPreviewNumber,
                      onSelect: (session) {
                        setState(() => _tokenSession = session);
                        _loadTokenPreview();
                      },
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_blockedSlots.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.block,
                                size: 13,
                                color: SevaCareColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Doctor is unavailable for some slots (shown in amber).',
                                  style: AppTextStyles.label(
                                    SevaCareColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_morningSlots.isNotEmpty) ...[
                          _SlotAccordionSection(
                            title: 'Morning  ${_morningSlots.first} – ${_morningSlots.last}',
                            slots: _morningSlots,
                            booked: _bookedSlots,
                            blocked: _blockedSlots,
                            selected: _slot,
                            onSelect: (s) => setState(() => _slot = s),
                            expanded: _expandedSlotSession == 'MORNING',
                            onToggle: () => setState(() =>
                                _expandedSlotSession =
                                    _expandedSlotSession == 'MORNING' ? '' : 'MORNING'),
                          ),
                        ],
                        if (_eveningSlots.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _SlotAccordionSection(
                            title: 'Evening  ${_eveningSlots.first} – ${_eveningSlots.last}',
                            slots: _eveningSlots,
                            booked: _bookedSlots,
                            blocked: _blockedSlots,
                            selected: _slot,
                            onSelect: (s) => setState(() => _slot = s),
                            expanded: _expandedSlotSession == 'EVENING',
                            onToggle: () => setState(() =>
                                _expandedSlotSession =
                                    _expandedSlotSession == 'EVENING' ? '' : 'EVENING'),
                          ),
                        ],
                        if (_morningSlots.isEmpty && _eveningSlots.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SevaCareColors.warningSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_busy,
                                  size: 16,
                                  color: SevaCareColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$_doctorName is not available on $_date under their working hours. Pick another date or doctor.',
                                    style: AppTextStyles.label(
                                      SevaCareColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],

          // ── Errors + submit ───────────────────────────────────────────────────
          const SizedBox(height: 12),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _Banner(msg: _error!, isError: true),
          ],
          if (_success != null) ...[
            const SizedBox(height: 10),
            _Banner(msg: _success!, isError: false),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: _registerOnly ? 'Register Patient' : 'Book Appointment',
            icon: _registerOnly ? Icons.person_add_alt : Icons.check_circle_outline,
            isLoading: _booking,
            fullWidth: true,
            onPressed: _booking ? null : _book,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _wd(int w) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _mo(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];
}

// ── Patients Tab ──────────────────────────────────────────────────────────────

/// Tappable column header with an up/down sort-direction indicator — shows a
/// neutral icon when this column isn't the active sort, and a filled arrow
/// matching the current direction when it is.
class _SortableHeader extends StatelessWidget {
  final String label;
  final String column;
  final String? activeColumn;
  final String dir;
  final VoidCallback onTap;
  final MainAxisAlignment alignment;

  const _SortableHeader({
    required this.label,
    required this.column,
    required this.activeColumn,
    required this.dir,
    required this.onTap,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColumn == column;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.label(SevaCareColors.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            !active
                ? Icons.unfold_more_rounded
                : (dir == 'asc' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
            size: 13,
            color: active
                ? SevaCareColors.primary
                : SevaCareColors.primary.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

const List<String> _bloodGroups = [
  'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
];

class _PatientsTab extends ConsumerStatefulWidget {
  final ValueChanged<PatientRecord> onBookForPatient;
  const _PatientsTab({required this.onBookForPatient});

  @override
  ConsumerState<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends ConsumerState<_PatientsTab>
    with AutoRefreshMixin {
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;

  List<PatientSummary> _patients = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  // Who is currently admitted, keyed by patientPublicId — so a row can show an
  // "In Room X" badge and the detail sheet knows to offer Discharge over Admit.
  Map<String, Admission> _admitted = {};

  String? _sortBy;
  String _sortDir = 'asc';

  // Visited-between filter: only patients with an appointment in this window.
  // Default (null) = 10 most recent patients first, no window.
  DateTime? _visitFrom;
  DateTime? _visitTo;

  static const _pageSize = 10;

  String? get _fromDateStr => _visitFrom == null
      ? null
      : '${_visitFrom!.year}-${_visitFrom!.month.toString().padLeft(2, '0')}-${_visitFrom!.day.toString().padLeft(2, '0')}';
  String? get _toDateStr => _visitTo == null
      ? null
      : '${_visitTo!.year}-${_visitTo!.month.toString().padLeft(2, '0')}-${_visitTo!.day.toString().padLeft(2, '0')}';

  Future<void> _pickVisitRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
      initialDateRange: _visitFrom != null && _visitTo != null
          ? DateTimeRange(start: _visitFrom!, end: _visitTo!)
          : null,
      helpText: 'Patients who visited between',
    );
    if (picked != null && mounted) {
      setState(() {
        _visitFrom = picked.start;
        _visitTo = picked.end;
      });
      _load(reset: true);
    }
  }

  void _clearVisitRange() {
    setState(() {
      _visitFrom = null;
      _visitTo = null;
    });
    _load(reset: true);
  }

  bool get _hasMore => _patients.length < _total;

  void _toggleSort(String column) {
    setState(() {
      if (_sortBy == column) {
        _sortDir = _sortDir == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = column;
        _sortDir = 'asc';
      }
    });
    _load(reset: true);
  }

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _loadAdmitted();
    // Silent first-page refresh — skipped while searching or paged deeper,
    // so it never clobbers what the user is looking at.
    startAutoRefresh(() async {
      if (_page <= 1 && _searchCtrl.text.trim().isEmpty && _visitFrom == null && !_loadingMore) {
        await _load();
        await _loadAdmitted();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // The tab content lives inside AppShell's page-level scroll view (it has no
  // bounded height of its own), so infinite-scroll is driven by that ancestor
  // scroll's notifications rather than a local ScrollController.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore &&
        !_loading) {
      _loadMore();
    }
    return false;
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _patients = [];
        _page = 0;
        _total = 0;
      });
    }
    try {
      final auth = ref.read(authProvider);
      final data = await ref
          .read(repositoryProvider)
          .getAdminPatients(
            auth.tenantPublicId ?? '',
            0,
            _pageSize,
            _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
            auth.token ?? '',
            sortBy: _sortBy,
            sortDir: _sortDir,
            fromDate: _fromDateStr,
            toDate: _toDateStr,
          );
      final list = (data['patients'] as List? ?? [])
          .map((e) => PatientSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = (data['total'] as num?)?.toInt() ?? list.length;
      if (mounted) {
        setState(() {
          _patients = list;
          _total = total;
          _page = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load patients.');
          _loading = false;
        });
      }
    }
  }

  // Current in-patients, so the list and the detail sheet can tell who is in a
  // room. Best-effort: a tenant that never uses IPD simply has none, and the
  // patient list must work regardless.
  Future<void> _loadAdmitted() async {
    try {
      final auth = ref.read(authProvider);
      final list = await ref.read(repositoryProvider).getAdmissions(
            auth.tenantPublicId ?? '',
            auth.token ?? '',
          );
      if (mounted) {
        setState(() {
          _admitted = {for (final a in list) a.patientPublicId: a};
        });
      }
    } catch (_) {
      // IPD unused or unreachable — leave the map as-is.
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final auth = ref.read(authProvider);
      final data = await ref
          .read(repositoryProvider)
          .getAdminPatients(
            auth.tenantPublicId ?? '',
            _page,
            _pageSize,
            _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
            auth.token ?? '',
            sortBy: _sortBy,
            sortDir: _sortDir,
            fromDate: _fromDateStr,
            toDate: _toDateStr,
          );
      final list = (data['patients'] as List? ?? [])
          .map((e) => PatientSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _patients.addAll(list);
          _page++;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 400),
      () => _load(reset: true),
    );
  }

  // ── Edit patient dialog ───────────────────────────────────────────────────
  void _openEdit(PatientSummary p) {
    final nc = TextEditingController(text: p.fullName);
    final mc = TextEditingController(text: p.mobileNumber);
    final ac = TextEditingController(text: p.age?.toString() ?? '');
    String gender = p.gender ?? 'male';
    String? bloodGroup = p.bloodGroup;
    bool saving = false;
    String? dlgErr;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: SevaCareColors.surface,
          title: Text(
            'Edit Patient',
            style: AppTextStyles.cardTitle(SevaCareColors.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFormField(
                  label: 'Full Name',
                  placeholder: 'Full name',
                  controller: nc,
                  required: true,
                ),
                AppFormField(
                  label: 'Mobile',
                  placeholder: '10-digit mobile',
                  controller: mc,
                  required: true,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                AppFormField(
                  label: 'Age',
                  placeholder: 'Age in years',
                  controller: ac,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Gender:',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    _ToggleChip(
                      label: 'Male',
                      selected: gender == 'male',
                      onTap: () => setDlg(() => gender = 'male'),
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Female',
                      selected: gender == 'female',
                      onTap: () => setDlg(() => gender = 'female'),
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Other',
                      selected: gender == 'other',
                      onTap: () => setDlg(() => gender = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Blood group',
                      style: AppTextStyles.label(SevaCareColors.textMuted)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final bg in _bloodGroups)
                      _ToggleChip(
                        label: bg,
                        selected: bloodGroup == bg,
                        // Tap again to clear — blood group is optional.
                        onTap: () => setDlg(
                            () => bloodGroup = bloodGroup == bg ? null : bg),
                      ),
                  ],
                ),
                if (dlgErr != null) ...[
                  const SizedBox(height: 10),
                  _Banner(msg: dlgErr!, isError: true),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: AppTextStyles.label(SevaCareColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SevaCareColors.primary,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nc.text.trim();
                      final mobile = mc.text.trim();
                      if (name.isEmpty || mobile.length < 10) {
                        setDlg(
                          () => dlgErr =
                              'Name and valid 10-digit mobile are required',
                        );
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        final auth = ref.read(authProvider);
                        await ref
                            .read(repositoryProvider)
                            .upsertPatientRecord(
                              auth.tenantPublicId ?? '',
                              p.patientPublicId,
                              auth.token ?? '',
                              PatientUpsertRequest(
                                fullName: name,
                                mobileNumber: mobile,
                                status: 'active',
                                gender: gender,
                                age: int.tryParse(ac.text.trim()),
                                bloodGroup: bloodGroup,
                              ),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load(reset: true);
                      } catch (e) {
                        setDlg(() {
                          dlgErr = extractErrorMessage(
                            e,
                            fallback: 'Update failed',
                          );
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Save', style: AppTextStyles.label(Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────
  void _confirmDelete(PatientSummary p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text(
          'Delete Patient',
          style: AppTextStyles.cardTitle(SevaCareColors.text),
        ),
        content: Text(
          'Delete "${p.fullName}"?\nThis cannot be undone.',
          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.label(SevaCareColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SevaCareColors.danger,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final auth = ref.read(authProvider);
                await ref
                    .read(repositoryProvider)
                    .deletePatient(
                      auth.tenantPublicId ?? '',
                      p.patientPublicId,
                      auth.token ?? '',
                    );
                _load(reset: true);
              } catch (e) {
                if (mounted) {
                  AppSnack.error(
                      context, extractErrorMessage(e, fallback: 'Delete failed'));
                }
              }
            },
            child: Text('Delete', style: AppTextStyles.label(Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Patient row ───────────────────────────────────────────────────────────
  // Tap anywhere to open the detail sheet (edit, book, admit/discharge). The
  // row itself stays lean: name, patient ID, and — if they are an in-patient —
  // which room they are in.
  Widget _buildRow(PatientSummary p) {
    final apptLabel = _formatAppt(p.lastAppointment);
    final admission = _admitted[p.patientPublicId];
    return Material(
      color: SevaCareColors.surface,
      child: InkWell(
        onTap: () => _openDetail(p, admission),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: SevaCareColors.border, width: 0.8),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
                      style: AppTextStyles.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: SevaCareColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          p.patientPublicId,
                          style: AppTextStyles.body(
                            size: 11,
                            weight: FontWeight.w500,
                            color: SevaCareColors.textMuted,
                          ),
                        ),
                        if (p.bloodGroup != null &&
                            p.bloodGroup!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _MiniChip(
                            label: p.bloodGroup!,
                            color: SevaCareColors.danger,
                            icon: Icons.water_drop_outlined,
                          ),
                        ],
                      ],
                    ),
                    if (admission != null) ...[
                      const SizedBox(height: 4),
                      _MiniChip(
                        label: 'In ${admission.roomLabel ?? 'room'}',
                        color: SevaCareColors.primary,
                        icon: Icons.king_bed_outlined,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  p.age != null ? '${p.age}y' : '—',
                  style: AppTextStyles.label(SevaCareColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  apptLabel,
                  style: AppTextStyles.label(
                    apptLabel == '—'
                        ? SevaCareColors.textMuted
                        : SevaCareColors.primary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: SevaCareColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ── Patient detail sheet ──────────────────────────────────────────────────
  // The single place a staffer manages one patient: their details, a shortcut
  // to book, and the IPD admit/discharge action. Kept as a bottom sheet so it
  // is one tap away and dismisses with a swipe.
  void _openDetail(PatientSummary p, Admission? admission) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PatientDetailSheet(
        patient: p,
        admission: admission,
        onEdit: () {
          Navigator.pop(ctx);
          _openEdit(p);
        },
        onBook: () {
          Navigator.pop(ctx);
          final auth = ref.read(authProvider);
          widget.onBookForPatient(PatientRecord(
            patientPublicId: p.patientPublicId,
            tenantPublicId: auth.tenantPublicId ?? '',
            fullName: p.fullName,
            mobileNumber: p.mobileNumber,
            status: 'active',
            gender: p.gender,
            age: p.age,
            bloodGroup: p.bloodGroup,
          ));
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDelete(p);
        },
        onChanged: () {
          _load(reset: true);
          _loadAdmitted();
        },
      ),
    );
  }

  String _formatAppt(String? slot) {
    if (slot == null || slot.isEmpty) return '—';
    try {
      final dt = DateTime.parse(slot.replaceAll(' ', 'T'));
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final time = slot.length > 10 ? slot.substring(11, 16) : '';
      return '${dt.day} ${months[dt.month - 1]}\n$time';
    } catch (_) {
      return slot.length > 10 ? slot.substring(0, 10) : slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Patients',
                    style: AppTextStyles.sectionTitle(SevaCareColors.text),
                  ),
                  if (!_loading && _error == null)
                    Text(
                      '$_total patient${_total == 1 ? '' : 's'}  ·  showing ${_patients.length}',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: SevaCareColors.textMuted,
                ),
                tooltip: 'Refresh',
                onPressed: () => _load(reset: true),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search
          AppFormField(
            label: '',
            placeholder: 'Search by name or mobile…',
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 4),

          // Visited-between filter + default hint
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickVisitRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _visitFrom != null ? SevaCareColors.primarySoft : SevaCareColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _visitFrom != null
                          ? SevaCareColors.primary.withValues(alpha: 0.35)
                          : SevaCareColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range_outlined,
                          size: 14,
                          color: _visitFrom != null ? SevaCareColors.primary : SevaCareColors.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        _visitFrom == null
                            ? 'Visited between…'
                            : '${_fromDateStr!}  →  ${_toDateStr!}',
                        style: AppTextStyles.label(
                            _visitFrom != null ? SevaCareColors.primary : SevaCareColors.textMuted),
                      ),
                      if (_visitFrom != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _clearVisitRange,
                          child: const Icon(Icons.close, size: 14, color: SevaCareColors.primary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_visitFrom == null && _searchCtrl.text.isEmpty)
                Text('Most recent first',
                    style: AppTextStyles.label(SevaCareColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: ShimmerList(count: 4, cardHeight: 72),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Banner(msg: _error!, isError: true),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Retry',
                      onPressed: () => _load(reset: true),
                    ),
                  ],
                ),
              ),
            )
          else if (_patients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _visitFrom != null
                      ? 'No patients visited in the selected dates.'
                      : _searchCtrl.text.isEmpty
                          ? 'No patients registered yet.'
                          : 'No patients match your search.',
                  style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(
              children: [
                // Table header
                Container(
                  color: SevaCareColors.primarySoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _SortableHeader(
                          label: 'Name',
                          column: 'name',
                          activeColumn: _sortBy,
                          dir: _sortDir,
                          onTap: () => _toggleSort('name'),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: _SortableHeader(
                          label: 'Age',
                          column: 'age',
                          activeColumn: _sortBy,
                          dir: _sortDir,
                          alignment: MainAxisAlignment.center,
                          onTap: () => _toggleSort('age'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SortableHeader(
                          label: 'Last Appt',
                          column: 'lastAppointment',
                          activeColumn: _sortBy,
                          dir: _sortDir,
                          alignment: MainAxisAlignment.center,
                          onTap: () => _toggleSort('lastAppointment'),
                        ),
                      ),
                      SizedBox(
                        width: 104,
                        child: Text(
                          'Actions',
                          style: AppTextStyles.label(SevaCareColors.primary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rows — shrink-wrapped since this flows inside AppShell's own
                // page-level scroll view, not a bounded-height parent.
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _patients.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _patients.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return StaggeredItem(
                      index: i,
                      child: _buildRow(_patients[i]),
                    );
                  },
                ),
                // Load more button (fallback if scroll doesn't trigger)
                if (_hasMore && !_loadingMore)
                  TextButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more, size: 16),
                    label: Text(
                      'Load more (${_total - _patients.length} remaining)',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Action icon button ────────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18, color: color),
    tooltip: tooltip,
    onPressed: onTap,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  );
}

// ── Shared small widgets ──────────────────────────────────────────────────────

// ── Vitals Section (mirrors the doctor's consultation vitals accordion) ───────

class _StaffVitalsSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController systolicCtrl;
  final TextEditingController diastolicCtrl;
  final TextEditingController tempCtrl;
  final TextEditingController pulseCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController spo2Ctrl;
  final TextEditingController sugarCtrl;

  const _StaffVitalsSection({
    required this.expanded,
    required this.onToggle,
    required this.systolicCtrl,
    required this.diastolicCtrl,
    required this.tempCtrl,
    required this.pulseCtrl,
    required this.weightCtrl,
    required this.spo2Ctrl,
    required this.sugarCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 16,
                color: expanded ? SevaCareColors.mint : SevaCareColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Vitals (optional)',
                      style: AppTextStyles.sectionTitle(SevaCareColors.text),
                    ),
                    Text(
                      'BP · Temperature · Weight · Pulse · SpO₂',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: SevaCareColors.textMuted,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StaffVitalInput(label: 'Systolic BP', unit: 'mmHg', ctrl: systolicCtrl, hint: '120')),
            const SizedBox(width: 12),
            Expanded(child: _StaffVitalInput(label: 'Diastolic BP', unit: 'mmHg', ctrl: diastolicCtrl, hint: '80')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StaffVitalInput(label: 'Temperature', unit: '°C', ctrl: tempCtrl, hint: '37.0')),
            const SizedBox(width: 12),
            Expanded(child: _StaffVitalInput(label: 'Pulse Rate', unit: 'bpm', ctrl: pulseCtrl, hint: '72')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StaffVitalInput(label: 'Weight', unit: 'kg', ctrl: weightCtrl, hint: '70')),
            const SizedBox(width: 12),
            Expanded(child: _StaffVitalInput(label: 'SpO₂', unit: '%', ctrl: spo2Ctrl, hint: '98')),
          ]),
          const SizedBox(height: 10),
          _StaffVitalInput(label: 'Blood Sugar', unit: 'mg/dL', ctrl: sugarCtrl, hint: '110'),
        ],
      ],
    );
  }
}

class _StaffVitalInput extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController ctrl;
  final String hint;

  const _StaffVitalInput({
    required this.label,
    required this.unit,
    required this.ctrl,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(SevaCareColors.textMuted)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: AppTextStyles.inputText(SevaCareColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputHint(
              SevaCareColors.textMuted.withValues(alpha: 0.5),
            ),
            suffixText: unit,
            suffixStyle: AppTextStyles.label(SevaCareColors.mint),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SevaCareColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SevaCareColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SevaCareColors.mint, width: 2),
            ),
            filled: true,
            fillColor: SevaCareColors.surface,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  const _Card({
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: icon, title: title, trailing: trailing),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: SevaCareColors.primary),
      const SizedBox(width: 6),
      Text(title, style: AppTextStyles.sectionTitle(SevaCareColors.text)),
      if (trailing != null) ...[const Spacer(), trailing!],
    ],
  );
}

class _Spinner extends StatelessWidget {
  final String label;
  const _Spinner({required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 10),
      Text(label, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
    ],
  );
}

class _RetryRow extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _RetryRow({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.error_outline, size: 16, color: SevaCareColors.danger),
      const SizedBox(width: 6),
      Expanded(
        child: Text(msg, style: AppTextStyles.label(SevaCareColors.danger)),
      ),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}

class _SlotAccordionSection extends StatelessWidget {
  final String title;
  final List<String> slots;
  final List<String> booked;
  final List<String> blocked;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool expanded;
  final VoidCallback onToggle;

  const _SlotAccordionSection({
    required this.title,
    required this.slots,
    required this.booked,
    this.blocked = const [],
    required this.selected,
    required this.onSelect,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: SevaCareColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: AppTextStyles.label(SevaCareColors.textMuted)),
                  ),
                  Text('${slots.length}',
                      style: AppTextStyles.label(SevaCareColors.textMuted)),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: SevaCareColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _SlotGrid(
                slots: slots,
                booked: booked,
                blocked: blocked,
                selected: selected,
                onSelect: onSelect,
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  final List<String> slots;
  final List<String> booked;
  final List<String> blocked;
  final String selected;
  final ValueChanged<String> onSelect;
  const _SlotGrid({
    required this.slots,
    required this.booked,
    this.blocked = const [],
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: slots.map((s) {
      final isBooked = booked.contains(s);
      final isBlocked = blocked.contains(s);
      final unavailable = isBooked || isBlocked;
      final isSel = selected == s;
      return GestureDetector(
        onTap: unavailable ? null : () => onSelect(s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isBlocked
                ? SevaCareColors.warningSurface
                : isBooked
                ? SevaCareColors.border
                : isSel
                ? SevaCareColors.primary
                : SevaCareColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBlocked
                  ? SevaCareColors.warning.withValues(alpha: 0.5)
                  : isBooked
                  ? SevaCareColors.border
                  : isSel
                  ? SevaCareColors.primary
                  : SevaCareColors.border,
            ),
          ),
          child: Text(
            s,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isBlocked
                  ? SevaCareColors.warning
                  : isBooked
                  ? SevaCareColors.textMuted
                  : isSel
                  ? Colors.white
                  : SevaCareColors.text,
              decoration: isBooked ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? SevaCareColors.primary : SevaCareColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: selected ? SevaCareColors.primary : SevaCareColors.border,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.label(
          selected ? SevaCareColors.textOnPrimary : SevaCareColors.textMuted,
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  final String msg;
  final bool isError;
  const _Banner({required this.msg, required this.isError});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFFEDED) : SevaCareColors.mintSoft;
    final fg = isError ? SevaCareColors.danger : SevaCareColors.mintForeground;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: AppTextStyles.label(fg))),
        ],
      ),
    );
  }
}

// ── Small pill used in patient rows and room cards ────────────────────────────

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _MiniChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.body(
                size: 10.5, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Patient detail sheet ──────────────────────────────────────────────────────
// One patient, one place: their details, a shortcut to book, and the IPD
// admit/discharge action. Admission state is kept locally so the sheet updates
// the moment the staffer admits or discharges, without a full reload behind it.

class _PatientDetailSheet extends ConsumerStatefulWidget {
  final PatientSummary patient;
  final Admission? admission;
  final VoidCallback onEdit;
  final VoidCallback onBook;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  const _PatientDetailSheet({
    required this.patient,
    required this.admission,
    required this.onEdit,
    required this.onBook,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  ConsumerState<_PatientDetailSheet> createState() =>
      _PatientDetailSheetState();
}

class _PatientDetailSheetState extends ConsumerState<_PatientDetailSheet> {
  Admission? _admission;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _admission = widget.admission;
  }

  Future<void> _admit() async {
    final selection = await showModalBottomSheet<({int roomId, String notes})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdmitRoomSheet(patientName: widget.patient.fullName),
    );
    if (selection == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authProvider);
      final adm = await ref.read(repositoryProvider).admitPatient(
            auth.tenantPublicId ?? '',
            auth.token ?? '',
            widget.patient.patientPublicId,
            selection.roomId,
            selection.notes.isEmpty ? null : selection.notes,
          );
      if (!mounted) return;
      setState(() {
        _admission = adm;
        _busy = false;
      });
      widget.onChanged();
      AppSnack.success(context, 'Admitted to ${adm.roomLabel ?? 'room'}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(context, extractErrorMessage(e, fallback: 'Could not admit'));
    }
  }

  Future<void> _discharge() async {
    final adm = _admission;
    if (adm == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text('Discharge patient',
            style: AppTextStyles.cardTitle(SevaCareColors.text)),
        content: Text(
          'Discharge ${widget.patient.fullName} from ${adm.roomLabel ?? 'the room'}? '
          'The room becomes available.',
          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: SevaCareColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discharge', style: AppTextStyles.label(Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).dischargePatient(
            auth.tenantPublicId ?? '',
            auth.token ?? '',
            adm.admissionId,
          );
      if (!mounted) return;
      setState(() {
        _admission = null;
        _busy = false;
      });
      widget.onChanged();
      AppSnack.success(context, 'Discharged');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
          context, extractErrorMessage(e, fallback: 'Could not discharge'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final adm = _admission;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SevaCareColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(p.fullName,
                style: AppTextStyles.sectionTitle(SevaCareColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('Patient ID · ${p.patientPublicId}',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _detailPill(Icons.phone_outlined, p.mobileNumber),
                if (p.age != null) _detailPill(Icons.cake_outlined, '${p.age} yrs'),
                if (p.gender != null && p.gender!.isNotEmpty)
                  _detailPill(Icons.person_outline, _capitalize(p.gender!)),
                _detailPill(
                    Icons.water_drop_outlined,
                    (p.bloodGroup != null && p.bloodGroup!.isNotEmpty)
                        ? p.bloodGroup!
                        : 'Blood group —'),
              ],
            ),
            if (adm != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SevaCareColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: SevaCareColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.king_bed_outlined,
                        size: 18, color: SevaCareColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'In-patient · ${adm.roomLabel ?? 'room'}'
                        '${adm.admittedAt != null ? '\nSince ${adm.admittedAt}' : ''}',
                        style: AppTextStyles.bodyText(SevaCareColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (adm == null)
              PrimaryButton(
                label: 'Admit to a room',
                isLoading: _busy,
                onPressed: _busy ? null : _admit,
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SevaCareColors.danger,
                    side: BorderSide(
                        color: SevaCareColors.danger.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(_busy ? 'Working…' : 'Discharge'),
                  onPressed: _busy ? null : _discharge,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SevaCareColors.primary,
                      side: const BorderSide(color: SevaCareColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit'),
                    onPressed: _busy ? null : widget.onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SevaCareColors.primary,
                      side: const BorderSide(color: SevaCareColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.calendar_month_outlined, size: 17),
                    label: const Text('Book'),
                    onPressed: _busy ? null : widget.onBook,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: SevaCareColors.danger),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('Delete patient'),
                onPressed: _busy ? null : widget.onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SevaCareColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SevaCareColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: SevaCareColors.textMuted),
          const SizedBox(width: 5),
          Text(text, style: AppTextStyles.label(SevaCareColors.text)),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Admit room picker ─────────────────────────────────────────────────────────
// Lists only the rooms that are free right now, so a staffer can never admit
// into an occupied one. Returns (roomId, notes) to the caller, which performs
// the admit.

class _AdmitRoomSheet extends ConsumerStatefulWidget {
  final String patientName;
  const _AdmitRoomSheet({required this.patientName});

  @override
  ConsumerState<_AdmitRoomSheet> createState() => _AdmitRoomSheetState();
}

class _AdmitRoomSheetState extends ConsumerState<_AdmitRoomSheet> {
  List<Room> _rooms = [];
  bool _loading = true;
  String? _error;
  int? _selectedRoomId;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final rooms = await ref
          .read(repositoryProvider)
          .getRooms(auth.tenantPublicId ?? '', auth.token ?? '');
      if (mounted) {
        setState(() {
          _rooms = rooms.where((r) => !r.isOccupied).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Could not load rooms');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SevaCareColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Admit ${widget.patientName}',
                style: AppTextStyles.sectionTitle(SevaCareColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('Choose an available room',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _Banner(msg: _error!, isError: true)
            else if (_rooms.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SevaCareColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.meeting_room_outlined,
                        color: SevaCareColors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'No free rooms right now.\nAdd rooms in the Rooms tab first.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                    ),
                  ],
                ),
              )
            else ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.38),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in _rooms)
                        _ToggleChip(
                          label: (r.roomType != null && r.roomType!.isNotEmpty)
                              ? '${r.label} · ${r.roomType}'
                              : r.label,
                          selected: _selectedRoomId == r.roomId,
                          onTap: () =>
                              setState(() => _selectedRoomId = r.roomId),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppFormField(
                label: 'Notes (optional)',
                placeholder: 'Reason for admission, ward notes…',
                controller: _notesCtrl,
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Admit',
                onPressed: _selectedRoomId == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          (
                            roomId: _selectedRoomId!,
                            notes: _notesCtrl.text.trim()
                          ),
                        ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Rooms tab ─────────────────────────────────────────────────────────────────
// The bed board: add rooms, see at a glance who is where, and discharge in one
// tap. Admitting starts from a patient (Patients tab → detail sheet), because
// that is where the staffer already is when a patient needs a bed.

class _RoomsTab extends ConsumerStatefulWidget {
  const _RoomsTab();

  @override
  ConsumerState<_RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends ConsumerState<_RoomsTab> with AutoRefreshMixin {
  List<Room> _rooms = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    startAutoRefresh(() => _load());
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final auth = ref.read(authProvider);
      final rooms = await ref
          .read(repositoryProvider)
          .getRooms(auth.tenantPublicId ?? '', auth.token ?? '');
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Could not load rooms');
          _loading = false;
        });
      }
    }
  }

  Future<void> _addRoom() async {
    final labelCtrl = TextEditingController();
    String? roomType;
    bool saving = false;
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: SevaCareColors.surface,
          title:
              Text('Add room', style: AppTextStyles.cardTitle(SevaCareColors.text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFormField(
                  label: 'Room number / name',
                  placeholder: 'e.g. 101, ICU-2',
                  controller: labelCtrl,
                  required: true,
                ),
                const SizedBox(height: 6),
                Text('Type (optional)',
                    style: AppTextStyles.label(SevaCareColors.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in const ['General', 'Private', 'ICU', 'Ward'])
                      _ToggleChip(
                        label: t,
                        selected: roomType == t,
                        onTap: () =>
                            setDlg(() => roomType = roomType == t ? null : t),
                      ),
                  ],
                ),
                if (err != null) ...[
                  const SizedBox(height: 10),
                  _Banner(msg: err!, isError: true),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTextStyles.label(SevaCareColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: SevaCareColors.primary),
              onPressed: saving
                  ? null
                  : () async {
                      final label = labelCtrl.text.trim();
                      if (label.isEmpty) {
                        setDlg(() => err = 'Room number is required');
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        final auth = ref.read(authProvider);
                        await ref.read(repositoryProvider).createRoom(
                              auth.tenantPublicId ?? '',
                              auth.token ?? '',
                              label,
                              roomType,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load(initial: true);
                      } catch (e) {
                        setDlg(() {
                          err = extractErrorMessage(e,
                              fallback: 'Could not add room');
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Add', style: AppTextStyles.label(Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRoom(Room r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title:
            Text('Remove room', style: AppTextStyles.cardTitle(SevaCareColors.text)),
        content: Text('Remove ${r.label}? This cannot be undone.',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: SevaCareColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: AppTextStyles.label(Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).deleteRoom(
          auth.tenantPublicId ?? '', auth.token ?? '', r.roomId);
      _load(initial: true);
    } catch (e) {
      if (mounted) {
        AppSnack.error(
            context, extractErrorMessage(e, fallback: 'Could not remove room'));
      }
    }
  }

  Future<void> _discharge(Room r) async {
    final admissionId = r.admissionId;
    if (admissionId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text('Discharge patient',
            style: AppTextStyles.cardTitle(SevaCareColors.text)),
        content: Text(
          'Discharge ${r.occupantName ?? 'the patient'} from ${r.label}? '
          'The room becomes available.',
          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: SevaCareColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discharge', style: AppTextStyles.label(Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).dischargePatient(
          auth.tenantPublicId ?? '', auth.token ?? '', admissionId);
      _load(initial: true);
    } catch (e) {
      if (mounted) {
        AppSnack.error(
            context, extractErrorMessage(e, fallback: 'Could not discharge'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _rooms.where((r) => !r.isOccupied).length;
    final occupied = _rooms.length - available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rooms',
                    style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                if (!_loading && _error == null)
                  Text(
                    '${_rooms.length} room${_rooms.length == 1 ? '' : 's'}  ·  '
                    '$available free  ·  $occupied occupied',
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh,
                  size: 18, color: SevaCareColors.textMuted),
              tooltip: 'Refresh',
              onPressed: () => _load(initial: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: SevaCareColors.primary,
              side:
                  BorderSide(color: SevaCareColors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add room'),
            onPressed: _addRoom,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const ShimmerList(count: 4, cardHeight: 64)
        else if (_error != null)
          _Banner(msg: _error!, isError: true)
        else if (_rooms.isEmpty)
          _emptyRooms()
        else
          ..._rooms.map(_roomCard),
      ],
    );
  }

  Widget _emptyRooms() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: SevaCareColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.king_bed_outlined,
              size: 32, color: SevaCareColors.textMuted),
          const SizedBox(height: 10),
          Text('No rooms yet',
              style: AppTextStyles.cardTitle(SevaCareColors.text)),
          const SizedBox(height: 4),
          Text(
            'Add your wards and rooms to start admitting in-patients.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _roomCard(Room r) {
    final occupied = r.isOccupied;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: occupied
              ? SevaCareColors.primary.withValues(alpha: 0.30)
              : SevaCareColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: occupied
                  ? SevaCareColors.primarySoft
                  : SevaCareColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.king_bed_outlined,
                color: occupied
                    ? SevaCareColors.primary
                    : SevaCareColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(r.label,
                          style: AppTextStyles.cardTitle(SevaCareColors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (r.roomType != null && r.roomType!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _MiniChip(
                          label: r.roomType!, color: SevaCareColors.textMuted),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  occupied ? (r.occupantName ?? 'Occupied') : 'Available',
                  style: AppTextStyles.label(
                      occupied ? SevaCareColors.primary : SevaCareColors.mint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (occupied)
            _ActionIcon(
              icon: Icons.logout,
              color: SevaCareColors.danger,
              tooltip: 'Discharge',
              onTap: () => _discharge(r),
            )
          else
            _ActionIcon(
              icon: Icons.delete_outline,
              color: SevaCareColors.textMuted,
              tooltip: 'Remove',
              onTap: () => _deleteRoom(r),
            ),
        ],
      ),
    );
  }
}
