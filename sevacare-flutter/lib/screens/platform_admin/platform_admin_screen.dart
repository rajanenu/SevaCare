import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class PlatformAdminScreen extends ConsumerStatefulWidget {
  const PlatformAdminScreen({super.key});

  @override
  ConsumerState<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends ConsumerState<PlatformAdminScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    final tabs = [
      SegmentItem<int>(value: 0, label: 'Overview'),
      SegmentItem<int>(value: 1, label: 'Hospitals'),
      SegmentItem<int>(value: 2, label: 'Admins'),
    ];

    Widget tabBody;
    switch (_tabIndex) {
      case 1:
        tabBody = _HospitalsTab(token: auth.token ?? '');
        break;
      case 2:
        tabBody = _PlatformAdminsTab(token: auth.token ?? '');
        break;
      default:
        tabBody = _OverviewTab(token: auth.token ?? '');
    }

    return AppShell(
      hospitalName: 'SevaCare Platform',
      role: UserRole.platformAdmin,
      headerActions: [
        TextButton(
          onPressed: () => setState(() => _tabIndex = 0),
          style: TextButton.styleFrom(
            foregroundColor: _tabIndex == 0 ? SevaCareColors.primary : SevaCareColors.textMuted,
          ),
          child: Text(
            'Dashboard',
            style: AppTextStyles.label(
              _tabIndex == 0 ? SevaCareColors.primary : SevaCareColors.textMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/platform-admin/profile'),
          style: TextButton.styleFrom(foregroundColor: SevaCareColors.textMuted),
          child: Text('Profile', style: AppTextStyles.label(SevaCareColors.textMuted)),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Platform Dashboard'),
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

// ── TAB 0: Overview ───────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerStatefulWidget {
  final String token;
  const _OverviewTab({required this.token});

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  PlatformAdminOverview? _overview;
  List<PlatformOnboardingRequestRecord> _requests = [];
  bool _loading = true;
  String? _error;

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
      final repo = ref.read(repositoryProvider);
      final results = await Future.wait([
        repo.getPlatformOverview(widget.token),
        repo.listOnboardingRequests(widget.token),
      ]);
      if (mounted) {
        setState(() {
          _overview = results[0] as PlatformAdminOverview;
          _requests = results[1] as List<PlatformOnboardingRequestRecord>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
          crossAxisAlignment: CrossAxisAlignment.start,
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

    final ov = _overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First metric row
        MetricRow(
          tiles: [
            MetricTile(
              value: '${ov?.activeTenants ?? 0}',
              label: 'Active Tenants',
              variant: MetricVariant.primary,
            ),
            MetricTile(
              value: '${ov?.onboardingRequests ?? 0}',
              label: 'Onboarding Req',
              variant: MetricVariant.peach,
            ),
            MetricTile(
              value: '${ov?.approvedOnboardings ?? 0}',
              label: 'Approved',
              variant: MetricVariant.mint,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Second metric row
        MetricRow(
          tiles: [
            MetricTile(
              value: '${ov?.platformAdmins ?? 0}',
              label: 'Platform Admins',
              variant: MetricVariant.primary,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Onboarding requests
        Text('Onboarding Requests', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        const SizedBox(height: 12),
        if (_requests.isEmpty)
          AppCard(
            child: Text(
              'No onboarding requests yet.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          )
        else
          Column(
            children: [
              for (final req in _requests) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              req.hospitalName,
                              style: AppTextStyles.cardTitle(SevaCareColors.text),
                            ),
                          ),
                          StatusBadge(status: req.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      InfoRow(label: 'City', value: req.city),
                      InfoRow(label: 'Type', value: req.facilityType),
                      InfoRow(label: 'Contact', value: req.contactName),
                      InfoRow(label: 'Mobile', value: req.contactMobile),
                      InfoRow(label: 'Email', value: req.contactEmail),
                      InfoRow(
                        label: 'Requested',
                        value: AppDateUtils.formatDisplay(req.requestedAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── TAB 1: Hospitals ──────────────────────────────────────────────────────────

class _HospitalsTab extends ConsumerStatefulWidget {
  final String token;
  const _HospitalsTab({required this.token});

  @override
  ConsumerState<_HospitalsTab> createState() => _HospitalsTabState();
}

class _HospitalsTabState extends ConsumerState<_HospitalsTab> {
  List<PlatformTenantRecord> _tenants = [];
  bool _loading = false;
  String? _error;
  bool _showAddForm = false;
  final Map<String, String> _qrCodes = {}; // tenantId → qrcodeUuid
  String? _generatingQrFor;

  // Add form state
  final _nameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactMobileCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  String _selectedTheme = 'premium';
  bool _saving = false;
  String? _formError;
  String? _formSuccess;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactMobileCtrl.dispose();
    _contactEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final list = await repo.listPlatformTenants(widget.token);
      if (mounted) {
        setState(() {
          _tenants = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _toggleAddForm() {
    setState(() {
      _showAddForm = !_showAddForm;
      _formError = null;
      _formSuccess = null;
      if (_showAddForm) {
        _nameCtrl.clear();
        _contactNameCtrl.clear();
        _contactMobileCtrl.clear();
        _contactEmailCtrl.clear();
        _selectedTheme = 'premium';
      }
    });
  }

  Future<void> _createTenant() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Hospital name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
      _formSuccess = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      await repo.createPlatformTenant(
        PlatformTenantUpsertRequest(
          hospitalName: name,
          themeKey: _selectedTheme,
          contactName: _contactNameCtrl.text.trim().isNotEmpty ? _contactNameCtrl.text.trim() : null,
          contactMobile:
              _contactMobileCtrl.text.trim().isNotEmpty ? _contactMobileCtrl.text.trim() : null,
          contactEmail:
              _contactEmailCtrl.text.trim().isNotEmpty ? _contactEmailCtrl.text.trim() : null,
        ),
        widget.token,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _formSuccess = 'Hospital created successfully.';
          _showAddForm = false;
        });
        await _loadTenants();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = e.toString();
        });
      }
    }
  }

  Future<void> _deleteTenant(String tenantId, String hospitalName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Hospital', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        content: Text(
          'Are you sure you want to delete "$hospitalName"? This action cannot be undone.',
          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
        ),
        actions: [
          SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
          const SizedBox(width: 8),
          DangerButton(label: 'Delete', onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repo = ref.read(repositoryProvider);
      await repo.deletePlatformTenant(tenantId, widget.token);
      await _loadTenants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: SevaCareColors.danger),
        );
      }
    }
  }

  Future<void> _toggleTenantStatus(PlatformTenantRecord tenant) async {
    final newStatus = tenant.status.toLowerCase() == 'active' ? 'inactive' : 'active';
    try {
      final repo = ref.read(repositoryProvider);
      await repo.updatePlatformTenant(
        tenant.tenantPublicId,
        PlatformTenantUpsertRequest(
          hospitalName: tenant.hospitalName,
          themeKey: tenant.themeKey,
          status: newStatus,
        ),
        widget.token,
      );
      await _loadTenants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: SevaCareColors.danger),
        );
      }
    }
  }

  Future<void> _generateQrCode(PlatformTenantRecord tenant) async {
    setState(() => _generatingQrFor = tenant.tenantPublicId);
    try {
      final repo = ref.read(repositoryProvider);
      final result = await repo.generateQrCode(tenant.tenantPublicId, widget.token);
      final uuid = result['qrcodeUuid'] as String? ?? '';
      final publicId = result['qrcodePublicId'] as String? ?? '';
      if (mounted) {
        setState(() {
          _qrCodes[tenant.tenantPublicId] = uuid;
          _generatingQrFor = null;
        });
        _showQrDialog(tenant.hospitalName, publicId, uuid);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingQrFor = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR generation failed: $e'), backgroundColor: SevaCareColors.danger),
        );
      }
    }
  }

  void _showQrDialog(String hospitalName, String publicId, String uuid) {
    final baseUrl = '${Uri.base.scheme}://${Uri.base.host}'
        '${Uri.base.port != 80 && Uri.base.port != 443 ? ':${Uri.base.port}' : ''}';
    final qrLink = '$baseUrl/#/qrcode/$uuid/appointment-form';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('QR Code — $hospitalName', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QR ID: $publicId', style: AppTextStyles.label(SevaCareColors.textMuted)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SevaCareColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                qrLink,
                style: AppTextStyles.bodyText(SevaCareColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share this link or scan it as a QR code so patients can book appointments.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          ],
        ),
        actions: [
          SecondaryButton(
            label: 'Copy Link',
            icon: Icons.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qrLink));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
          ),
          const SizedBox(width: 8),
          PrimaryButton(label: 'Close', onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action bar
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hospital Management', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
              const SizedBox(height: 4),
              Text(
                'Create and manage hospital tenants on the platform.',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PrimaryButton(
                    label: _showAddForm ? 'Cancel' : 'Add New Hospital',
                    icon: _showAddForm ? Icons.close : Icons.add,
                    onPressed: _toggleAddForm,
                  ),
                  const SizedBox(width: 8),
                  SecondaryButton(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    onPressed: _loading ? null : _loadTenants,
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
                Text('New Hospital', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                const SizedBox(height: 12),
                AppFormField(
                  label: 'Hospital Name',
                  controller: _nameCtrl,
                  required: true,
                  placeholder: 'e.g. City General Hospital',
                ),
                AppDropdown<String>(
                  label: 'Theme',
                  value: _selectedTheme,
                  items: const [
                    DropdownMenuItem(value: 'premium', child: Text('Premium')),
                    DropdownMenuItem(value: 'clinic', child: Text('Clinic')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedTheme = v);
                  },
                ),
                AppFormField(
                  label: 'Contact Name',
                  controller: _contactNameCtrl,
                  placeholder: 'Administrator name',
                ),
                AppFormField(
                  label: 'Contact Mobile',
                  controller: _contactMobileCtrl,
                  placeholder: '+91 XXXXXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                AppFormField(
                  label: 'Contact Email',
                  controller: _contactEmailCtrl,
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
                    child: Text(
                      _formSuccess!,
                      style: AppTextStyles.bodyText(SevaCareColors.mintForeground),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  label: 'Create',
                  isLoading: _saving,
                  onPressed: _saving ? null : _createTenant,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Tenant list
        if (_loading)
          const Center(
            child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
          )
        else if (_error != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Error loading hospitals', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Retry', onPressed: _loadTenants),
              ],
            ),
          )
        else if (_tenants.isEmpty)
          AppCard(
            child: Text(
              'No hospitals found. Add your first hospital above.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          )
        else
          Column(
            children: [
              for (final tenant in _tenants) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tenant.hospitalName,
                                  style: AppTextStyles.cardTitle(SevaCareColors.text),
                                ),
                                Text(
                                  tenant.tenantPublicId,
                                  style: AppTextStyles.label(SevaCareColors.textMuted),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: SevaCareColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    tenant.themeKey.toUpperCase(),
                                    style: AppTextStyles.label(SevaCareColors.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: tenant.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          DangerButton(
                            label: 'Delete',
                            icon: Icons.delete_outline,
                            onPressed: () => _deleteTenant(tenant.tenantPublicId, tenant.hospitalName),
                          ),
                          SecondaryButton(
                            label: tenant.status.toLowerCase() == 'active' ? 'Deactivate' : 'Activate',
                            onPressed: () => _toggleTenantStatus(tenant),
                          ),
                          SecondaryButton(
                            label: _generatingQrFor == tenant.tenantPublicId
                                ? 'Generating...'
                                : _qrCodes.containsKey(tenant.tenantPublicId)
                                    ? 'Show QR'
                                    : 'Generate QR',
                            icon: Icons.qr_code_outlined,
                            onPressed: _generatingQrFor != null
                                ? null
                                : _qrCodes.containsKey(tenant.tenantPublicId)
                                    ? () => _showQrDialog(
                                          tenant.hospitalName,
                                          '',
                                          _qrCodes[tenant.tenantPublicId]!,
                                        )
                                    : () => _generateQrCode(tenant),
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
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── TAB 2: Platform Admins ────────────────────────────────────────────────────

class _PlatformAdminsTab extends ConsumerStatefulWidget {
  final String token;
  const _PlatformAdminsTab({required this.token});

  @override
  ConsumerState<_PlatformAdminsTab> createState() => _PlatformAdminsTabState();
}

class _PlatformAdminsTabState extends ConsumerState<_PlatformAdminsTab> {
  List<PlatformAdminUserRecord> _admins = [];
  bool _loading = false;
  String? _error;
  bool _showAddForm = false;

  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _formError;
  String? _formSuccess;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
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
      final repo = ref.read(repositoryProvider);
      final list = await repo.listPlatformAdminUsers(widget.token);
      if (mounted) {
        setState(() {
          _admins = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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
      final repo = ref.read(repositoryProvider);
      await repo.createPlatformAdminUser(
        PlatformAdminUserUpsertRequest(
          fullName: name,
          mobileNumber: mobile,
          email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        ),
        widget.token,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _formSuccess = 'Platform admin created successfully.';
          _showAddForm = false;
        });
        await _loadAdmins();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = e.toString();
        });
      }
    }
  }

  Future<void> _deleteAdmin(String adminId) async {
    try {
      final repo = ref.read(repositoryProvider);
      await repo.deletePlatformAdminUser(adminId, widget.token);
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
      final repo = ref.read(repositoryProvider);
      await repo.deactivatePlatformAdminUser(adminId, widget.token);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action bar
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Admin Users', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
              const SizedBox(height: 4),
              Text(
                'Manage platform-level administrator accounts.',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PrimaryButton(
                    label: _showAddForm ? 'Cancel' : 'Add New Admin',
                    icon: _showAddForm ? Icons.close : Icons.add,
                    onPressed: _toggleAddForm,
                  ),
                  const SizedBox(width: 8),
                  SecondaryButton(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    onPressed: _loading ? null : _loadAdmins,
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
                Text('New Platform Admin', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
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
                  placeholder: 'admin@sevacare.in',
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
                    child: Text(
                      _formSuccess!,
                      style: AppTextStyles.bodyText(SevaCareColors.mintForeground),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  label: 'Create',
                  isLoading: _saving,
                  onPressed: _saving ? null : _createAdmin,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Admin list
        if (_loading)
          const Center(
            child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
          )
        else if (_error != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
              'No platform admins found.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
          )
        else
          Column(
            children: [
              for (final admin in _admins) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            initials: _initials(admin.fullName),
                            hue: AppAvatar.hueFromString(admin.platformAdminPublicId),
                            size: 44,
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
                                  admin.mobileNumber,
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
                          DangerButton(
                            label: 'Delete',
                            icon: Icons.delete_outline,
                            onPressed: () => _deleteAdmin(admin.platformAdminPublicId),
                          ),
                          const SizedBox(width: 8),
                          if (admin.active)
                            SecondaryButton(
                              label: 'Deactivate',
                              onPressed: () => _deactivateAdmin(admin.platformAdminPublicId),
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

        const SizedBox(height: 16),
      ],
    );
  }
}
