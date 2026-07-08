import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/ai/symptom_specialty_engine.dart';
import '../../core/i18n/i18n.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/doctor_name.dart';
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

  // Booked/blocked slots for current doctor+date
  List<String> _bookedSlots = [];
  List<String> _blockedSlots = [];
  bool _doctorOnLeave = false;

  // This doctor's own working-hours slots for the selected date — null falls
  // back to the tenant-wide _setup slots (e.g. while loading, or on error).
  List<String>? _doctorMorningSlots;
  List<String>? _doctorEveningSlots;
  List<String> get _morningSlots => _doctorMorningSlots ?? _setup?.morningSlots ?? [];
  List<String> get _eveningSlots => _doctorEveningSlots ?? _setup?.eveningSlots ?? [];

  // Dates (yyyy-MM-dd) the selected doctor has no working hours on — used to
  // gray out chips in the date strip and to explain empty slot lists.
  Set<String> _unavailableDates = {};

  // Token booking preview
  int? _tokenPreviewNumber;
  bool _loadingTokenPreview = false;

  // Which slot-time accordion section is open: 'MORNING' or 'EVENING'
  String _expandedSlotSession = 'MORNING';

  // Symptoms + AI specialty suggestion
  final _symptomsCtrl = TextEditingController();
  List<SpecialtySuggestion> _suggestions = [];
  Timer? _suggestionsHideTimer;

  // Booking submission
  bool _booking = false;
  String? _bookingError;

  // Advanced details toggle
  bool _showAdvancedDetails = false;

  // Prescription attachments
  List<PickedPrescriptionFile> _attachments = [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loginMobile = ref.read(loginMobileProvider);
      if (loginMobile.isNotEmpty && _mobileCtrl.text.isEmpty) {
        _mobileCtrl.text = loginMobile;
      }
    });
  }

  @override
  void dispose() {
    _suggestionsHideTimer?.cancel();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _symptomsCtrl.dispose();
    super.dispose();
  }

  void _onSymptomsChanged(String text) {
    final suggestions = SymptomSpecialtyEngine.suggest(
      text,
      _setup?.specialties ?? const [],
    );
    setState(() => _suggestions = suggestions);

    _suggestionsHideTimer?.cancel();
    if (suggestions.isNotEmpty) {
      _suggestionsHideTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => _suggestions = []);
      });
    }
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
        if (booking.selectedDoctorId.isNotEmpty) {
          _loadUnavailableDates(booking.selectedDoctorId);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _setupError = extractErrorMessage(e, fallback: 'Failed to load booking setup. Please try again.'));
    } finally {
      if (mounted) setState(() => _loadingSetup = false);
    }
  }

  /// Fetches which strip dates the doctor is off on — one batched call.
  /// Best-effort: on failure the strip simply shows all dates as normal.
  Future<void> _loadUnavailableDates(String doctorId) async {
    final dates = _setup?.availableDates ?? const [];
    if (doctorId.isEmpty || dates.isEmpty) {
      setState(() => _unavailableDates = {});
      return;
    }
    try {
      final auth = ref.read(authProvider);
      final unavailable = await ref.read(repositoryProvider).getDoctorUnavailableDates(
            auth.tenantPublicId ?? '',
            doctorId,
            dates.first,
            dates.length,
            auth.token ?? '',
          );
      if (mounted) setState(() => _unavailableDates = unavailable);
    } catch (_) {
      if (mounted) setState(() => _unavailableDates = {});
    }
  }

  Future<void> _loadBookedSlots(String doctorId, String date) async {
    if (doctorId.isEmpty || date.isEmpty) {
      setState(() {
        _bookedSlots = [];
        _blockedSlots = [];
        _doctorOnLeave = false;
        _doctorMorningSlots = null;
        _doctorEveningSlots = null;
      });
      return;
    }
    final auth = ref.read(authProvider);
    final repo = ref.read(repositoryProvider);
    try {
      final status = await repo.getSlotStatus(
        auth.tenantPublicId ?? '',
        doctorId,
        date,
        auth.token ?? '',
      );
      if (mounted) {
        setState(() {
          _bookedSlots = status.bookedSlots;
          _blockedSlots = status.blockedSlots;
          _doctorOnLeave = status.doctorOnLeave;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bookedSlots = [];
          _blockedSlots = [];
          _doctorOnLeave = false;
        });
      }
    }
    try {
      final slots = await repo.getDoctorSlots(
        auth.tenantPublicId ?? '',
        doctorId,
        date,
        auth.token ?? '',
      );
      if (mounted) {
        setState(() {
          _doctorMorningSlots = List<String>.from(slots['morningSlots'] as List? ?? const []);
          _doctorEveningSlots = List<String>.from(slots['eveningSlots'] as List? ?? const []);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _doctorMorningSlots = null;
          _doctorEveningSlots = null;
        });
      }
    }
  }

  Future<void> _loadTokenPreview(String doctorId, String date, String session) async {
    if (doctorId.isEmpty || date.isEmpty) return;
    setState(() {
      _loadingTokenPreview = true;
      _tokenPreviewNumber = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final preview = await repo.getTokenPreview(
        auth.tenantPublicId ?? '',
        doctorId,
        date,
        session,
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

  Future<void> _submit() async {
    setState(() => _bookingError = null);

    final form = ref.read(bookingFormProvider);

    // Validate patient name
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _bookingError = 'Please enter patient name');
      return;
    }

    // Validate mobile number
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isEmpty || mobile.length < 10) {
      setState(() => _bookingError = 'Please enter a valid 10-digit mobile number');
      return;
    }

    // Validate required booking fields
    if (form.selectedDoctorId.isEmpty) {
      setState(() => _bookingError = 'Please select a doctor');
      return;
    }

    // Validate date selection
    if (form.selectedDate.isEmpty) {
      setState(() => _bookingError = 'Please select an appointment date');
      return;
    }

    final isToken = form.bookingType == 'TOKEN';
    if (isToken) {
      if (form.tokenSession == null || form.tokenSession!.isEmpty) {
        setState(() => _bookingError = 'Please select Morning or Evening token');
        return;
      }
    } else if (form.selectedSlot.isEmpty) {
      setState(() => _bookingError = 'Please select a time slot');
      return;
    }

    // Validate age if provided (field is always visible now)
    final ageStr = _ageCtrl.text.trim();
    if (ageStr.isNotEmpty) {
      final age = int.tryParse(ageStr);
      if (age == null || age <= 0) {
        setState(() => _bookingError = 'Please enter a valid age');
        return;
      }
    }

    final age = int.tryParse(ageStr) ?? 0;

    // Combine date + time slot into the format the backend expects: "yyyy-MM-dd HH:mm"
    // Token bookings just send the plain date — the backend assigns the session start time.
    final combinedSlot = isToken ? form.selectedDate : '${form.selectedDate} ${form.selectedSlot}';

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
          patientName: name,
          gender: form.gender,
          age: age,
          mobileNumber: mobile,
          address: _addressCtrl.text.trim().isEmpty ? '' : _addressCtrl.text.trim(),
          specialty: form.specialty,
          doctorPublicId: form.selectedDoctorId,
          slot: combinedSlot,
          bookingType: form.bookingType,
          tokenSession: isToken ? form.tokenSession : null,
          note: _symptomsCtrl.text.trim().isEmpty
              ? null
              : 'Symptoms: ${_symptomsCtrl.text.trim()}',
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
        // Resolve doctor name from current selection
        final bookedDoc = _doctors.where(
          (d) => d.doctorPublicId == form.selectedDoctorId,
        ).firstOrNull;
        final doctorName = bookedDoc?.name ?? '';

        // Format slot for display: "2 Jul · 10:30 AM" (or "Token #14 · Morning · 2 Jul" for tokens)
        String displaySlot = combinedSlot;
        if (isToken) {
          final sessionLabel = form.tokenSession == 'EVENING' ? 'Evening' : 'Morning';
          try {
            final dt = DateTime.parse(form.selectedDate).toLocal();
            final months = ['Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'];
            displaySlot = 'Token #${_tokenPreviewNumber ?? '-'} · $sessionLabel · ${dt.day} ${months[dt.month - 1]}';
          } catch (_) {
            displaySlot = 'Token #${_tokenPreviewNumber ?? '-'} · $sessionLabel';
          }
        } else {
          try {
            final dt = DateTime.parse(combinedSlot.replaceFirst(' ', 'T')).toLocal();
            final months = ['Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'];
            final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final min = dt.minute.toString().padLeft(2, '0');
            final ampm = dt.hour < 12 ? 'AM' : 'PM';
            displaySlot = '${dt.day} ${months[dt.month - 1]} · $hour:$min $ampm';
          } catch (_) {}
        }

        ref.read(bookingFormProvider.notifier).reset();

        await showBookingSuccessOverlay(
          context,
          doctorName: doctorName,
          displaySlot: displaySlot,
        );

        if (mounted) context.go('/patient');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Booking failed. Please try again.';
        if (e is DioException && e.error is ApiException) {
          msg = (e.error as ApiException).message;
        }
        setState(() => _bookingError = msg);
      }
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
          ? const ShimmerList(count: 4, cardHeight: 100)
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
                        PrimaryButton(label: tr(ref, 'Retry'), onPressed: _loadSetup),
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
                      PageHeader(title: tr(ref, 'Appointment Booking')),
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
                            Text(tr(ref, 'Patient Details'),
                                style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                            const SizedBox(height: 16),

                            // Specialty dropdown — always visible at top
                            if ((_setup?.specialties ?? []).isNotEmpty)
                              AppDropdown<String>(
                                label: tr(ref, 'Specialty'),
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

                            const SizedBox(height: 12),
                            // Always visible fields
                            AppFormField(
                              label: tr(ref, 'Patient Name'),
                              controller: _nameCtrl,
                              placeholder: 'Full name',
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AppDropdown<String>(
                                    label: tr(ref, 'Gender'),
                                    value: form.gender,
                                    items: [
                                      DropdownMenuItem(value: 'male', child: Text(tr(ref, 'Male'))),
                                      DropdownMenuItem(value: 'female', child: Text(tr(ref, 'Female'))),
                                      DropdownMenuItem(value: 'other', child: Text(tr(ref, 'Other'))),
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
                                    label: tr(ref, 'Age'),
                                    controller: _ageCtrl,
                                    placeholder: 'Years',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ),
                              ],
                            ),
                            AppFormField(
                              label: tr(ref, 'Mobile Number'),
                              controller: _mobileCtrl,
                              placeholder: '10-digit mobile',
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            AppFormField(
                              label: tr(ref, 'Symptoms'),
                              controller: _symptomsCtrl,
                              placeholder: 'e.g. tooth pain, fever since 2 days…',
                              maxLines: 2,
                              onChanged: _onSymptomsChanged,
                            ),
                            if (_suggestions.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: SevaCareColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: SevaCareColors.primary
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.auto_awesome,
                                            size: 14,
                                            color: SevaCareColors.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          tr(ref, 'Suggested specialty'),
                                          style: AppTextStyles.label(
                                              SevaCareColors.primary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: _suggestions.map((s) {
                                        final applied =
                                            form.specialty == s.specialty;
                                        return GestureDetector(
                                          onTap: () {
                                            notifier
                                                .updateSpecialty(s.specialty);
                                            final currentDoc =
                                                form.selectedDoctorId;
                                            if (currentDoc.isNotEmpty) {
                                              final stillValid = _doctors.any(
                                                  (d) =>
                                                      d.doctorPublicId ==
                                                          currentDoc &&
                                                      d.specialty ==
                                                          s.specialty);
                                              if (!stillValid) {
                                                notifier.updateDoctorId('');
                                              }
                                            }
                                            setState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: applied
                                                  ? SevaCareColors.primary
                                                  : SevaCareColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppTheme.radiusPill),
                                              border: Border.all(
                                                color:
                                                    SevaCareColors.primary,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  applied
                                                      ? Icons.check
                                                      : Icons
                                                          .arrow_forward_rounded,
                                                  size: 12,
                                                  color: applied
                                                      ? Colors.white
                                                      : SevaCareColors
                                                          .primary,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  s.specialty,
                                                  style: AppTextStyles
                                                      .chipLabel(
                                                    applied
                                                        ? Colors.white
                                                        : SevaCareColors
                                                            .primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Based on "${_suggestions.first.matchedSymptom}". You can still choose any specialty.',
                                      style: AppTextStyles.label(
                                          SevaCareColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            PrescriptionAttachmentPicker(
                              onChanged: (files) => setState(() => _attachments = files),
                            ),
                            // Optional details toggle
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => setState(() => _showAdvancedDetails = !_showAdvancedDetails),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showAdvancedDetails ? Icons.expand_less : Icons.expand_more,
                                      size: 18,
                                      color: SevaCareColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      tr(ref, 'Optional Contact Info'),
                                      style: AppTextStyles.label(SevaCareColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showAdvancedDetails) ...[
                              AppFormField(
                                label: tr(ref, 'Email Address'),
                                controller: _emailCtrl,
                                placeholder: 'Optional',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              AppFormField(
                                label: tr(ref, 'Address'),
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
                      Text(tr(ref, 'Select Doctor'),
                          style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                      const SizedBox(height: 12),
                      if (filteredDoctors.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: Text(
                            _doctors.isEmpty
                                ? tr(ref, 'No doctors available')
                                : tr(ref, 'No doctors available for the selected specialty'),
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
                            return StaggeredItem(
                              index: index,
                              child: GestureDetector(
                              onTap: () {
                                notifier.updateDoctorId(doc.doctorPublicId);
                                notifier.updateSlot('');
                                notifier.updateBookingType(
                                    doc.bookingMode == 'TOKEN' ? 'TOKEN' : 'SLOT');
                                setState(() => _tokenPreviewNumber = null);
                                final currentDate = ref.read(bookingFormProvider).selectedDate;
                                _loadBookedSlots(doc.doctorPublicId, currentDate);
                                _loadUnavailableDates(doc.doctorPublicId);
                              },
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
                                    DoctorPhoto.circle(
                                      doctorId: doc.doctorPublicId,
                                      size: 44,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dr. ${stripDoctorPrefix(doc.name)}',
                                            style: AppTextStyles.cardTitle(
                                                SevaCareColors.text),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            doc.specialty,
                                            style: AppTextStyles.label(
                                                SevaCareColors.textMuted),
                                          ),
                                          if (doc.qualification != null &&
                                              doc.qualification!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              doc.qualification!,
                                              style: AppTextStyles.label(
                                                  SevaCareColors.textMuted),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (doc.averageRating != null) ...[
                                            const SizedBox(height: 2),
                                            RatingStars(
                                                averageRating: doc.averageRating,
                                                reviewCount: doc.reviewCount),
                                          ],
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (doc.experienceYears != null) ...[
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
                                                    '${doc.experienceYears}y Exp',
                                                    style:
                                                        AppTextStyles.chipLabel(
                                                            SevaCareColors
                                                                .primary),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
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
                            ),
                          );
                          },
                        ),
                      const SizedBox(height: 24),

                      // ── Date + slots (only after doctor selected)
                      if (form.selectedDoctorId.isNotEmpty) ...[
                        if ((_doctors
                                    .where((d) => d.doctorPublicId == form.selectedDoctorId)
                                    .firstOrNull
                                    ?.bookingMode ??
                                'BOTH') ==
                            'BOTH') ...[
                          SegmentedControl<String>(
                            selected: form.bookingType,
                            items: [
                              SegmentItem(value: 'SLOT', label: tr(ref, 'Slot Booking'), icon: Icons.schedule),
                              SegmentItem(value: 'TOKEN', label: tr(ref, 'Token Booking'), icon: Icons.confirmation_number_outlined),
                            ],
                            onChanged: (v) {
                              notifier.updateBookingType(v);
                              setState(() => _tokenPreviewNumber = null);
                              if (v == 'TOKEN' && form.tokenSession != null && form.selectedDate.isNotEmpty) {
                                _loadTokenPreview(form.selectedDoctorId, form.selectedDate, form.tokenSession!);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(tr(ref, 'Select Date'),
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
                                final isDoctorOff =
                                    _unavailableDates.contains(date);
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
                                    _loadBookedSlots(form.selectedDoctorId, date);
                                    if (form.bookingType == 'TOKEN' && form.tokenSession != null) {
                                      _loadTokenPreview(form.selectedDoctorId, date, form.tokenSession!);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: isDoctorOff ? 5 : 12),
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
                                          : isDoctorOff
                                              ? SevaCareColors.surfaceMuted
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
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          displayDate,
                                          style: AppTextStyles.chipLabel(
                                            isSelected
                                                ? SevaCareColors.textOnPrimary
                                                : isDoctorOff
                                                    ? SevaCareColors.textMuted
                                                    : SevaCareColors.text,
                                          ).copyWith(
                                            decoration: isDoctorOff && !isSelected
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (isDoctorOff)
                                          Text(
                                            tr(ref, 'Off'),
                                            style: AppTextStyles.label(
                                              isSelected
                                                  ? SevaCareColors.textOnPrimary
                                                  : SevaCareColors.textMuted,
                                            ).copyWith(fontSize: 10, height: 1.1),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),

                        // ── Doctor-on-leave banner
                        if (_doctorOnLeave && form.selectedDate.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SevaCareColors.errorSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_busy,
                                    size: 16, color: SevaCareColors.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tr(ref, 'Doctor is on leave on this date. Please pick another date or doctor.'),
                                    style: AppTextStyles.label(
                                        SevaCareColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Doctor-not-available banner (no working hours on
                        // this date under their schedule) — distinct from the
                        // on-leave banner above.
                        if (!_doctorOnLeave &&
                            form.selectedDoctorId.isNotEmpty &&
                            form.selectedDate.isNotEmpty &&
                            _unavailableDates.contains(form.selectedDate)) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SevaCareColors.warningSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_busy,
                                    size: 16, color: SevaCareColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tr(ref, 'Doctor is not available on this date. Please pick another date or doctor.'),
                                    style: AppTextStyles.label(
                                        SevaCareColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else if (!_doctorOnLeave && form.selectedDoctorId.isNotEmpty && form.selectedDate.isNotEmpty) ...[
                          if (form.bookingType == 'TOKEN') ...[
                            Text(tr(ref, 'Token Booking'),
                                style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                            const SizedBox(height: 10),
                            TokenSessionPicker(
                              selectedSession: form.tokenSession,
                              loadingPreview: _loadingTokenPreview,
                              nextTokenNumber: _tokenPreviewNumber,
                              onSelect: (session) {
                                notifier.updateTokenSession(session);
                                _loadTokenPreview(form.selectedDoctorId, form.selectedDate, session);
                              },
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            // ── Morning / Evening slot accordion — uses this doctor's own
                            // working-hours slots (falls back to the tenant-wide defaults
                            // while loading or on error, see _morningSlots/_eveningSlots).
                            if (_morningSlots.isNotEmpty)
                              _SlotAccordionSection(
                                title: tr(ref, 'Morning Slots'),
                                slots: _morningSlots,
                                selectedSlot: form.selectedSlot,
                                bookedSlots: _bookedSlots,
                                blockedSlots: _blockedSlots,
                                selectedDate: form.selectedDate,
                                onSelect: notifier.updateSlot,
                                expanded: _expandedSlotSession == 'MORNING',
                                onToggle: () => setState(() =>
                                    _expandedSlotSession = _expandedSlotSession == 'MORNING' ? '' : 'MORNING'),
                              ),
                            if (_morningSlots.isNotEmpty && _eveningSlots.isNotEmpty)
                              const SizedBox(height: 12),
                            if (_eveningSlots.isNotEmpty)
                              _SlotAccordionSection(
                                title: tr(ref, 'Evening Slots'),
                                slots: _eveningSlots,
                                selectedSlot: form.selectedSlot,
                                bookedSlots: _bookedSlots,
                                blockedSlots: _blockedSlots,
                                selectedDate: form.selectedDate,
                                onSelect: notifier.updateSlot,
                                expanded: _expandedSlotSession == 'EVENING',
                                onToggle: () => setState(() =>
                                    _expandedSlotSession = _expandedSlotSession == 'EVENING' ? '' : 'EVENING'),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ],

                      // ── Book button
                      PrimaryButton(
                        label: tr(ref, 'Book Appointment'),
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

// ── Slot accordion section ──────────────────────────────────────────────────────

class _SlotAccordionSection extends StatelessWidget {
  final String title;
  final List<String> slots;
  final String selectedSlot;
  final List<String> bookedSlots;
  final List<String> blockedSlots;
  final String selectedDate;
  final ValueChanged<String> onSelect;
  final bool expanded;
  final VoidCallback onToggle;

  const _SlotAccordionSection({
    required this.title,
    required this.slots,
    required this.selectedSlot,
    required this.bookedSlots,
    this.blockedSlots = const [],
    required this.selectedDate,
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
                        style: AppTextStyles.sectionTitle(SevaCareColors.text)),
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
                selectedSlot: selectedSlot,
                bookedSlots: bookedSlots,
                blockedSlots: blockedSlots,
                selectedDate: selectedDate,
                onSelect: onSelect,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Slot chip grid ────────────────────────────────────────────────────────────

class _SlotGrid extends StatelessWidget {
  final List<String> slots;
  final String selectedSlot;
  final List<String> bookedSlots;
  final List<String> blockedSlots;
  final String selectedDate;
  final ValueChanged<String> onSelect;

  const _SlotGrid({
    required this.slots,
    required this.selectedSlot,
    required this.bookedSlots,
    this.blockedSlots = const [],
    required this.selectedDate,
    required this.onSelect,
  });

  bool _isPast(String slot) {
    final today = DateTime.now();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    if (selectedDate != todayStr) return false;
    final parts = slot.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h < today.hour || (h == today.hour && m <= today.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isBooked = bookedSlots.contains(slot);
        final isBlocked = blockedSlots.contains(slot);
        final isPast = _isPast(slot);
        final isDisabled = isBooked || isBlocked || isPast;
        final isSelected = !isDisabled && selectedSlot == slot;

        String label;
        try {
          label = AppDateUtils.formatSlot(slot);
        } catch (_) {
          label = slot;
        }

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (isBlocked) {
          bgColor = SevaCareColors.warningSurface;
          borderColor = SevaCareColors.warning;
          textColor = SevaCareColors.warning;
        } else if (isBooked) {
          bgColor = const Color(0xFFFFEDED);
          borderColor = SevaCareColors.danger;
          textColor = SevaCareColors.danger;
        } else if (isPast) {
          bgColor = SevaCareColors.border;
          borderColor = SevaCareColors.border;
          textColor = SevaCareColors.textMuted;
        } else if (isSelected) {
          bgColor = SevaCareColors.primary;
          borderColor = SevaCareColors.primary;
          textColor = SevaCareColors.textOnPrimary;
        } else {
          bgColor = SevaCareColors.surface;
          borderColor = SevaCareColors.border;
          textColor = SevaCareColors.text;
        }

        return GestureDetector(
          onTap: isDisabled ? null : () => onSelect(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: SevaCareColors.buttonGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: isSelected ? null : bgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
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
              style: AppTextStyles.chipLabel(textColor),
            ),
          ),
        );
      }).toList(),
    );
  }
}
