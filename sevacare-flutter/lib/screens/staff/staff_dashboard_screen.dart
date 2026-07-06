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
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
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
            child: IndexedStack(
              index: _tab,
              sizing: StackFit.expand,
              children: [
                _tabPage(_BookTab(
                  key: ValueKey(_prefillPatient?.patientPublicId ?? '__new__'),
                  prefill: _prefillPatient,
                  onClearPrefill: () => setState(() => _prefillPatient = null),
                )),
                _tabPage(const _DoctorsTab()),
                _tabPage(_PatientsTab(onBookForPatient: _bookForExistingPatient)),
                _tabPage(const _StaffRequestsTab()),
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
  const _StaffHeroBanner({required this.name, required this.userId});

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
                  const SizedBox(width: 6),
                  Text(
                    tabs[i].label,
                    style: AppTextStyles.label(
                      active
                          ? SevaCareColors.textOnPrimary
                          : SevaCareColors.textMuted,
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
    });
    try {
      final auth = ref.read(authProvider);
      final status = await ref.read(repositoryProvider).getSlotStatus(
        auth.tenantPublicId ?? '', _doctorId, _date, auth.token ?? '',
      );
      if (mounted) setState(() => _status = status);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
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
    final all = [..._setup!.morningSlots, ..._setup!.eveningSlots];
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
    final totalSlots =
        (_setup?.morningSlots.length ?? 0) + (_setup?.eveningSlots.length ?? 0);

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
                              if (_setup!.morningSlots.isNotEmpty) ...[
                                Text('Morning  09:00 – 14:00',
                                    style: AppTextStyles.label(SevaCareColors.textMuted)),
                                const SizedBox(height: 6),
                                _SlotGrid(
                                  slots: _setup!.morningSlots,
                                  booked: _status!.bookedSlots,
                                  blocked: _status!.blockedSlots,
                                  selected: '',
                                  onSelect: (_) {},
                                ),
                              ],
                              if (_setup!.eveningSlots.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Evening  17:00 – 21:00',
                                    style: AppTextStyles.label(SevaCareColors.textMuted)),
                                const SizedBox(height: 6),
                                _SlotGrid(
                                  slots: _setup!.eveningSlots,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select from and to dates.')),
      );
      return;
    }
    if (_hourlyLeave) {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and end time for hourly leave.')),
        );
        return;
      }
      final startMins = _startTime!.hour * 60 + _startTime!.minute;
      final endMins = _endTime!.hour * 60 + _endTime!.minute;
      if (endMins <= startMins) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractErrorMessage(e, fallback: 'Failed to submit request.')),
          backgroundColor: SevaCareColors.danger,
        ));
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

  // Submit
  bool _booking = false;
  String? _error;
  String? _success;

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
    });
    try {
      final auth = ref.read(authProvider);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token counter reset.')),
        );
        _loadTokenPreview();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractErrorMessage(e, fallback: 'Reset failed.'))),
        );
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

      await repo.bookAppointment(
        tenantId,
        patientId,
        auth.token ?? '',
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
            ),
          ),

          // ── Slot / Token mode toggle ─────────────────────────────────────────
          if (!_loadingSetup && _setupError == null && _doctorId.isNotEmpty &&
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
          if (!_loadingSetup &&
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
                        if (_setup!.morningSlots.isNotEmpty) ...[
                          _SlotAccordionSection(
                            title: 'Morning  09:00 – 14:00',
                            slots: _setup!.morningSlots,
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
                        if (_setup!.eveningSlots.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _SlotAccordionSection(
                            title: 'Evening  17:00 – 21:00',
                            slots: _setup!.eveningSlots,
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
                        if (_setup!.morningSlots.isEmpty &&
                            _setup!.eveningSlots.isEmpty)
                          Text(
                            'No slots configured.',
                            style: AppTextStyles.bodyText(
                              SevaCareColors.textMuted,
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
            label: 'Book Appointment',
            icon: Icons.check_circle_outline,
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

class _PatientsTab extends ConsumerStatefulWidget {
  final ValueChanged<PatientRecord> onBookForPatient;
  const _PatientsTab({required this.onBookForPatient});

  @override
  ConsumerState<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends ConsumerState<_PatientsTab> {
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;

  List<PatientSummary> _patients = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  String? _sortBy;
  String _sortDir = 'asc';

  static const _pageSize = 10;

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        extractErrorMessage(e, fallback: 'Delete failed'),
                      ),
                      backgroundColor: SevaCareColors.danger,
                    ),
                  );
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
  Widget _buildRow(PatientSummary p) {
    final apptLabel = _formatAppt(p.lastAppointment);
    return Container(
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        border: Border(
          bottom: BorderSide(color: SevaCareColors.border, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Name + mobile
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
                Text(
                  p.mobileNumber,
                  style: AppTextStyles.label(SevaCareColors.textMuted),
                ),
              ],
            ),
          ),
          // Age
          SizedBox(
            width: 36,
            child: Text(
              p.age != null ? '${p.age}y' : '—',
              style: AppTextStyles.label(SevaCareColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
          // Last appointment
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
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIcon(
                icon: Icons.calendar_month_outlined,
                color: SevaCareColors.primary,
                tooltip: 'Book',
                onTap: () {
                  final auth = ref.read(authProvider);
                  widget.onBookForPatient(
                    PatientRecord(
                      patientPublicId: p.patientPublicId,
                      tenantPublicId: auth.tenantPublicId ?? '',
                      fullName: p.fullName,
                      mobileNumber: p.mobileNumber,
                      status: 'active',
                      gender: p.gender,
                      age: p.age,
                    ),
                  );
                },
              ),
              _ActionIcon(
                icon: Icons.edit_outlined,
                color: SevaCareColors.textMuted,
                tooltip: 'Edit',
                onTap: () => _openEdit(p),
              ),
              _ActionIcon(
                icon: Icons.delete_outline,
                color: SevaCareColors.danger,
                tooltip: 'Delete',
                onTap: () => _confirmDelete(p),
              ),
            ],
          ),
        ],
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
                  _searchCtrl.text.isEmpty
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
