import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// ── Admin bottom nav items ────────────────────────────────────────────────────

List<BottomNavItem> _adminNavItems() => const [
  BottomNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/admin'),
  BottomNavItem(label: 'Admins', icon: Icons.manage_accounts_outlined, route: '/admin/users'),
  BottomNavItem(label: 'Doctors', icon: Icons.medical_services_outlined, route: '/admin/doctors'),
  BottomNavItem(label: 'Reports', icon: Icons.bar_chart_outlined, route: '/admin/reports'),
  BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/admin/profile'),
];

// ── Root screen with tab controller ──────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const AdminDashboardScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
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
    final auth = ref.watch(authProvider);
    final isGeneric = auth.isGenericAdmin;

    // Generic admin: restricted view — only Admin Users tab
    if (isGeneric) {
      return AppShell(
        hospitalName: hospital.hospitalName.isNotEmpty ? hospital.hospitalName : 'SevaCare',
        role: UserRole.admin,
        bottomNavItems: _adminNavItems(),
        currentNavIndex: widget.initialTab,
        onNavTap: _handleNavTap,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(title: 'Hospital Setup'),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You are logged in as Generic Admin. Add at least 2 hospital admins to unlock full access.',
                      style: AppTextStyles.bodyText(Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const _AdminUsersTab(),
          ],
        ),
      );
    }

    // Full dashboard for real admins
    final tabs = [
      SegmentItem<int>(value: 0, label: 'Dashboard'),
      SegmentItem<int>(value: 1, label: 'Admin Users'),
      SegmentItem<int>(value: 2, label: 'Doctors'),
      SegmentItem<int>(value: 3, label: 'Reports'),
    ];

    Widget tabBody;
    switch (_tabIndex) {
      case 1:
        tabBody = const _AdminUsersTab();
        break;
      case 2:
        tabBody = const _DoctorManagementTab();
        break;
      case 3:
        tabBody = const _ReportsTab();
        break;
      default:
        tabBody = const _DashboardTab();
    }

    return AppShell(
      hospitalName: hospital.hospitalName.isNotEmpty ? hospital.hospitalName : 'SevaCare',
      role: UserRole.admin,
      bottomNavItems: _adminNavItems(),
      currentNavIndex: widget.initialTab,
      onNavTap: _handleNavTap,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Operations Dashboard'),
          const SizedBox(height: 12),
          SegmentedControl<int>(
            items: tabs,
            selected: _tabIndex,
            onChanged: (v) => setState(() => _tabIndex = v),
          ),
          const SizedBox(height: 16),
          tabBody,
        ],
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

class _DashboardTabState extends ConsumerState<_DashboardTab> {
  AdminOverview? _overview;
  List<DoctorRecord> _doctors = [];
  bool _loading = true;
  String? _error;
  int _visitSegment = 1; // 0=Today, 1=Week, 2=Month, 3=Year

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
      final token = auth.token ?? '';
      final tenantId = hospital.tenantPublicId;

      final results = await Future.wait([
        repo.getAdminOverview(tenantId, token),
        repo.listDoctorRecords(tenantId, token),
      ]);

      if (mounted) {
        setState(() {
          _overview = results[0] as AdminOverview;
          _doctors = results[1] as List<DoctorRecord>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load dashboard overview.');
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
      return Column(children: [
        const ShimmerMetricRow(),
        const SizedBox(height: 10),
        const ShimmerMetricRow(),
        const SizedBox(height: 10),
        const ShimmerList(count: 2, cardHeight: 70),
      ]);
    }

    if (_error != null) {
      return AppCard(
        child: Column(
          children: [
            Text('Failed to load overview', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
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

    // Pull overview metric values for patient visits section
    final totalVisits = overview?.metrics.isNotEmpty == true ? overview!.metrics[0].value : '0';
    final bookedSlots = overview?.metrics.length != null && overview!.metrics.length > 1
        ? overview.metrics[1].value
        : '0';
    final prescriptions = overview?.metrics.length != null && overview!.metrics.length > 2
        ? overview.metrics[2].value
        : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hospital Overview ──────────────────────────────────────────────────
        Text('Hospital Overview', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        const SizedBox(height: 12),
        if (overview != null && overview.metrics.isNotEmpty) ...[
          MetricRow(
            tiles: [
              for (int i = 0; i < overview.metrics.length && i < 3; i++)
                MetricTile(
                  value: overview.metrics[i].value,
                  label: overview.metrics[i].label,
                  variant: i == 0
                      ? MetricVariant.primary
                      : i == 1
                          ? MetricVariant.mint
                          : MetricVariant.peach,
                  trend: overview.metrics[i].trend,
                ),
            ],
          ),
        ] else ...[
          MetricRow(
            tiles: [
              MetricTile(value: '0', label: 'Daily Visits', variant: MetricVariant.primary),
              MetricTile(value: '0', label: 'Booked Slots', variant: MetricVariant.mint),
              MetricTile(value: '0', label: 'Prescriptions Issued', variant: MetricVariant.peach),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // ── Doctors by Department ─────────────────────────────────────────────
        Text('Doctors by Department', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
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
                          value: '${specialtyCounts.entries.elementAt(i + 1).value}',
                          label: specialtyCounts.entries.elementAt(i + 1).key,
                          variant: MetricVariant.primary,
                        )
                      else
                        MetricTile(value: '', label: '', variant: MetricVariant.primary),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),

        // ── Patient Visits ─────────────────────────────────────────────────────
        Text('Patient Visits', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        const SizedBox(height: 12),
        SegmentedControl<int>(
          items: visitSegments,
          selected: _visitSegment,
          onChanged: (v) => setState(() => _visitSegment = v),
        ),
        const SizedBox(height: 12),
        MetricRow(
          tiles: [
            MetricTile(value: totalVisits, label: 'Total Visits', variant: MetricVariant.primary),
            MetricTile(value: bookedSlots, label: 'Upcoming', variant: MetricVariant.mint),
          ],
        ),
        const SizedBox(height: 8),
        MetricRow(
          tiles: [
            MetricTile(value: prescriptions, label: 'Completed', variant: MetricVariant.peach),
            MetricTile(value: '0', label: 'Cancelled', variant: MetricVariant.danger),
          ],
        ),
        const SizedBox(height: 16),
      ],
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
    // Load on demand — user taps "Load Admin Users" button
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
        list.sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        setState(() {
          _admins = list;
          _page = 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load admin users.');
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
      final id = await repo.getNextAdminId(hospital.tenantPublicId, auth.token ?? '');
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
          email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
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
          _formError = extractErrorMessage(e, fallback: 'Failed to create admin user.');
        });
      }
    }
  }

  Future<void> _deleteAdmin(String adminId) async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.deleteAdminUser(hospital.tenantPublicId, adminId, auth.token ?? '');
      await _loadAdmins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: SevaCareColors.danger),
        );
      }
    }
  }

  Future<void> _deactivateAdmin(String adminId) async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.deactivateAdminUser(hospital.tenantPublicId, adminId, auth.token ?? '');
      await _loadAdmins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deactivate failed: $e'), backgroundColor: SevaCareColors.danger),
        );
      }
    }
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final filterSegments = [
      SegmentItem<int>(value: 0, label: 'All'),
      SegmentItem<int>(value: 1, label: 'Active only'),
    ];

    final totalPages = _admins.isEmpty ? 1 : (_admins.length / _pageSize).ceil();
    final paged = _admins.skip(_page * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workspace card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin workspace', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
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
                Text('New Admin User', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                if (_nextAdminId != null) ...[
                  const SizedBox(height: 4),
                  Text('ID: $_nextAdminId', style: AppTextStyles.label(SevaCareColors.textMuted)),
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
                    child: Text(_formError!, style: AppTextStyles.bodyText(SevaCareColors.danger)),
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
                    child: Text(_formSuccess!, style: AppTextStyles.bodyText(SevaCareColors.mintForeground)),
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
                Text('Error loading admins', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
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
                          AppAvatar(
                            initials: _initials(admin.fullName),
                            hue: AppAvatar.hueFromString(admin.adminPublicId),
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  admin.fullName,
                                  style: AppTextStyles.cardTitle(SevaCareColors.text),
                                ),
                                Text(
                                  admin.adminPublicId,
                                  style: AppTextStyles.label(SevaCareColors.textMuted),
                                ),
                                if (admin.mobileNumber != null && admin.mobileNumber!.isNotEmpty)
                                  Text(
                                    admin.mobileNumber!,
                                    style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                                  ),
                                if (admin.email != null && admin.email!.isNotEmpty)
                                  Text(
                                    admin.email!,
                                    style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          StatusBadge(status: admin.active ? 'active' : 'inactive'),
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
                            onPressed: () => _deleteAdmin(admin.adminPublicId),
                          ),
                          if (admin.active) ...[
                            const SizedBox(width: 8),
                            IconBtn(
                              icon: Icons.pause_circle_outline,
                              iconColor: SevaCareColors.peachForeground,
                              bgColor: SevaCareColors.peachSoft,
                              tooltip: 'Deactivate',
                              onPressed: () => _deactivateAdmin(admin.adminPublicId),
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
                      onTap: _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      child: Opacity(
                        opacity: _page > 0 ? 1.0 : 0.4,
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

// ── TAB 2: Doctor Management ──────────────────────────────────────────────────

class _DoctorManagementTab extends ConsumerStatefulWidget {
  const _DoctorManagementTab();

  @override
  ConsumerState<_DoctorManagementTab> createState() => _DoctorManagementTabState();
}

class _DoctorManagementTabState extends ConsumerState<_DoctorManagementTab> {
  List<DoctorRecord> _doctors = [];
  bool _loading = false;
  String? _error;
  bool _showAddForm = false;
  String? _nextDoctorId;
  String? _selectedSpecialtyFilter;
  bool _doctorsLoaded = false;

  // Add form state
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  String _selectedSpecialty = 'General Physician';
  String _selectedAvailability = 'Available';
  bool _saving = false;
  String? _formError;
  String? _formSuccess;

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
    // Doctors are loaded on demand — user selects a specialty first
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _feeCtrl.dispose();
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
      final list = await repo.listDoctorRecords(hospital.tenantPublicId, auth.token ?? '');
      if (mounted) {
        setState(() {
          _doctors = list;
          _loading = false;
          _doctorsLoaded = true;
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
      final id = await repo.getNextDoctorId(hospital.tenantPublicId, auth.token ?? '');
      if (mounted) setState(() => _nextDoctorId = id);
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
        _feeCtrl.clear();
        _selectedSpecialty = 'General Physician';
        _selectedAvailability = 'Available';
        _loadNextDoctorId();
      }
    });
  }

  Future<void> _saveDoctor() async {
    final name = _nameCtrl.text.trim();
    final fee = _feeCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Doctor full name is required.');
      return;
    }
    if (fee.isEmpty) {
      setState(() => _formError = 'Fee is required.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
      _formSuccess = null;
    });
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.createDoctorRecord(
        hospital.tenantPublicId,
        auth.token ?? '',
        DoctorUpsertRequest(
          fullName: name,
          specialty: _selectedSpecialty,
          availability: _selectedAvailability,
          fee: fee,
          active: true,
          mobileNumber: _mobileCtrl.text.trim().isNotEmpty ? _mobileCtrl.text.trim() : null,
        ),
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _formSuccess = 'Doctor record created successfully.';
          _showAddForm = false;
        });
        await _loadDoctors();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = extractErrorMessage(e, fallback: 'Failed to create doctor record.');
        });
      }
    }
  }

  Future<void> _deleteDoctor(String doctorId) async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.deleteDoctorRecord(hospital.tenantPublicId, doctorId, auth.token ?? '');
      await _loadDoctors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: SevaCareColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workspace card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doctor workspace', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
              const SizedBox(height: 4),
              Text(
                'Manage the hospital\'s doctor roster.',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PrimaryButton(
                    label: _showAddForm ? 'Cancel' : 'Add Doctor',
                    icon: _showAddForm ? Icons.close : Icons.add,
                    compact: true,
                    onPressed: _toggleAddForm,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _loadDoctors,
                  ),
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
                Text('New Doctor', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                if (_nextDoctorId != null) ...[
                  const SizedBox(height: 4),
                  Text('ID: $_nextDoctorId', style: AppTextStyles.label(SevaCareColors.textMuted)),
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
                  placeholder: '+91 XXXXXXXXXX',
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
                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SevaCareColors.errorSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_formError!, style: AppTextStyles.bodyText(SevaCareColors.danger)),
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
                    child: Text(_formSuccess!, style: AppTextStyles.bodyText(SevaCareColors.mintForeground)),
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
          ),
          const SizedBox(height: 12),
        ],

        // Specialty filter
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter by Specialty', style: AppTextStyles.label(SevaCareColors.textMuted)),
              const SizedBox(height: 8),
              AppDropdown<String?>(
                label: 'Select Specialty',
                value: _selectedSpecialtyFilter,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— All Specialties —')),
                  ..._specialties.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) {
                  setState(() => _selectedSpecialtyFilter = v);
                  if (!_doctorsLoaded) _loadDoctors();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Doctor list
        if (!_doctorsLoaded && !_loading && _doctors.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medical_services_outlined, color: SevaCareColors.textMuted, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Select a specialty above to load doctors.',
                  style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                ),
              ],
            ),
          )
        else if (_loading)
          const ShimmerList(count: 3)
        else if (_error != null)
          AppCard(
            child: Column(
              children: [
                Text('Error loading doctors', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Retry', onPressed: _loadDoctors),
              ],
            ),
          )
        else
          Builder(
            builder: (context) {
              final filteredDoctors = _selectedSpecialtyFilter == null
                  ? _doctors
                  : _doctors.where((d) => d.specialty == _selectedSpecialtyFilter).toList();
              if (filteredDoctors.isEmpty) {
                return AppCard(
                  child: Text(
                    'No doctors found. Add your first doctor above.',
                    style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final doctor in filteredDoctors) ...[
                    AppCard(
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
                                      doctor.doctorPublicId,
                                      style: AppTextStyles.label(SevaCareColors.textMuted),
                                    ),
                                    Text(
                                      doctor.fullName,
                                      style: AppTextStyles.cardTitle(SevaCareColors.text),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: SevaCareColors.primarySoft,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            doctor.specialty,
                                            style: AppTextStyles.label(SevaCareColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          doctor.fee,
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
                                      style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                                    ),
                                    Text(
                                      'Mobile: ${doctor.mobileNumber ?? 'Not set'}',
                                      style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(status: doctor.active ? 'active' : 'inactive'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconBtn(
                                icon: Icons.delete_outline,
                                iconColor: SevaCareColors.danger,
                                bgColor: SevaCareColors.errorSurface,
                                tooltip: 'Delete doctor',
                                onPressed: () => _deleteDoctor(doctor.doctorPublicId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        const SizedBox(height: 16),
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
      final overview = await repo.getAdminOverview(hospital.tenantPublicId, auth.token ?? '');
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
        child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return AppCard(
        child: Column(
          children: [
            Text('Failed to load reports', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Retry', onPressed: _load),
          ],
        ),
      );
    }

    final ov = _overview;
    final totalVisits = ov?.metrics.isNotEmpty == true ? ov!.metrics[0].value : '0';
    final upcoming = ov != null && ov.metrics.length > 1 ? ov.metrics[1].value : '0';
    final completed = ov != null && ov.metrics.length > 2 ? ov.metrics[2].value : '0';

    final filterSegments = [
      SegmentItem<int>(value: 0, label: 'Today'),
      SegmentItem<int>(value: 1, label: 'This Week'),
      SegmentItem<int>(value: 2, label: 'This Month'),
      SegmentItem<int>(value: 3, label: 'This Year'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appointment Reports', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        const SizedBox(height: 12),
        SegmentedControl<int>(
          items: filterSegments,
          selected: _timeFilter,
          onChanged: (v) => setState(() => _timeFilter = v),
        ),
        const SizedBox(height: 16),
        MetricRow(
          tiles: [
            MetricTile(value: totalVisits, label: 'Total Visits', variant: MetricVariant.primary),
            MetricTile(value: upcoming, label: 'Upcoming', variant: MetricVariant.mint),
          ],
        ),
        const SizedBox(height: 8),
        MetricRow(
          tiles: [
            MetricTile(value: completed, label: 'Completed', variant: MetricVariant.peach),
            MetricTile(value: '0', label: 'Cancelled', variant: MetricVariant.danger),
          ],
        ),
        const SizedBox(height: 24),
        Text('Summary', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(label: 'Total Appointments', value: totalVisits),
              InfoRow(label: 'Upcoming / Booked', value: upcoming),
              InfoRow(label: 'Completed', value: completed),
              InfoRow(label: 'Cancelled', value: '0'),
              InfoRow(
                label: 'Period',
                value: ['Today', 'This Week', 'This Month', 'This Year'][_timeFilter],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
