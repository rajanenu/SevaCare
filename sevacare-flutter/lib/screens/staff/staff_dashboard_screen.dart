import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
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

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: auth.role,
      bottomNavItems: _bottomNav,
      currentNavIndex: 0,
      onNavTap: (i) {
        if (i < _bottomNav.length) context.go(_bottomNav[i].route);
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'IP-Staff Portal',
            subtitle:
                'Welcome, ${auth.subjectName.isNotEmpty ? auth.subjectName : "Staff"}',
          ),
          const SizedBox(height: 12),
          _TabBar(
            selected: _tab,
            onSelect: (i) => setState(() {
              _tab = i;
              if (i != 0) _prefillPatient = null;
            }),
          ),
          const SizedBox(height: 16),
          _tab == 0
              ? _BookTab(
                  key: ValueKey(_prefillPatient?.patientPublicId ?? '__new__'),
                  prefill: _prefillPatient,
                  onClearPrefill: () => setState(() => _prefillPatient = null),
                )
              : _PatientsTab(onBookForPatient: _bookForExistingPatient),
        ],
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
      (icon: Icons.calendar_month_outlined, label: 'Book Appointment'),
      (icon: Icons.people_outline, label: 'Patients'),
    ];
    return Row(
      children: List.generate(tabs.length, (i) {
        final active = i == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(
                right: i == 0 ? 6 : 0,
                left: i == 1 ? 6 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
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

  // Booking options
  BookingSetupView? _setup;
  List<DoctorSummary> _doctors = [];
  bool _loadingSetup = true;
  String? _setupError;

  // Selections
  String _specialty = '';
  String _doctorId = '';
  String _doctorName = '';
  String _date = '';
  String _slot = '';
  List<String> _bookedSlots = [];
  bool _loadingSlots = false;

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

  Future<void> _loadBookedSlots() async {
    if (_doctorId.isEmpty || _date.isEmpty) return;
    setState(() {
      _loadingSlots = true;
      _bookedSlots = [];
      _slot = '';
    });
    try {
      final auth = ref.read(authProvider);
      final slots = await ref
          .read(repositoryProvider)
          .getBookedSlots(
            auth.tenantPublicId ?? '',
            _doctorId,
            _date,
            auth.token ?? '',
          );
      if (mounted)
        setState(() {
          _bookedSlots = slots;
          _loadingSlots = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
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
    if (_slot.isEmpty) {
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
          slot: '$_date $_slot',
          note: 'Booked by IP-Staff: $staffId',
        ),
      );

      if (mounted) {
        widget.onClearPrefill();
        setState(() {
          _success =
              'Appointment booked with $_doctorName on $_date at $_slot.\nAdded to doctor\'s queue.';
          _nameCtrl.clear();
          _mobileCtrl.clear();
          _ageCtrl.clear();
          _gender = 'male';
          _doctorId = '';
          _doctorName = '';
          _slot = '';
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

          // ── Patient Details ───────────────────────────────────────────────────
          _Card(
            icon: Icons.person_outline,
            title: 'Patient Details',
            child: Column(
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
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Specialty & Doctor ────────────────────────────────────────────────
          _Card(
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
            child: _loadingSetup
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
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _doctorId = doc.doctorPublicId;
                                    _doctorName = doc.name;
                                    _slot = '';
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
                                    color: sel
                                        ? SevaCareColors.primary
                                        : SevaCareColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusPill,
                                    ),
                                    border: Border.all(
                                      color: sel
                                          ? SevaCareColors.primary
                                          : SevaCareColors.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.name,
                                        style: AppTextStyles.body(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: sel
                                              ? SevaCareColors.textOnPrimary
                                              : SevaCareColors.text,
                                        ),
                                      ),
                                      Text(
                                        doc.specialty,
                                        style: AppTextStyles.label(
                                          sel
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
          ),

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
              icon: Icons.access_time_outlined,
              title: 'Select Time Slot',
              child: _loadingSlots
                  ? const _Spinner(label: 'Loading available slots…')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_setup!.morningSlots.isNotEmpty) ...[
                          Text(
                            'Morning  09:00 – 14:00',
                            style: AppTextStyles.label(
                              SevaCareColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _SlotGrid(
                            slots: _setup!.morningSlots,
                            booked: _bookedSlots,
                            selected: _slot,
                            onSelect: (s) => setState(() => _slot = s),
                          ),
                        ],
                        if (_setup!.eveningSlots.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Evening  17:00 – 21:00',
                            style: AppTextStyles.label(
                              SevaCareColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _SlotGrid(
                            slots: _setup!.eveningSlots,
                            booked: _bookedSlots,
                            selected: _slot,
                            onSelect: (s) => setState(() => _slot = s),
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

          // ── Info + errors + submit ─────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SevaCareColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: SevaCareColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: SevaCareColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Appointment is tagged as IP-Staff booking and appears directly in the doctor\'s queue.',
                    style: AppTextStyles.label(SevaCareColors.primary),
                  ),
                ),
              ],
            ),
          ),
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

  static const _pageSize = 10;

  bool get _hasMore => _patients.length < _total;

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
                        child: Text(
                          'Patient',
                          style: AppTextStyles.label(SevaCareColors.primary),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          'Age',
                          style: AppTextStyles.label(SevaCareColors.primary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Last Appt',
                          style: AppTextStyles.label(SevaCareColors.primary),
                          textAlign: TextAlign.center,
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
        Row(
          children: [
            Icon(icon, size: 16, color: SevaCareColors.primary),
            const SizedBox(width: 6),
            Text(title, style: AppTextStyles.sectionTitle(SevaCareColors.text)),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
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

class _SlotGrid extends StatelessWidget {
  final List<String> slots;
  final List<String> booked;
  final String selected;
  final ValueChanged<String> onSelect;
  const _SlotGrid({
    required this.slots,
    required this.booked,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: slots.map((s) {
      final isBooked = booked.contains(s);
      final isSel = selected == s;
      return GestureDetector(
        onTap: isBooked ? null : () => onSelect(s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isBooked
                ? SevaCareColors.border
                : isSel
                ? SevaCareColors.primary
                : SevaCareColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBooked
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
              color: isBooked
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
