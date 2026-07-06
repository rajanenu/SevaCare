import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/config/app_config.dart';
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

    // Fixed-frame layout: the page header and tab bar are pinned; each tab
    // owns its scroll area below, so switching tabs never moves the frame.
    return AppShell(
      hospitalName: 'SevaCare Platform',
      role: UserRole.platformAdmin,
      scrollable: false,
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
          onPressed: () => context.push('/platform-admin/profile'),
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
          // All tabs stay mounted (IndexedStack) so switching is instant —
          // no refetch, no shimmer flash — and each tab keeps its own scroll
          // position inside the fixed frame.
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              sizing: StackFit.expand,
              children: [
                _tabPage(_OverviewTab(token: auth.token ?? '')),
                _tabPage(_HospitalsTab(token: auth.token ?? '')),
                _tabPage(_PlatformAdminsTab(token: auth.token ?? '')),
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
      return const ShimmerList(count: 4, cardHeight: 80);
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
          ],
        ),
        const SizedBox(height: 8),

        // Second metric row
        MetricRow(
          tiles: [
            MetricTile(
              value: '${ov?.approvedOnboardings ?? 0}',
              label: 'Approved',
              variant: MetricVariant.mint,
            ),
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

  int _visibleCount = 2;
  final Set<String> _expandedTenants = {};

  // Add form state
  final _nameCtrl = TextEditingController();
  final _pinCodeCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactMobileCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  String _selectedTheme = 'premium';
  String _selectedCity = '';
  bool _saving = false;
  String? _formError;
  String? _formSuccess;

  static const _cityOptions = [
    'Bangalore', 'Chennai', 'Hyderabad', 'Visakhapatnam', 'Proddatur', 'Kadapa',
  ];

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCodeCtrl.dispose();
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
        _pinCodeCtrl.clear();
        _contactNameCtrl.clear();
        _contactMobileCtrl.clear();
        _contactEmailCtrl.clear();
        _selectedTheme = 'premium';
        _selectedCity = '';
      }
    });
  }

  Future<void> _createTenant() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Hospital name is required.');
      return;
    }
    final contactMobile = _contactMobileCtrl.text.trim();
    if (contactMobile.isEmpty) {
      setState(() => _formError = 'Contact mobile is required — it becomes the hospital admin login.');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Create Hospital',
      message: 'Create a new hospital tenant "$name"?',
      confirmLabel: 'Create',
      isDanger: false,
    );
    if (!confirmed) return;
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
          city: _selectedCity.isNotEmpty ? _selectedCity : null,
          pinCode: _pinCodeCtrl.text.trim().isNotEmpty ? _pinCodeCtrl.text.trim() : null,
          themeKey: _selectedTheme,
          contactName: _contactNameCtrl.text.trim().isNotEmpty ? _contactNameCtrl.text.trim() : null,
          contactMobile: contactMobile,
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

  /// Picks a hospital image from the gallery and uploads it as the tenant's
  /// hero image — shown as the glass background on the hospital's login page.
  Future<void> _uploadHeroImage(PlatformTenantRecord tenant) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final repo = ref.read(repositoryProvider);
      await repo.uploadPlatformTenantHeroImage(
        tenant.tenantPublicId,
        widget.token,
        base64Encode(bytes),
        contentType: picked.mimeType ?? 'image/jpeg',
      );
      // Drop the cached login background so the new image shows immediately
      ref.invalidate(tenantHeroImageProvider(tenant.tenantPublicId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hospital image updated for ${tenant.hospitalName}. '
              'It now appears on the login screen background.'),
          backgroundColor: SevaCareColors.mintForeground,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Image upload failed: $e'),
          backgroundColor: SevaCareColors.danger,
        ));
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
    // The QR must encode a URL any patient's phone camera can open — the
    // backend serves a self-contained booking page at this path. AppConfig
    // .apiBaseUrl already resolves to a reachable host (the Mac's LAN IP baked
    // into the APK, or the serving host on web), unlike Uri.base which is
    // file://:0 inside the mobile app and produces an unscannable link.
    final qrLink = '${AppConfig.apiBaseUrl}/public/qrcode/$uuid/book';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('QR Code — $hospitalName', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('QR ID: $publicId', style: AppTextStyles.label(SevaCareColors.textMuted)),
            const SizedBox(height: 16),
            // Actual QR code image — rendered after frame to avoid freezing the UI
            Center(child: _QrDialogContent(qrLink: qrLink)),
            const SizedBox(height: 16),
            // Copyable link
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SevaCareColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                qrLink,
                style: AppTextStyles.bodyText(SevaCareColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Patients can scan this QR code or visit the link to book an appointment.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
              textAlign: TextAlign.center,
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
                    label: _showAddForm ? 'Cancel' : 'Add Hospital',
                    icon: _showAddForm ? Icons.close : Icons.add,
                    compact: true,
                    onPressed: _toggleAddForm,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
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
                  label: 'City',
                  value: _selectedCity,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Select city…')),
                    ..._cityOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => _selectedCity = v ?? ''),
                ),
                AppFormField(
                  label: 'Pin Code',
                  controller: _pinCodeCtrl,
                  placeholder: 'e.g. 516360',
                  keyboardType: TextInputType.number,
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
                  required: true,
                  placeholder: '+91 XXXXXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'This number becomes the hospital admin login. They can add more admins after signing in.',
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
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
          const ShimmerList(count: 3)
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
              for (final (i, tenant) in _tenants.take(_visibleCount).indexed) ...[
                StaggeredItem(
                  index: i,
                  child: _HospitalCard(
                    tenant: tenant,
                    isExpanded: _expandedTenants.contains(tenant.tenantPublicId),
                    isGeneratingQr: _generatingQrFor == tenant.tenantPublicId,
                    qrGenerated: _qrCodes.containsKey(tenant.tenantPublicId),
                    onTap: () => setState(() {
                      if (_expandedTenants.contains(tenant.tenantPublicId)) {
                        _expandedTenants.remove(tenant.tenantPublicId);
                      } else {
                        _expandedTenants.add(tenant.tenantPublicId);
                      }
                    }),
                    onDelete: () => _deleteTenant(tenant.tenantPublicId, tenant.hospitalName),
                    onToggleStatus: () => _toggleTenantStatus(tenant),
                    onUploadImage: () => _uploadHeroImage(tenant),
                    onGenerateQr: _generatingQrFor != null ? null : () => _generateQrCode(tenant),
                    onShowQr: _qrCodes.containsKey(tenant.tenantPublicId)
                        ? () => _showQrDialog(tenant.hospitalName, '', _qrCodes[tenant.tenantPublicId]!)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_visibleCount < _tenants.length)
                GestureDetector(
                  onTap: () => setState(() => _visibleCount += 2),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: SevaCareColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SevaCareColors.border, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.expand_more, size: 16, color: SevaCareColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Load More (${_tenants.length - _visibleCount} remaining)',
                          style: AppTextStyles.label(SevaCareColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Hospital Card ─────────────────────────────────────────────────────────────

class _HospitalCard extends StatelessWidget {
  final PlatformTenantRecord tenant;
  final bool isExpanded;
  final bool isGeneratingQr;
  final bool qrGenerated;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onGenerateQr;
  final VoidCallback? onShowQr;
  final VoidCallback? onUploadImage;

  const _HospitalCard({
    required this.tenant,
    required this.isExpanded,
    required this.isGeneratingQr,
    required this.qrGenerated,
    this.onTap,
    this.onDelete,
    this.onToggleStatus,
    this.onGenerateQr,
    this.onShowQr,
    this.onUploadImage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Column(
          children: [
            // ── Collapsed header row ──────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SevaCareColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      tenant.hospitalName.isNotEmpty
                          ? tenant.hospitalName[0].toUpperCase()
                          : 'H',
                      style: AppTextStyles.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: SevaCareColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.hospitalName,
                        style: AppTextStyles.cardTitle(SevaCareColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tenant.city.isNotEmpty)
                        Text(
                          '${tenant.city}${tenant.pinCode.isNotEmpty ? ' · ${tenant.pinCode}' : ''}',
                          style: AppTextStyles.label(SevaCareColors.primary),
                        ),
                      Text(
                        tenant.tenantPublicId,
                        style: AppTextStyles.label(SevaCareColors.textMuted),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: tenant.status),
                const SizedBox(width: 6),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: SevaCareColors.textMuted,
                ),
              ],
            ),
            // ── Expanded actions ──────────────────────────────────────────
            if (isExpanded) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconBtn(
                    icon: Icons.delete_outline,
                    iconColor: SevaCareColors.danger,
                    bgColor: SevaCareColors.errorSurface,
                    tooltip: 'Delete hospital',
                    onPressed: onDelete,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: tenant.status.toLowerCase() == 'active'
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    iconColor: tenant.status.toLowerCase() == 'active'
                        ? SevaCareColors.peachForeground
                        : SevaCareColors.mintForeground,
                    bgColor: tenant.status.toLowerCase() == 'active'
                        ? SevaCareColors.peachSoft
                        : SevaCareColors.mintSoft,
                    tooltip: tenant.status.toLowerCase() == 'active'
                        ? 'Deactivate'
                        : 'Activate',
                    onPressed: onToggleStatus,
                  ),
                  const SizedBox(width: 8),
                  if (isGeneratingQr)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    IconBtn(
                      icon: Icons.qr_code_outlined,
                      iconColor: SevaCareColors.primary,
                      bgColor: SevaCareColors.primarySoft,
                      tooltip: qrGenerated ? 'Show QR Code' : 'Generate QR Code',
                      onPressed: qrGenerated ? onShowQr : onGenerateQr,
                    ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.image_outlined,
                    iconColor: SevaCareColors.mintForeground,
                    bgColor: SevaCareColors.mintSoft,
                    tooltip: 'Upload hospital image (login background)',
                    onPressed: onUploadImage,
                  ),
                  const Spacer(),
                  Text(
                    tenant.themeKey.toUpperCase(),
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Add Admin User',
      message: 'Add "$name" as a platform admin?',
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

  Future<void> _deleteAdmin(String adminId, String adminName) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Admin User',
      message: 'Remove "$adminName" from platform admins? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
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
                    label: _showAddForm ? 'Cancel' : 'Add Admin',
                    icon: _showAddForm ? Icons.close : Icons.add,
                    compact: true,
                    onPressed: _toggleAddForm,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
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
          const ShimmerList(count: 3)
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconBtn(
                            icon: Icons.delete_outline,
                            iconColor: SevaCareColors.danger,
                            bgColor: SevaCareColors.errorSurface,
                            tooltip: 'Delete admin',
                            onPressed: () => _deleteAdmin(admin.platformAdminPublicId, admin.fullName),
                          ),
                          const SizedBox(width: 8),
                          if (admin.active)
                            IconBtn(
                              icon: Icons.pause_circle_outline,
                              iconColor: SevaCareColors.peachForeground,
                              bgColor: SevaCareColors.peachSoft,
                              tooltip: 'Deactivate',
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

// ── Deferred QR renderer — avoids freezing the UI on web ─────────────────────

class _QrDialogContent extends StatefulWidget {
  final String qrLink;
  const _QrDialogContent({required this.qrLink});
  @override
  State<_QrDialogContent> createState() => _QrDialogContentState();
}

class _QrDialogContentState extends State<_QrDialogContent> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      height: 224,
      padding: _ready ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SevaCareColors.border, width: 1),
      ),
      child: _ready
          ? RepaintBoundary(
              child: QrImageView(
                data: widget.qrLink,
                version: QrVersions.auto,
                size: 200,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
