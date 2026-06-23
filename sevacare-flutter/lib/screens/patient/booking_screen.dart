import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  // Setup / doctor loading
  BookingSetupView? _setup;
  List<DoctorSummary> _doctors = [];
  bool _loadingSetup = true;
  String? _setupError;

  // Booking submission
  bool _booking = false;
  String? _bookingError;

  // Advanced details toggle
  bool _showAdvancedDetails = false;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // Filtered doctors by current specialty
  List<DoctorSummary> get _filteredDoctors {
    final form = ref.read(bookingFormProvider);
    if (form.specialty.isEmpty) return _doctors;
    return _doctors.where((d) => d.specialty == form.specialty).toList();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loadingSetup = true;
      _setupError = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final booking = ref.read(bookingFormProvider);

      final results = await Future.wait([
        repo.getBookingSetup(
          auth.tenantPublicId ?? '',
          auth.subjectPublicId ?? '',
          auth.token ?? '',
        ),
        repo.listPublicDoctors(auth.tenantPublicId ?? ''),
      ]);

      final setup = results[0] as BookingSetupView;
      final doctors = results[1] as List<DoctorSummary>;

      if (mounted) {
        setState(() {
          _setup = setup;
          _doctors = doctors;
        });

        // Seed form defaults — prefer 'General Physician' if available
        final notifier = ref.read(bookingFormProvider.notifier);
        if (setup.specialties.isNotEmpty) {
          final defaultSpec = setup.specialties.contains('General Physician')
              ? 'General Physician'
              : setup.specialties.first;
          if (booking.specialty.isEmpty || booking.specialty == 'General Physician') {
            notifier.updateSpecialty(defaultSpec);
          }
        }
        if (setup.availableDates.isNotEmpty && booking.selectedDate.isEmpty) {
          notifier.updateDate(setup.availableDates.first);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _setupError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSetup = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _bookingError = null);

    final form = ref.read(bookingFormProvider);

    // Validate required booking fields
    if (form.selectedDoctorId.isEmpty) {
      setState(() => _bookingError = 'Please select a doctor');
      return;
    }
    if (form.selectedSlot.isEmpty) {
      setState(() => _bookingError = 'Please select a time slot');
      return;
    }

    // When advanced details shown, validate only if content is partially filled
    if (_showAdvancedDetails) {
      final ageStr = _ageCtrl.text.trim();
      if (ageStr.isNotEmpty) {
        final age = int.tryParse(ageStr);
        if (age == null || age <= 0) {
          setState(() => _bookingError = 'Please enter a valid age');
          return;
        }
      }
    }

    final name = _nameCtrl.text.trim();
    final ageStr = _ageCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final age = int.tryParse(ageStr) ?? 0;

    final auth = ref.read(authProvider);
    final repo = ref.read(repositoryProvider);

    setState(() => _booking = true);
    try {
      await repo.bookAppointment(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
        AppointmentBookingRequest(
          tenantPublicId: auth.tenantPublicId ?? '',
          patientPublicId: auth.subjectPublicId ?? '',
          patientName: name.isNotEmpty ? name : 'Patient',
          gender: form.gender,
          age: age,
          mobileNumber: mobile,
          address: _addressCtrl.text.trim(),
          specialty: form.specialty,
          doctorPublicId: form.selectedDoctorId,
          slot: form.selectedSlot,
        ),
      );

      if (mounted) {
        ref.read(bookingFormProvider.notifier).reset();
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: SevaCareColors.mint, size: 28),
                const SizedBox(width: 10),
                Text('Booked!', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
              ],
            ),
            content: Text(
              'Your appointment has been booked successfully.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            actions: [
              PrimaryButton(
                label: 'Go to Dashboard',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/patient');
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _bookingError = e.toString());
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);
    final form = ref.watch(bookingFormProvider);
    final notifier = ref.read(bookingFormProvider.notifier);
    final filteredDoctors = _filteredDoctors;

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: UserRole.patient,
      body: _loadingSetup
          ? const SizedBox(
              height: 500,
              child: Center(child: CircularProgressIndicator()),
            )
          : _setupError != null
              ? SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: SevaCareColors.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_setupError!,
                            style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                        const SizedBox(height: 16),
                        PrimaryButton(label: 'Retry', onPressed: _loadSetup),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Back + header
                      BackBtn(onPressed: () => context.go('/patient')),
                      const SizedBox(height: 16),
                      const PageHeader(title: 'Appointment Booking'),
                      const SizedBox(height: 16),

                      // ── Error banner
                      if (_bookingError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: SevaCareColors.errorSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            border: Border.all(
                                color: SevaCareColors.danger.withValues(alpha: 0.4),
                                width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: SevaCareColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _bookingError!,
                                  style: AppTextStyles.label(SevaCareColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Patient details card
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Patient Details',
                                style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                            const SizedBox(height: 16),

                            // Specialty dropdown — always visible at top
                            if ((_setup?.specialties ?? []).isNotEmpty)
                              AppDropdown<String>(
                                label: 'Specialty',
                                value: form.specialty.isNotEmpty &&
                                        (_setup!.specialties.contains(form.specialty))
                                    ? form.specialty
                                    : _setup!.specialties.first,
                                required: true,
                                items: (_setup?.specialties ?? [])
                                    .map((s) =>
                                        DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    notifier.updateSpecialty(v);
                                    // Reset doctor if it no longer matches new specialty
                                    final currentDoc = form.selectedDoctorId;
                                    if (currentDoc.isNotEmpty) {
                                      final stillValid = _doctors.any((d) =>
                                          d.doctorPublicId == currentDoc &&
                                          d.specialty == v);
                                      if (!stillValid) notifier.updateDoctorId('');
                                    }
                                    setState(() {});
                                  }
                                },
                              ),

                            // Additional details toggle row
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _showAdvancedDetails = !_showAdvancedDetails),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showAdvancedDetails
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 20,
                                      color: SevaCareColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Additional Details (Optional)',
                                      style: AppTextStyles.label(SevaCareColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Optional fields — shown when expanded
                            if (_showAdvancedDetails) ...[
                              const SizedBox(height: 4),
                              AppFormField(
                                label: 'Patient Name',
                                controller: _nameCtrl,
                                placeholder: 'Full name',
                              ),
                              // Gender + Age on same row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: AppDropdown<String>(
                                      label: 'Gender',
                                      value: form.gender,
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'male', child: Text('Male')),
                                        DropdownMenuItem(
                                            value: 'female', child: Text('Female')),
                                        DropdownMenuItem(
                                            value: 'other', child: Text('Other')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) notifier.updateGender(v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 100,
                                    child: AppFormField(
                                      label: 'Age',
                                      controller: _ageCtrl,
                                      placeholder: 'Years',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              AppFormField(
                                label: 'Mobile Number',
                                controller: _mobileCtrl,
                                placeholder: '10-digit mobile',
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                              ),
                              AppFormField(
                                label: 'Email Address',
                                controller: _emailCtrl,
                                placeholder: 'Optional',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              AppFormField(
                                label: 'Address',
                                controller: _addressCtrl,
                                placeholder: 'Optional',
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Doctor selection
                      Text('Select Doctor',
                          style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                      const SizedBox(height: 12),
                      if (filteredDoctors.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: Text(
                            _doctors.isEmpty
                                ? 'No doctors available'
                                : 'No doctors available for the selected specialty',
                            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredDoctors.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = filteredDoctors[index];
                            final isSelected =
                                form.selectedDoctorId == doc.doctorPublicId;
                            return GestureDetector(
                              onTap: () => notifier.updateDoctorId(doc.doctorPublicId),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: SevaCareColors.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radius),
                                  border: Border.all(
                                    color: isSelected
                                        ? SevaCareColors.primary
                                        : SevaCareColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: SevaCareColors.primary
                                                .withValues(alpha: 0.15),
                                            blurRadius: 12,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    AppAvatar(
                                      initials: doc.name.isNotEmpty
                                          ? doc.name
                                              .trim()
                                              .split(' ')
                                              .where((w) => w.isNotEmpty)
                                              .take(2)
                                              .map((w) => w[0])
                                              .join()
                                          : '?',
                                      size: 44,
                                      hue: AppAvatar.hueFromString(
                                          doc.doctorPublicId),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dr. ${doc.name}',
                                            style: AppTextStyles.cardTitle(
                                                SevaCareColors.text),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            doc.specialty,
                                            style: AppTextStyles.label(
                                                SevaCareColors.textMuted),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: SevaCareColors.mintSoft,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppTheme.radiusPill),
                                                ),
                                                child: Text(
                                                  doc.fee.isNotEmpty
                                                      ? 'Fee: ${doc.fee}'
                                                      : 'Fee N/A',
                                                  style:
                                                      AppTextStyles.chipLabel(
                                                          SevaCareColors
                                                              .mintForeground),
                                                ),
                                              ),
                                              if (doc.availability
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: SevaCareColors
                                                        .primarySoft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            AppTheme.radiusPill),
                                                  ),
                                                  child: Text(
                                                    doc.availability,
                                                    style:
                                                        AppTextStyles.chipLabel(
                                                            SevaCareColors
                                                                .primary),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle,
                                          color: SevaCareColors.primary,
                                          size: 22),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),

                      // ── Date selection
                      Text('Select Date',
                          style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                      const SizedBox(height: 12),
                      if ((_setup?.availableDates ?? []).isNotEmpty)
                        SizedBox(
                          height: 52,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _setup!.availableDates.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final date = _setup!.availableDates[index];
                              final isSelected = form.selectedDate == date;
                              String displayDate;
                              try {
                                displayDate = DateFormat('d MMM')
                                    .format(DateTime.parse(date).toLocal());
                              } catch (_) {
                                displayDate = date;
                              }
                              return GestureDetector(
                                onTap: () {
                                  notifier.updateDate(date);
                                  notifier.updateSlot('');
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors:
                                                SevaCareColors.buttonGradient,
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : SevaCareColors.surface,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill),
                                    border: Border.all(
                                      color: isSelected
                                          ? SevaCareColors.primary
                                          : SevaCareColors.border,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    displayDate,
                                    style: AppTextStyles.chipLabel(
                                      isSelected
                                          ? SevaCareColors.textOnPrimary
                                          : SevaCareColors.text,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),

                      // ── Morning slots
                      if ((_setup?.morningSlots ?? []).isNotEmpty) ...[
                        Text('Morning Slots',
                            style:
                                AppTextStyles.sectionTitle(SevaCareColors.text)),
                        const SizedBox(height: 10),
                        _SlotGrid(
                          slots: _setup!.morningSlots,
                          selectedSlot: form.selectedSlot,
                          onSelect: notifier.updateSlot,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Evening slots
                      if ((_setup?.eveningSlots ?? []).isNotEmpty) ...[
                        Text('Evening Slots',
                            style:
                                AppTextStyles.sectionTitle(SevaCareColors.text)),
                        const SizedBox(height: 10),
                        _SlotGrid(
                          slots: _setup!.eveningSlots,
                          selectedSlot: form.selectedSlot,
                          onSelect: notifier.updateSlot,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Book button
                      PrimaryButton(
                        label: 'Book Appointment',
                        isLoading: _booking,
                        fullWidth: true,
                        onPressed: _booking ? null : _submit,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

// ── Slot chip grid ────────────────────────────────────────────────────────────

class _SlotGrid extends StatelessWidget {
  final List<String> slots;
  final String selectedSlot;
  final ValueChanged<String> onSelect;

  const _SlotGrid({
    required this.slots,
    required this.selectedSlot,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = selectedSlot == slot;
        String label;
        try {
          label = AppDateUtils.formatSlot(slot);
        } catch (_) {
          label = slot;
        }
        return GestureDetector(
          onTap: () => onSelect(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: SevaCareColors.buttonGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: isSelected ? null : SevaCareColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(
                color:
                    isSelected ? SevaCareColors.primary : SevaCareColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: SevaCareColors.primary.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: AppTextStyles.chipLabel(
                isSelected ? SevaCareColors.textOnPrimary : SevaCareColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
