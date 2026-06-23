import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class QrAppointmentFormScreen extends ConsumerStatefulWidget {
  final String qrcodeUuid;
  const QrAppointmentFormScreen({super.key, required this.qrcodeUuid});

  @override
  ConsumerState<QrAppointmentFormScreen> createState() =>
      _QrAppointmentFormScreenState();
}

class _QrAppointmentFormScreenState
    extends ConsumerState<QrAppointmentFormScreen> {
  // Form data loaded from backend
  String? _tenantName;
  List<Map<String, dynamic>> _doctors = [];
  bool _loading = true;
  String? _loadError;

  // Form state
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  String? _selectedDoctorPublicId;
  String? _selectedSpecialty;
  DateTime? _preferredDate;
  bool _submitting = false;
  String? _submitError;
  bool _submitted = false;
  String? _requestPublicId;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _symptomsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final repo = ref.read(repositoryProvider);
      final data = await repo.getQrCodeFormData(widget.qrcodeUuid);
      if (mounted) {
        setState(() {
          _tenantName = data['tenantName'] as String? ?? 'Hospital';
          final docs = data['availableDoctors'];
          if (docs is List) {
            _doctors = docs
                .whereType<Map<String, dynamic>>()
                .toList();
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = extractErrorMessage(e, fallback: 'Failed to load form data. Please scan the QR code again.');
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _submitError = 'Patient name is required.');
      return;
    }
    final ageStr = _ageCtrl.text.trim();
    final age = int.tryParse(ageStr) ?? 0;
    if (age <= 0) {
      setState(() => _submitError = 'Please enter a valid age.');
      return;
    }
    if (_symptomsCtrl.text.trim().isEmpty) {
      setState(() => _submitError = 'Please describe your symptoms.');
      return;
    }
    if (_selectedDoctorPublicId == null) {
      setState(() => _submitError = 'Please select a doctor.');
      return;
    }
    if (_preferredDate == null) {
      setState(() => _submitError = 'Please select a preferred date.');
      return;
    }

    setState(() { _submitting = true; _submitError = null; });
    try {
      final repo = ref.read(repositoryProvider);
      // Find specialty for selected doctor
      final doctorInfo = _doctors.firstWhere(
        (d) => d['doctorPublicId'] == _selectedDoctorPublicId,
        orElse: () => {},
      );
      final specialty = doctorInfo['specialty'] as String? ?? _selectedSpecialty ?? '';
      final result = await repo.submitQrAppointmentRequest(
        widget.qrcodeUuid,
        {
          'patientName': _nameCtrl.text.trim(),
          'patientAge': age,
          'symptoms': _symptomsCtrl.text.trim(),
          'doctorPublicId': _selectedDoctorPublicId!,
          'specialty': specialty,
          'preferredDate': DateFormat('yyyy-MM-dd').format(_preferredDate!),
        },
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
          _requestPublicId = result['requestPublicId'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = extractErrorMessage(e, fallback: 'Failed to submit request. Please try again.');
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'Select preferred appointment date',
    );
    if (picked != null && mounted) {
      setState(() => _preferredDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: SevaCareColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: SevaCareColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2, size: 64, color: SevaCareColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Invalid QR Code',
                          style: AppTextStyles.sectionTitle(SevaCareColors.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This QR code link is invalid or has expired. Please scan a fresh QR code from the hospital.',
                          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_submitted) {
      return Scaffold(
        backgroundColor: SevaCareColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: SevaCareColors.mintSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline,
                              size: 48, color: SevaCareColors.mint),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Request Submitted!',
                          style: AppTextStyles.sectionTitle(SevaCareColors.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your appointment request has been submitted to $_tenantName. They will confirm your slot shortly.',
                          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        if (_requestPublicId != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: SevaCareColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Request ID: $_requestPublicId',
                              style: AppTextStyles.label(SevaCareColors.textMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group doctors by specialty for the dropdown
    final specialties = _doctors
        .map((d) => d['specialty'] as String? ?? '')
        .toSet()
        .toList()..sort();

    final filteredDoctors = _selectedSpecialty == null
        ? _doctors
        : _doctors
            .where((d) => d['specialty'] == _selectedSpecialty)
            .toList();

    return Scaffold(
      backgroundColor: SevaCareColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(height: 8),
              // Hospital header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: SevaCareColors.buttonGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(Icons.local_hospital_outlined,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tenantName ?? 'Hospital',
                          style: AppTextStyles.sectionTitle(SevaCareColors.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Book an Appointment',
                          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form card
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient Details',
                        style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                    const SizedBox(height: 16),
                    AppFormField(
                      label: 'Full Name',
                      controller: _nameCtrl,
                      placeholder: 'Enter your full name',
                      required: true,
                    ),
                    AppFormField(
                      label: 'Age',
                      controller: _ageCtrl,
                      placeholder: 'Your age',
                      keyboardType: TextInputType.number,
                      required: true,
                    ),
                    AppFormField(
                      label: 'Symptoms / Reason for Visit',
                      controller: _symptomsCtrl,
                      placeholder: 'Briefly describe your symptoms',
                      required: true,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Doctor selection card
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Doctor',
                        style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                    const SizedBox(height: 12),
                    if (specialties.length > 1)
                      AppDropdown<String?>(
                        label: 'Filter by Specialty',
                        value: _selectedSpecialty,
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('All Specialties')),
                          ...specialties.map((s) =>
                              DropdownMenuItem<String?>(value: s, child: Text(s))),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedSpecialty = v;
                          _selectedDoctorPublicId = null;
                        }),
                      ),
                    const SizedBox(height: 8),
                    if (filteredDoctors.isEmpty)
                      Text('No doctors available.',
                          style: AppTextStyles.bodyText(SevaCareColors.textMuted))
                    else
                      Column(
                        children: filteredDoctors.map((doc) {
                          final id = doc['doctorPublicId'] as String? ?? '';
                          final name = doc['doctorName'] as String? ?? 'Doctor';
                          final spec = doc['specialty'] as String? ?? '';
                          final isSelected = _selectedDoctorPublicId == id;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedDoctorPublicId = id;
                              _selectedSpecialty = spec;
                            }),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? SevaCareColors.primarySoft
                                    : SevaCareColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? SevaCareColors.primary
                                      : SevaCareColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? SevaCareColors.primary
                                          : SevaCareColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'D',
                                        style: AppTextStyles.body(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : SevaCareColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Dr. $name',
                                            style: AppTextStyles.cardTitle(
                                                isSelected
                                                    ? SevaCareColors.primary
                                                    : SevaCareColors.text)),
                                        Text(spec,
                                            style: AppTextStyles.label(
                                                SevaCareColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle,
                                        color: SevaCareColors.primary, size: 20),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date card
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preferred Date',
                        style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: SevaCareColors.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(
                            color: _preferredDate != null
                                ? SevaCareColors.primary
                                : SevaCareColors.border,
                            width: _preferredDate != null ? 2 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: _preferredDate != null
                                  ? SevaCareColors.primary
                                  : SevaCareColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _preferredDate != null
                                  ? DateFormat('d MMMM yyyy')
                                      .format(_preferredDate!)
                                  : 'Tap to select a date',
                              style: AppTextStyles.bodyText(
                                _preferredDate != null
                                    ? SevaCareColors.text
                                    : SevaCareColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Error banner
              if (_submitError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SevaCareColors.errorSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: SevaCareColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_submitError!,
                            style: AppTextStyles.bodyText(SevaCareColors.danger)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Submit button
              PrimaryButton(
                label: 'Request Appointment',
                isLoading: _submitting,
                fullWidth: true,
                onPressed: _submitting ? null : _submit,
              ),
              const SizedBox(height: 8),
              Text(
                'Your request will be reviewed by the hospital. They will confirm the appointment slot.',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
