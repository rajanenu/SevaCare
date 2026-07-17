import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Hospital Detail controllers
  final _hospitalNameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pinCtrl = TextEditingController(text: '500001');

  // Contact Detail controllers
  final _contactNameCtrl = TextEditingController();
  final _contactMobileCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();

  // Dropdown state
  String _selectedState = 'Telangana';
  String _selectedCity = 'Hyderabad';
  String _selectedFacilityType = 'hospital';

  bool _submitting = false;
  String? _error;

  // State → Cities map
  static const Map<String, List<String>> _stateCities = {
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad'],
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Tirupati'],
    'Karnataka': ['Bangalore', 'Mysore', 'Mangalore'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur'],
    'Delhi': ['New Delhi'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur'],
    'West Bengal': ['Kolkata'],
    'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode'],
  };

  static const List<String> _states = [
    'Telangana',
    'Andhra Pradesh',
    'Karnataka',
    'Tamil Nadu',
    'Maharashtra',
    'Delhi',
    'Gujarat',
    'Rajasthan',
    'West Bengal',
    'Kerala',
  ];

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    _licenseCtrl.dispose();
    _addressCtrl.dispose();
    _pinCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactMobileCtrl.dispose();
    _contactEmailCtrl.dispose();
    super.dispose();
  }

  List<String> get _citiesForState => _stateCities[_selectedState] ?? [];

  void _onStateChanged(String? state) {
    if (state == null) return;
    final cities = _stateCities[state] ?? [];
    setState(() {
      _selectedState = state;
      _selectedCity = cities.isNotEmpty ? cities.first : '';
    });
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    final hospitalName = _hospitalNameCtrl.text.trim();
    final licenseNumber = _licenseCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final pinCode = _pinCtrl.text.trim();
    final contactName = _contactNameCtrl.text.trim();
    final contactMobile = _contactMobileCtrl.text.trim();
    final contactEmail = _contactEmailCtrl.text.trim();

    if (hospitalName.isEmpty) {
      setState(() => _error = 'Hospital name is required.');
      return;
    }
    if (licenseNumber.isEmpty) {
      setState(() => _error = 'License number is required.');
      return;
    }
    if (address.isEmpty) {
      setState(() => _error = 'Street address is required.');
      return;
    }
    if (pinCode.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit pin code.');
      return;
    }
    if (contactName.isEmpty) {
      setState(() => _error = 'Contact name is required.');
      return;
    }
    if (contactMobile.isEmpty) {
      setState(() => _error = 'Contact mobile is required.');
      return;
    }
    if (contactEmail.isEmpty) {
      setState(() => _error = 'Contact email is required.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(repositoryProvider);
      final result = await repo.requestOnboarding(
        TenantOnboardingRequest(
          hospitalName: hospitalName,
          licenseNumber: licenseNumber,
          address: '$address, $_selectedCity, $_selectedState - $pinCode',
          city: _selectedCity,
          state: _selectedState,
          country: 'India',
          facilityType: _selectedFacilityType,
          contactName: contactName,
          contactMobile: contactMobile,
          contactEmail: contactEmail,
          pinCode: pinCode,
        ),
      );

      if (mounted) {
        setState(() => _submitting = false);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: context.colors.mint, size: 28),
                const SizedBox(width: 10),
                Text('Request Submitted!',
                    style: AppTextStyles.sectionTitle(context.colors.text)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.message.isNotEmpty
                      ? result.message
                      : 'Your onboarding request has been received.',
                  style: AppTextStyles.bodyText(context.colors.textMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.primarySoft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Request ID: ',
                          style: AppTextStyles.label(context.colors.textMuted)),
                      Text(
                        result.requestPublicId,
                        style: AppTextStyles.label(context.colors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              PrimaryButton(
                label: 'Back to Home',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) context.go('/');
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: context.colors.danger, size: 26),
                const SizedBox(width: 10),
                Text('Submission Failed',
                    style: AppTextStyles.sectionTitle(context.colors.text)),
              ],
            ),
            content: Text(
              e.toString(),
              style: AppTextStyles.bodyText(context.colors.textMuted),
            ),
            actions: [
              SecondaryButton(
                label: 'Dismiss',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesForState = _citiesForState;

    return AppShell(
      hospitalName: 'SevaCare',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackBtn(onPressed: () => context.go('/')),
          const SizedBox(height: 16),
          const PageHeader(
            title: 'Onboard Your Hospital',
            subtitle: 'Request to join the SevaCare platform',
          ),
          const SizedBox(height: 16),

          // ── Error banner ───────────────────────────────────────────────────
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.errorSurface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                    color: context.colors.danger.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: context.colors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: AppTextStyles.label(context.colors.danger)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Card 1: Hospital Details ───────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hospital Details',
                    style: AppTextStyles.sectionTitle(context.colors.text)),
                const SizedBox(height: 16),
                AppFormField(
                  label: 'Hospital Name',
                  controller: _hospitalNameCtrl,
                  required: true,
                  placeholder: 'e.g. City General Hospital',
                ),
                AppFormField(
                  label: 'License Number',
                  controller: _licenseCtrl,
                  required: true,
                  placeholder: 'e.g. MH-HOS-2024-0001',
                ),
                AppFormField(
                  label: 'Street Address',
                  controller: _addressCtrl,
                  required: true,
                  placeholder: 'Building, Street, Area',
                  maxLines: 2,
                ),
                AppDropdown<String>(
                  label: 'State',
                  value: _selectedState,
                  required: true,
                  items: _states
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _onStateChanged,
                ),
                if (citiesForState.isNotEmpty)
                  AppDropdown<String>(
                    label: 'City',
                    value: citiesForState.contains(_selectedCity)
                        ? _selectedCity
                        : citiesForState.first,
                    required: true,
                    items: citiesForState
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCity = v);
                    },
                  ),
                AppFormField(
                  label: 'Pin Code',
                  controller: _pinCtrl,
                  required: true,
                  placeholder: '6-digit pin code',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
                AppDropdown<String>(
                  label: 'Facility Type',
                  value: _selectedFacilityType,
                  required: true,
                  items: const [
                    DropdownMenuItem(value: 'hospital', child: Text('Hospital')),
                    DropdownMenuItem(value: 'clinic', child: Text('Clinic')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedFacilityType = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Card 2: Contact Details ────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Details',
                    style: AppTextStyles.sectionTitle(context.colors.text)),
                const SizedBox(height: 16),
                AppFormField(
                  label: 'Contact Name',
                  controller: _contactNameCtrl,
                  required: true,
                  placeholder: 'Full name of contact person',
                ),
                AppFormField(
                  label: 'Contact Mobile',
                  controller: _contactMobileCtrl,
                  required: true,
                  placeholder: '10-digit mobile number',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                AppFormField(
                  label: 'Contact Email',
                  controller: _contactEmailCtrl,
                  required: true,
                  placeholder: 'contact@hospital.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Submit ─────────────────────────────────────────────────────────
          PrimaryButton(
            label: 'Submit Onboarding Request',
            isLoading: _submitting,
            fullWidth: true,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
