import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../data/models/models.dart';

/// A fresh Idempotency-Key for one logical attempt (a checkout, a booking tap).
/// Hold it across retries of the same attempt — that is what lets the server
/// recognise the retry — and clear it only after the request succeeds.
String newIdempotencyKey() =>
    'idem-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0xFFFFFF)}';

class SevaCareRepository {
  final ApiClient _client;

  SevaCareRepository(this._client);

  // ── Public ──────────────────────────────────────────────────────────────────

  /// The public tenant directory.
  ///
  /// [module] narrows it to one shelf — `'clinical'` for Search Hospitals,
  /// `'pharmacy'` for Search Pharmacies — and the server does the filtering, so a
  /// medical store never reaches the hospital list to be sieved out here.
  /// Omitting it lists every tenant.
  Future<List<TenantSummary>> listTenants({String? module}) async {
    final data = await _client.get<Map<String, dynamic>>(
      module == null || module.isEmpty
          ? ApiConstants.publicTenants
          : '${ApiConstants.publicTenants}?module=$module',
      fromJson: (d) => d as Map<String, dynamic>,
    );
    final list = data['tenants'] as List? ?? [];
    final tenants = list.map((e) => TenantSummary.fromJson(e as Map<String, dynamic>)).toList();
    return tenants.asMap().entries.map((entry) {
      final t = entry.value;
      return TenantSummary(
        tenantPublicId: t.tenantPublicId,
        hospitalName: t.hospitalName,
        city: t.city,
        specialty: t.specialty,
        themeKey: t.themeKey,
        distance: '${entry.key + 1}.0 km',
        pinCode: t.pinCode,
        hasClinical: t.hasClinical,
        hasPharmacy: t.hasPharmacy,
      );
    }).toList();
  }

  /// Hospital hero image (login-screen background). Returns the base64
  /// payload, or null when the hospital has no image uploaded.
  Future<String?> getTenantHeroImageBase64(String tenantId) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.publicTenantHeroImage(tenantId),
      fromJson: (d) => d as Map<String, dynamic>,
    );
    final b64 = data['imageBase64'] as String?;
    return (b64 == null || b64.isEmpty) ? null : b64;
  }

  Future<ReferenceLookups> getLookups() async {
    return _client.get<ReferenceLookups>(
      ApiConstants.publicLookups,
      fromJson: (d) => ReferenceLookups.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<List<DoctorSummary>> listPublicDoctors(String tenantId) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.publicDoctors(tenantId),
      fromJson: (d) => d as Map<String, dynamic>,
    );
    final list = data['doctors'] as List? ?? [];
    return list.map((e) => DoctorSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Returns the credential mode for this mobile: 'PASSCODE' when the user set
  /// their own 4-digit code (the login screen asks for it), else 'DEFAULT_OTP'.
  Future<String> requestOtp(OtpRequest req) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiConstants.otpRequest,
      body: req.toJson(),
      fromJson: (d) => d as Map<String, dynamic>,
    );
    return data['credentialMode'] as String? ?? 'DEFAULT_OTP';
  }

  // ── Login passcode ─────────────────────────────────────────────────────────

  /// Whether the signed-in user's mobile still uses the default OTP or has a
  /// self-set passcode. Returns 'PASSCODE' or 'DEFAULT_OTP'. Tenant-free: the
  /// server resolves the caller from the token.
  Future<String> getPasscodeStatus(String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.accountPasscode,
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
    return data['credentialMode'] as String? ?? 'DEFAULT_OTP';
  }

  /// Set or change the caller's own passcode. [currentCode] is what they log in
  /// with today (the default OTP, or their existing passcode).
  Future<void> changePasscode(String token, String currentCode, String newPasscode) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.accountPasscode,
      body: {'currentCode': currentCode, 'newPasscode': newPasscode},
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  /// Hospital/store admin: clear a forgotten passcode for a user of their own
  /// tenant, so the default OTP applies again until a new code is set.
  Future<void> adminResetPasscode(String tenantId, String token, String mobileNumber) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.adminPasscodeReset(tenantId),
      body: {'mobileNumber': mobileNumber},
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Platform admin: clear any user's passcode, including a hospital admin's.
  Future<void> platformResetPasscode(String token, String mobileNumber) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.platformPasscodeReset,
      body: {'mobileNumber': mobileNumber},
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<AuthenticatedSession> verifyOtp(OtpVerifyRequest req) async {
    return _client.post<AuthenticatedSession>(
      ApiConstants.otpVerify,
      body: req.toJson(),
      fromJson: (d) => AuthenticatedSession.fromJson(d as Map<String, dynamic>),
    );
  }

  /// Exchanges a live refresh token for a fresh access token. The refresh token
  /// rotates: the one sent here is dead afterwards, use only the returned one.
  Future<RefreshedSession> refreshSession(String refreshToken) async {
    return _client.post<RefreshedSession>(
      ApiConstants.authRefresh,
      body: {'refreshToken': refreshToken},
      fromJson: (d) => RefreshedSession.fromJson(d as Map<String, dynamic>),
    );
  }

  /// Real logout: revokes the refresh token and the bearer's jti server-side.
  /// The endpoint never fails, but callers should still treat this as
  /// best-effort — local sign-out must not wait on a dead network.
  Future<void> logout(String token, String? refreshToken) async {
    await _client.post<dynamic>(
      ApiConstants.authLogout,
      body: {'refreshToken': refreshToken},
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  // ── Standalone pharmacy login ────────────────────────────────────────────

  /// Resolve which medical store(s) a mobile number can sign into. Throws with a
  /// friendly message if the number isn't registered at any store.
  Future<PharmacyOtpResponse> pharmacyRequestOtp(String mobileNumber) async {
    return _client.post<PharmacyOtpResponse>(
      ApiConstants.pharmacyAuthRequestOtp,
      body: {'mobileNumber': mobileNumber},
      fromJson: (d) => PharmacyOtpResponse.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<AuthenticatedSession> pharmacyVerify(
      String mobileNumber, String otp, String tenantPublicId) async {
    return _client.post<AuthenticatedSession>(
      ApiConstants.pharmacyAuthVerify,
      body: {'mobileNumber': mobileNumber, 'otp': otp, 'tenantPublicId': tenantPublicId},
      fromJson: (d) => AuthenticatedSession.fromJson(d as Map<String, dynamic>),
    );
  }

  // ── Onboarding ──────────────────────────────────────────────────────────────

  Future<TenantOnboardingAccepted> requestOnboarding(TenantOnboardingRequest req) async {
    return _client.post<TenantOnboardingAccepted>(
      ApiConstants.publicOnboardingRequest,
      body: req.toJson(),
      fromJson: (d) => TenantOnboardingAccepted.fromJson(d as Map<String, dynamic>),
    );
  }

  // ── Patient ─────────────────────────────────────────────────────────────────

  Future<PatientHomeView> getPatientHome(String tenantId, String patientId, String token) async {
    return _client.get<PatientHomeView>(
      ApiConstants.patientHome(tenantId, patientId),
      fromJson: (d) => PatientHomeView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<BookingSetupView> getBookingSetup(String tenantId, String patientId, String token) async {
    return _client.get<BookingSetupView>(
      ApiConstants.bookingSetup(tenantId, patientId),
      fromJson: (d) => BookingSetupView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<String>> getBookedSlots(String tenantId, String doctorId, String date, String token) async {
    return _client.get<List<String>>(
      ApiConstants.bookedSlots(tenantId, doctorId, date),
      fromJson: (d) => List<String>.from(d as List),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Booked + doctor-blocked slots and leave status in one call.
  Future<SlotStatusView> getSlotStatus(
      String tenantId, String doctorId, String date, String token) async {
    return _client.get<SlotStatusView>(
      ApiConstants.slotStatus(tenantId, doctorId, date),
      fromJson: (d) => SlotStatusView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Read-only peek at the next token number for a doctor/date/session — does not reserve it.
  Future<TokenPreviewView> getTokenPreview(
      String tenantId, String doctorId, String date, String session, String token) async {
    return _client.get<TokenPreviewView>(
      ApiConstants.tokenPreview(tenantId, doctorId, date, session),
      fromJson: (d) => TokenPreviewView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// IP-Staff/Admin resets a doctor's token counter for a date/session back to zero.
  Future<void> resetTokenCounter(
      String tenantId, String doctorId, String date, String session, String token) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.tokenReset(tenantId),
      body: {
        'tenantPublicId': tenantId,
        'doctorPublicId': doctorId,
        'date': date,
        'session': session,
      },
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<Map<String, dynamic>> bookAppointment(
      String tenantId, String patientId, String token, AppointmentBookingRequest body,
      {String? idempotencyKey}) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.bookAppointment(tenantId, patientId),
      body: body.toJson(),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {
        'Authorization': 'Bearer $token',
        'X-Tenant-Id': tenantId,
        'Idempotency-Key': ?idempotencyKey,
      },
    );
  }

  Future<PatientRecord> getPatientRecord(String tenantId, String patientId, String token) async {
    return _client.get<PatientRecord>(
      ApiConstants.patientRecord(tenantId, patientId),
      fromJson: (d) => PatientRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<PatientRecord> upsertPatientRecord(
      String tenantId, String patientId, String token, PatientUpsertRequest body) async {
    return _client.put<PatientRecord>(
      ApiConstants.patientRecord(tenantId, patientId),
      body: body.toJson(),
      fromJson: (d) => PatientRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<Map<String, dynamic>> getAdminPatients(
      String tenantId, int page, int size, String? search, String token,
      {String? sortBy, String? sortDir, String? fromDate, String? toDate, String? specialty}) async {
    return _client.get<Map<String, dynamic>>(
      ApiConstants.adminPatients(tenantId, page: page, size: size, search: search, sortBy: sortBy, sortDir: sortDir, fromDate: fromDate, toDate: toDate, specialty: specialty),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> deletePatient(String tenantId, String patientId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.adminDeletePatient(tenantId, patientId),
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Self-service "delete my account" — disables login only, no data is removed.
  Future<void> deleteMyPatientAccount(String tenantId, String patientId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.deletePatientAccount(tenantId, patientId),
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<PhotoView> getPatientPhoto(String tenantId, String patientId, String token) async {
    return _client.get<PhotoView>(
      ApiConstants.patientPhoto(tenantId, patientId),
      fromJson: (d) => PhotoView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> updatePatientPhoto(String tenantId, String patientId, String token, String? photoBase64) async {
    await _client.put<dynamic>(
      ApiConstants.patientPhoto(tenantId, patientId),
      body: {'photoBase64': photoBase64},
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<PrescriptionCollectionView> getPatientPrescriptions(
      String tenantId, String patientId, String token) async {
    return _client.get<PrescriptionCollectionView>(
      ApiConstants.patientPrescriptions(tenantId, patientId),
      fromJson: (d) => PrescriptionCollectionView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<PrescriptionDetailView> getPrescriptionDetail(
      String tenantId, String rxId, String token) async {
    return _client.get<PrescriptionDetailView>(
      ApiConstants.prescriptionDetail(tenantId, rxId),
      fromJson: (d) => PrescriptionDetailView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<MedicalHistoryView> getPatientMedicalHistory(
      String tenantId, String patientId, String token) async {
    return _client.get<MedicalHistoryView>(
      ApiConstants.patientMedicalHistory(tenantId, patientId),
      fromJson: (d) => MedicalHistoryView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<AppointmentActionResult> cancelAppointment(
      String tenantId, String patientId, String apptId, String token, {String? reason}) async {
    return _client.put<AppointmentActionResult>(
      ApiConstants.cancelAppointment(tenantId, patientId, apptId),
      body: AppointmentCancelRequest(reason: reason).toJson(),
      fromJson: (d) => AppointmentActionResult.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<AppointmentActionResult> rescheduleAppointment(
      String tenantId, String patientId, String apptId, String token, String newSlot) async {
    return _client.put<AppointmentActionResult>(
      ApiConstants.rescheduleAppointment(tenantId, patientId, apptId),
      body: AppointmentRescheduleRequest(newSlot: newSlot).toJson(),
      fromJson: (d) => AppointmentActionResult.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<ReviewSubmitResult> submitReview(String tenantId, String patientId, String apptId,
      String token, int rating, String? comment) async {
    return _client.post<ReviewSubmitResult>(
      ApiConstants.submitReview(tenantId, patientId, apptId),
      body: {'rating': rating, 'comment': comment},
      fromJson: (d) => ReviewSubmitResult.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<QueueStatusView> getQueueStatus(
      String tenantId, String patientId, String apptId, String token) async {
    return _client.get<QueueStatusView>(
      ApiConstants.queueStatus(tenantId, patientId, apptId),
      fromJson: (d) => QueueStatusView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Doctor ──────────────────────────────────────────────────────────────────

  Future<DoctorDashboardView> getDoctorDashboard(
      String tenantId, String doctorId, String token) async {
    return _client.get<DoctorDashboardView>(
      ApiConstants.doctorDashboard(tenantId, doctorId),
      fromJson: (d) => DoctorDashboardView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<DoctorQueueDayView> getDoctorQueue(
      String tenantId, String doctorId, String date, String token) async {
    return _client.get<DoctorQueueDayView>(
      ApiConstants.doctorQueue(tenantId, doctorId, date),
      fromJson: (d) => DoctorQueueDayView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<DoctorRecord>> listDoctorRecords(String tenantId, String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.doctorRecords(tenantId),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final list = data['doctors'] as List? ?? [];
    return list.map((e) => DoctorRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DoctorRecord> getDoctorRecord(String tenantId, String doctorId, String token) async {
    return _client.get<DoctorRecord>(
      ApiConstants.doctorRecord(tenantId, doctorId),
      fromJson: (d) => DoctorRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<String> getNextDoctorId(String tenantId, String token) async {
    return _client.get<String>(
      ApiConstants.nextDoctorId(tenantId),
      fromJson: (d) => d as String,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<DoctorRecord> createDoctorRecord(
      String tenantId, String token, DoctorUpsertRequest body) async {
    return _client.post<DoctorRecord>(
      ApiConstants.doctorRecords(tenantId),
      body: body.toJson(),
      fromJson: (d) => DoctorRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<DoctorRecord> upsertDoctorRecord(
      String tenantId, String doctorId, String token, DoctorUpsertRequest body) async {
    return _client.put<DoctorRecord>(
      ApiConstants.doctorRecord(tenantId, doctorId),
      body: body.toJson(),
      fromJson: (d) => DoctorRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Doctor's own working-hours rules (date range + weekend flags + time window).
  /// Each rule is `{dayScope, sessionLabel, startTime, endTime, fromDate,
  /// toDate, includeSaturday, includeSunday}` — dates nullable (null = unbounded).
  Future<List<Map<String, dynamic>>> getDoctorWorkingHours(
      String tenantId, String doctorId, String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.doctorWorkingHours(tenantId, doctorId),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final rules = data['rules'] as List? ?? [];
    return rules.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> updateDoctorWorkingHours(
    String tenantId,
    String doctorId,
    String token,
    List<Map<String, dynamic>> rules,
  ) async {
    final data = await _client.put<Map<String, dynamic>>(
      ApiConstants.doctorWorkingHours(tenantId, doctorId),
      body: {'rules': rules},
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final updated = data['rules'] as List? ?? [];
    return updated.cast<Map<String, dynamic>>();
  }

  /// This doctor's actual bookable morning/evening slots for one date, derived
  /// from their working hours — use in place of the tenant-wide booking/setup
  /// slots once a specific doctor is selected.
  Future<Map<String, dynamic>> getDoctorSlots(
      String tenantId, String doctorId, String date, String token) async {
    return _client.get<Map<String, dynamic>>(
      ApiConstants.doctorSlots(tenantId, doctorId, date),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Dates (yyyy-MM-dd) on which this doctor has NO working hours, over
  /// [days] days starting at [from] — used to gray out the booking date strip.
  Future<Set<String>> getDoctorUnavailableDates(
      String tenantId, String doctorId, String from, int days, String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.doctorAvailableDates(tenantId, doctorId, from, days),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final dates = data['dates'] as List? ?? const [];
    return {
      for (final d in dates.cast<Map<String, dynamic>>())
        if (d['available'] == false) d['date'] as String,
    };
  }

  Future<void> deleteDoctorRecord(String tenantId, String doctorId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.doctorRecord(tenantId, doctorId),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Self-service "delete my account" — disables login only, no data is removed.
  Future<void> deleteMyDoctorAccount(String tenantId, String doctorId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.deleteDoctorAccount(tenantId, doctorId),
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<PhotoView> getDoctorPhoto(String tenantId, String doctorId, String token) async {
    return _client.get<PhotoView>(
      ApiConstants.doctorPhoto(tenantId, doctorId),
      fromJson: (d) => PhotoView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> updateDoctorPhoto(String tenantId, String doctorId, String token, String? photoBase64) async {
    await _client.put<dynamic>(
      ApiConstants.doctorPhoto(tenantId, doctorId),
      body: {'photoBase64': photoBase64},
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<DoctorPatientView>> getDoctorPatients(
      String tenantId, String doctorId, String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.doctorPatients(tenantId, doctorId),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final list = data['patients'] as List? ?? [];
    return list.map((e) => DoctorPatientView.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PrescriptionDetailView>> getDoctorPrescriptions(
      String tenantId, String doctorId, String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.doctorPrescriptions(tenantId, doctorId),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final list = data['prescriptions'] as List? ?? [];
    return list.map((e) => PrescriptionDetailView.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> uploadPrescription(
      String tenantId, String doctorId, String token, PrescriptionUploadRequest body) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.uploadPrescription(tenantId, doctorId),
      body: body.toJson(),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Slot blocks (partial-day unavailability) ────────────────────────────────

  Future<List<SlotBlockView>> listSlotBlocks(
      String tenantId, String doctorId, String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.slotBlocks(tenantId, doctorId),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final list = data['blocks'] as List? ?? [];
    return list.map((e) => SlotBlockView.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SlotBlockView> createSlotBlock(String tenantId, String doctorId,
      String token,
      {required String date,
      required String startTime,
      required String endTime,
      String reason = ''}) async {
    return _client.post<SlotBlockView>(
      ApiConstants.slotBlocks(tenantId, doctorId),
      body: {
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'reason': reason,
      },
      fromJson: (d) => SlotBlockView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> deleteSlotBlock(
      String tenantId, String doctorId, String blockId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.slotBlock(tenantId, doctorId, blockId),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Per-doctor availability (leave + blocked windows) for a date — used by IP-Staff.
  Future<List<DoctorAvailabilityView>> getDoctorAvailability(
      String tenantId, String date, String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.doctorAvailability(tenantId, date),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final list = data['doctors'] as List? ?? [];
    return list.map((e) => DoctorAvailabilityView.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> completeConsultation(
      String tenantId, String doctorId, String appointmentId, String token) async {
    // Backend returns a String payload ("completed") here, not a Map — casting
    // to Map<String, dynamic> throws client-side even though the PATCH already
    // succeeded server-side, which looked like "complete failed" to the doctor
    // while the appointment was in fact already marked completed.
    await _client.patch<dynamic>(
      ApiConstants.completeAppointment(tenantId, doctorId, appointmentId),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Admin ───────────────────────────────────────────────────────────────────

  Future<AdminOverview> getAdminOverview(String tenantId, String token) async {
    return _client.get<AdminOverview>(
      ApiConstants.adminOverview(tenantId),
      fromJson: (d) => AdminOverview.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Real, period-scoped performance for the Reports tab. period: today|week|month|year.
  Future<HospitalReport> getHospitalReport(String tenantId, String token, String period) async {
    return _client.get<HospitalReport>(
      ApiConstants.adminReport(tenantId, period),
      fromJson: (d) => HospitalReport.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Terms of service ────────────────────────────────────────────────────────

  /// Readable without a login — a hospital can read the terms before it has one.
  Future<TermsDocument> getTerms() async {
    return _client.get<TermsDocument>(
      ApiConstants.publicTerms,
      fromJson: (d) => TermsDocument.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<TermsAcceptance> getTermsAcceptance(String tenantId, String token) async {
    return _client.get<TermsAcceptance>(
      ApiConstants.termsAcceptance,
      fromJson: (d) => TermsAcceptance.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<TermsAcceptance> acceptTerms(
      String tenantId, String token, String version, String acceptedBy) async {
    return _client.post<TermsAcceptance>(
      ApiConstants.acceptTerms,
      body: {'version': version, 'acceptedBy': acceptedBy},
      fromJson: (d) => TermsAcceptance.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<AdminUserRecord>> listAdminUsers(String tenantId, String token,
      {bool activeOnly = false}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.adminUsers(tenantId, activeOnly: activeOnly),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final list = data['admins'] as List? ?? [];
    return list.map((e) => AdminUserRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> getNextAdminId(String tenantId, String token) async {
    return _client.get<String>(
      ApiConstants.nextAdminId(tenantId),
      fromJson: (d) => d as String,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<AdminUserRecord> createAdminUser(
      String tenantId, String token, AdminUserUpsertRequest body) async {
    return _client.post<AdminUserRecord>(
      ApiConstants.adminUsers(tenantId),
      body: body.toJson(),
      fromJson: (d) => AdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<AdminUserRecord> getAdminUser(
      String tenantId, String adminId, String token) async {
    return _client.get<AdminUserRecord>(
      ApiConstants.adminUser(tenantId, adminId),
      fromJson: (d) => AdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<AdminUserRecord> updateAdminUser(
      String tenantId, String adminId, String token, AdminUserUpsertRequest body) async {
    return _client.put<AdminUserRecord>(
      ApiConstants.adminUser(tenantId, adminId),
      body: body.toJson(),
      fromJson: (d) => AdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<AdminUserRecord> deactivateAdminUser(
      String tenantId, String adminId, String token) async {
    return _client.put<AdminUserRecord>(
      ApiConstants.deactivateAdmin(tenantId, adminId),
      fromJson: (d) => AdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> deleteAdminUser(String tenantId, String adminId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.adminUser(tenantId, adminId),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  /// Self-service "delete my account" (Admin or Staff) — disables login only.
  Future<void> deleteMyAdminOrStaffAccount(String tenantId, String adminId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.deleteAdminOrStaffAccount(tenantId, adminId),
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<PhotoView> getAdminOrStaffPhoto(String tenantId, String adminId, String token) async {
    return _client.get<PhotoView>(
      ApiConstants.adminOrStaffPhoto(tenantId, adminId),
      fromJson: (d) => PhotoView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> updateAdminOrStaffPhoto(String tenantId, String adminId, String token, String? photoBase64) async {
    await _client.put<dynamic>(
      ApiConstants.adminOrStaffPhoto(tenantId, adminId),
      body: {'photoBase64': photoBase64},
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Staff ───────────────────────────────────────────────────────────────────

  Future<List<AdminUserRecord>> listStaff(String tenantId, String token,
      {bool activeOnly = false}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.adminStaff(tenantId, activeOnly: activeOnly),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    final list = data['staff'] as List? ?? [];
    return list.map((e) => AdminUserRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminUserRecord> createStaff(
      String tenantId, String token, AdminUserUpsertRequest body) async {
    return _client.post<AdminUserRecord>(
      ApiConstants.adminStaff(tenantId),
      body: body.toJson(),
      fromJson: (d) => AdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<AdminUserRecord> deactivateStaff(
      String tenantId, String staffId, String token) async {
    return _client.put<AdminUserRecord>(
      ApiConstants.deactivateStaff(tenantId, staffId),
      fromJson: (d) => AdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<StaffBookingStat>> getStaffBookingStats(String tenantId, String token) async {
    final data = await _client.get<List<dynamic>>(
      ApiConstants.staffBookingStats(tenantId),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return data.map((e) => StaffBookingStat.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BookingChannelStats> getBookingChannelStats(String tenantId, String token) async {
    return _client.get<BookingChannelStats>(
      ApiConstants.bookingChannelStats(tenantId),
      fromJson: (d) => BookingChannelStats.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<HospitalProfileView> getHospitalProfile(String tenantId, String token) async {
    return _client.get<HospitalProfileView>(
      ApiConstants.hospitalProfile(tenantId),
      fromJson: (d) => HospitalProfileView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<HospitalProfileView> updateHospitalProfile(String tenantId, String token, String email) async {
    return _client.put<HospitalProfileView>(
      ApiConstants.hospitalProfile(tenantId),
      body: {'email': email},
      fromJson: (d) => HospitalProfileView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> deleteStaff(String tenantId, String staffId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.adminStaffMember(tenantId, staffId),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Platform Admin ──────────────────────────────────────────────────────────

  Future<PlatformAdminOverview> getPlatformOverview(String token) async {
    return _client.get<PlatformAdminOverview>(
      ApiConstants.platformOverview,
      fromJson: (d) => PlatformAdminOverview.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<PlatformTenantRecord>> listPlatformTenants(String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.platformTenants,
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
    final list = data['tenants'] as List? ?? [];
    return list.map((e) => PlatformTenantRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fills the "what kind of pharmacy?" dropdown. Served from the database, so a
  /// new capability profile appears without shipping a new app.
  Future<List<PharmacyProfileOption>> listPharmacyProfiles(String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.platformPharmacyProfiles,
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
    final list = data['profiles'] as List? ?? [];
    return list.map((e) => PharmacyProfileOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlatformTenantRecord> createPlatformTenant(
      PlatformTenantUpsertRequest body, String token) async {
    return _client.post<PlatformTenantRecord>(
      ApiConstants.platformTenants,
      body: body.toJson(),
      fromJson: (d) => PlatformTenantRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<PlatformTenantRecord> updatePlatformTenant(
      String tenantId, PlatformTenantUpsertRequest body, String token) async {
    return _client.put<PlatformTenantRecord>(
      ApiConstants.platformTenant(tenantId),
      body: body.toJson(),
      fromJson: (d) => PlatformTenantRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  /// Uploads (or clears, when [imageBase64] is null) a hospital's hero image.
  Future<void> uploadPlatformTenantHeroImage(
    String tenantId,
    String token,
    String? imageBase64, {
    String contentType = 'image/jpeg',
  }) async {
    await _client.put<dynamic>(
      ApiConstants.platformTenantHeroImage(tenantId),
      body: {'imageBase64': imageBase64, 'contentType': contentType},
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> deletePlatformTenant(String tenantId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.platformTenant(tenantId),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<PlatformAdminUserRecord>> listPlatformAdminUsers(String token,
      {bool activeOnly = false}) async {
    final path = activeOnly
        ? '${ApiConstants.platformAdminUsers}?activeOnly=true'
        : ApiConstants.platformAdminUsers;
    final data = await _client.get<Map<String, dynamic>>(
      path,
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
    final list = data['admins'] as List? ?? [];
    return list.map((e) => PlatformAdminUserRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlatformAdminUserRecord> getPlatformAdminUser(
      String adminId, String token) async {
    return _client.get<PlatformAdminUserRecord>(
      ApiConstants.platformAdminUser(adminId),
      fromJson: (d) => PlatformAdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<PlatformAdminUserRecord> createPlatformAdminUser(
      PlatformAdminUserUpsertRequest body, String token) async {
    return _client.post<PlatformAdminUserRecord>(
      ApiConstants.platformAdminUsers,
      body: body.toJson(),
      fromJson: (d) => PlatformAdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<PlatformAdminUserRecord> updatePlatformAdminUser(
      String adminId, PlatformAdminUserUpsertRequest body, String token) async {
    return _client.put<PlatformAdminUserRecord>(
      ApiConstants.platformAdminUser(adminId),
      body: body.toJson(),
      fromJson: (d) => PlatformAdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> deletePlatformAdminUser(String adminId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.platformAdminUser(adminId),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<PlatformAdminUserRecord> deactivatePlatformAdminUser(String adminId, String token) async {
    return _client.put<PlatformAdminUserRecord>(
      ApiConstants.deactivatePlatformAdmin(adminId),
      fromJson: (d) => PlatformAdminUserRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  /// Self-service "delete my account" — disables login only.
  Future<void> deleteMyPlatformAdminAccount(String adminId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.deletePlatformAdminAccount(adminId),
      fromJson: (d) => d,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> generateQrCode(String tenantId, String token) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.generateQrCode(tenantId),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> getQrCodeFormData(String qrcodeUuid) async {
    return _client.get<Map<String, dynamic>>(
      ApiConstants.qrCodeFormData(qrcodeUuid),
      fromJson: (d) => d as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> submitQrAppointmentRequest(
    String qrcodeUuid,
    Map<String, dynamic> body,
  ) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.qrCodeAppointmentRequest(qrcodeUuid),
      body: body,
      fromJson: (d) => d as Map<String, dynamic>,
    );
  }

  /// Chatbot booking with the same fields as the QR portal. The request lands
  /// in the chosen doctor's inbox and is auto-confirmed with the next token —
  /// the response carries requestStatus/assignedSlot to show the patient.
  Future<Map<String, dynamic>> submitQuickBookingRequest(
    String tenantPublicId, {
    required String patientName,
    required String patientMobile,
    int? patientAge,
    String? doctorPublicId,
    String? preferredDate,
    String? symptoms,
    String? specialty,
    String? doctorName,
  }) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.quickBookingRequest(tenantPublicId),
      body: {
        'patientName': patientName,
        'patientMobile': patientMobile,
        if (patientAge != null && patientAge > 0) 'patientAge': patientAge,
        if (doctorPublicId != null && doctorPublicId.isNotEmpty) 'doctorPublicId': doctorPublicId,
        if (preferredDate != null && preferredDate.isNotEmpty) 'preferredDate': preferredDate,
        if (symptoms != null && symptoms.trim().isNotEmpty) 'symptoms': symptoms.trim(),
        if (specialty != null && specialty.trim().isNotEmpty) 'specialty': specialty.trim(),
        if (doctorName != null && doctorName.trim().isNotEmpty) 'doctorName': doctorName.trim(),
      },
      fromJson: (d) => d as Map<String, dynamic>,
    );
  }

  /// Public get-or-create booking QR for a hospital — powers the QR icon in
  /// the hospital search list. Returns the qrcodeUuid used in the booking URL.
  Future<Map<String, dynamic>> getPublicTenantQrCode(String tenantPublicId) async {
    return _client.get<Map<String, dynamic>>(
      '/public/tenants/$tenantPublicId/qrcode',
      fromJson: (d) => d as Map<String, dynamic>,
    );
  }

  // ── Doctor Booking Requests (QR appointment requests inbox) ──────────────────

  Future<AppointmentRequestCollection> getDoctorAppointmentRequests(
    String tenantId,
    String doctorId,
    String token,
  ) async {
    return _client.get<AppointmentRequestCollection>(
      ApiConstants.doctorAppointmentRequests(tenantId, doctorId),
      fromJson: (d) => AppointmentRequestCollection.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<Map<String, dynamic>> confirmDoctorAppointmentRequest(
    String tenantId,
    String doctorId,
    String requestId,
    String token, {
    required String bookingType,
    String? slot,
    String? tokenSession,
    String? notes,
  }) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.confirmAppointmentRequest(tenantId, doctorId, requestId),
      body: {
        'bookingType': bookingType,
        if (slot != null && slot.isNotEmpty) 'slot': slot,
        if (tokenSession != null && tokenSession.isNotEmpty) 'tokenSession': tokenSession,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<PlatformOnboardingRequestRecord>> listOnboardingRequests(String token) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.platformOnboardingRequests,
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token'},
    );
    final list = data['requests'] as List? ?? [];
    return list.map((e) => PlatformOnboardingRequestRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Leave Requests ───────────────────────────────────────────────────────────

  Future<LeaveRequestCollection> getDoctorLeaveRequests(String tenantId, String doctorId, String token) async {
    return _client.get<LeaveRequestCollection>(
      ApiConstants.leaveRequests(tenantId, doctorId),
      fromJson: (d) => LeaveRequestCollection.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<LeaveRequestRecord> createLeaveRequest(
      String tenantId, String doctorId, String token, String adminPublicId,
      Map<String, dynamic> body) async {
    return _client.post<LeaveRequestRecord>(
      '${ApiConstants.leaveRequests(tenantId, doctorId)}?adminPublicId=${Uri.encodeComponent(adminPublicId)}',
      body: body,
      fromJson: (d) => LeaveRequestRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<LeaveRequestCollection> getStaffLeaveRequests(String tenantId, String staffId, String token) async {
    return _client.get<LeaveRequestCollection>(
      ApiConstants.staffLeaveRequests(tenantId, staffId),
      fromJson: (d) => LeaveRequestCollection.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<LeaveRequestRecord> createStaffLeaveRequest(
      String tenantId, String staffId, String token, Map<String, dynamic> body) async {
    return _client.post<LeaveRequestRecord>(
      ApiConstants.staffLeaveRequests(tenantId, staffId),
      body: body,
      fromJson: (d) => LeaveRequestRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<LeaveRequestCollection> getAdminLeaveRequests(String tenantId, String token) async {
    return _client.get<LeaveRequestCollection>(
      ApiConstants.adminLeaveRequests(tenantId),
      fromJson: (d) => LeaveRequestCollection.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<LeaveRequestRecord> actionLeaveRequest(
      String tenantId, String requestId, String token, String action, String? response) async {
    return _client.put<LeaveRequestRecord>(
      ApiConstants.leaveRequestAction(tenantId, requestId),
      body: {'action': action, 'response': response ?? ''},
      fromJson: (d) => LeaveRequestRecord.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Notifications ────────────────────────────────────────────────────────────

  Future<NotificationCollection> getNotifications(
      String tenantId, String recipientId, String recipientType, String token) async {
    return _client.get<NotificationCollection>(
      ApiConstants.notifications(tenantId, recipientId, recipientType),
      fromJson: (d) => NotificationCollection.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> markNotificationRead(String tenantId, String notifId, String token) async {
    await _client.post<String>(
      ApiConstants.markNotificationRead(tenantId, notifId),
      body: {},
      fromJson: (d) => d.toString(),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<void> markAllNotificationsRead(
      String tenantId, String recipientId, String recipientType, String token) async {
    await _client.post<String>(
      ApiConstants.markAllNotificationsRead(tenantId, recipientId, recipientType),
      body: {},
      fromJson: (d) => d.toString(),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Admin Messages ───────────────────────────────────────────────────────────

  Future<void> sendAdminMessage(String tenantId, String token,
      {required String title,
      required String body,
      required String targetType,
      String? targetDoctorId,
      String? targetSpecialty}) async {
    await _client.post<String>(
      ApiConstants.adminMessages(tenantId),
      body: {
        'title': title,
        'body': body,
        'targetType': targetType,
        'targetDoctorId': ?targetDoctorId,
        'targetSpecialty': ?targetSpecialty,
      },
      fromJson: (d) => d.toString(),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  // ── Capabilities & Pharmacy ───────────────────────────────────────────────────

  Future<Capabilities> getCapabilities(String tenantId, String token) async {
    return _client.get<Capabilities>(
      ApiConstants.capabilities,
      fromJson: (d) => Capabilities.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<PharmacySku>> searchCatalog(String tenantId, String token, String query, {int limit = 15}) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyCatalogSearch(tenantId, query, limit: limit),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => PharmacySku.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The whole active catalog with live on-hand + MRP. The counter holds this and
  /// searches it locally, so every keystroke is instant and offline.
  ///
  /// Kept on the device between sessions and revalidated with the tag the server
  /// stamps it with. Opening the till usually costs a 304 and no download; the
  /// moment a colleague rings up a sale the tag moves and the new shelf arrives.
  /// If the network is down we serve the shelf we hold rather than an empty
  /// counter — stale stock a pharmacist can sanity-check beats no medicines at all.
  Future<List<PharmacySku>> catalogStock(String tenantId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    final bodyKey = 'pharmacy_catalog_body_$tenantId';
    final etagKey = 'pharmacy_catalog_etag_$tenantId';
    final held = prefs.getString(bodyKey);

    try {
      final result = await _client.getIfChanged<List<dynamic>>(
        ApiConstants.pharmacyCatalogStock(tenantId),
        fromJson: (d) => d as List<dynamic>,
        etag: held == null ? null : prefs.getString(etagKey),
        extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
      );

      if (result.notModified && held != null) {
        return _decodeCatalog(held);
      }
      final list = result.data ?? const <dynamic>[];
      if (result.etag != null) {
        await prefs.setString(bodyKey, jsonEncode(list));
        await prefs.setString(etagKey, result.etag!);
      }
      return list.map((e) => PharmacySku.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      if (held != null) return _decodeCatalog(held);
      rethrow;
    }
  }

  List<PharmacySku> _decodeCatalog(String body) => (jsonDecode(body) as List<dynamic>)
      .map((e) => PharmacySku.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<Map<String, dynamic>> importCatalog(
      String tenantId, String token, List<Map<String, dynamic>> rows) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.pharmacyCatalogImport(tenantId),
      body: {'rows': rows},
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<TopMedicine>> topMedicines(String tenantId, String token,
      {String period = 'WEEK', int limit = 15}) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyTopMedicines(tenantId, period: period, limit: limit),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => TopMedicine.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PharmacySku> createSku(String tenantId, String token, Map<String, dynamic> body) async {
    return _client.post<PharmacySku>(
      ApiConstants.pharmacyCreateSku(tenantId),
      body: body,
      fromJson: (d) => PharmacySku.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<GrnReceipt> receiveStock(String tenantId, String token, Map<String, dynamic> body) async {
    return _client.post<GrnReceipt>(
      ApiConstants.pharmacyReceiveStock(tenantId),
      body: body,
      fromJson: (d) => GrnReceipt.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<SaleReceipt> getReceipt(String tenantId, String token, String salePublicId) async {
    return _client.get<SaleReceipt>(
      ApiConstants.pharmacyReceipt(tenantId, salePublicId),
      fromJson: (d) => SaleReceipt.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<SaleReceipt> createSale(String tenantId, String token, Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    return _client.post<SaleReceipt>(
      ApiConstants.pharmacySales(tenantId),
      body: body,
      fromJson: (d) => SaleReceipt.fromJson(d as Map<String, dynamic>),
      extraHeaders: {
        'Authorization': 'Bearer $token',
        'X-Tenant-Id': tenantId,
        'Idempotency-Key': ?idempotencyKey,
      },
    );
  }

  Future<List<SaleSummary>> recentSales(String tenantId, String token, {int limit = 20}) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyRecentSales(tenantId, limit: limit),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => SaleSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SalesRegisterLine>> salesRegister(
      String tenantId, String token, String fromIso, String toIso) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacySalesRegister(tenantId, fromIso, toIso),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => SalesRegisterLine.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DaySummary> daySummary(String tenantId, String token, {String? date}) async {
    return _client.get<DaySummary>(
      ApiConstants.pharmacyDaySummary(tenantId, date: date),
      fromJson: (d) => DaySummary.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<DaySummary> rangeSummary(String tenantId, String token, String fromIso, String toIso) async {
    return _client.get<DaySummary>(
      ApiConstants.pharmacyRangeSummary(tenantId, fromIso, toIso),
      fromJson: (d) => DaySummary.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<DailyTotal>> dailyTotals(String tenantId, String token, String fromIso, String toIso) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyDailyTotals(tenantId, fromIso, toIso),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => DailyTotal.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SaleSummary>> salesInRange(
      String tenantId, String token, String fromIso, String toIso,
      {String sortBy = 'date', int limit = 100}) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacySalesInRange(tenantId, fromIso, toIso, sortBy: sortBy, limit: limit),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => SaleSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SaleReceipt?> lastSaleForMobile(String tenantId, String token, String mobile) async {
    try {
      return await _client.get<SaleReceipt>(
        ApiConstants.pharmacyLastSaleForMobile(tenantId, mobile),
        fromJson: (d) => SaleReceipt.fromJson(d as Map<String, dynamic>),
        extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> voidSale(String tenantId, String token, String salePublicId) async {
    await _client.post(
      ApiConstants.pharmacyVoidSale(tenantId, salePublicId),
      body: const {},
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<RecentReturn>> recentReturns(String tenantId, String token, {int limit = 20}) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyRecentReturns(tenantId, limit: limit),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => RecentReturn.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CreditOutstanding>> creditOutstanding(String tenantId, String token) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyCreditOutstanding(tenantId),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => CreditOutstanding.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CreditOutstanding?> creditOutstandingFor(String tenantId, String token, String mobile) async {
    try {
      return await _client.get<CreditOutstanding>(
        ApiConstants.pharmacyCreditOutstandingFor(tenantId, mobile),
        fromJson: (d) => CreditOutstanding.fromJson(d as Map<String, dynamic>),
        extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
      );
    } catch (_) {
      return null; // 404 = no credit history, not an error worth surfacing
    }
  }

  Future<CreditOutstanding> recordCreditPayment(
      String tenantId, String token, Map<String, dynamic> body) async {
    return _client.post<CreditOutstanding>(
      ApiConstants.pharmacyCreditPayments(tenantId),
      body: body,
      fromJson: (d) => CreditOutstanding.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<GstSlabTotal>> gstSummary(
      String tenantId, String token, String fromIso, String toIso) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyGstSummary(tenantId, fromIso, toIso),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => GstSlabTotal.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PharmacySku> updateSku(
      String tenantId, String token, String skuPublicId, Map<String, dynamic> body) async {
    return _client.post<PharmacySku>(
      ApiConstants.pharmacyUpdateSku(tenantId, skuPublicId),
      body: body,
      fromJson: (d) => PharmacySku.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<NearExpiryBatch>> nearExpiry(String tenantId, String token) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyNearExpiry(tenantId),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => NearExpiryBatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LowStockItem>> lowStock(String tenantId, String token) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyLowStock(tenantId),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => LowStockItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Supplier>> listSuppliers(String tenantId, String token) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacySuppliers(tenantId),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Supplier> createSupplier(String tenantId, String token, Map<String, dynamic> body) async {
    return _client.post<Supplier>(
      ApiConstants.pharmacySuppliers(tenantId),
      body: body,
      fromJson: (d) => Supplier.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<PostedGrn> postGrn(String tenantId, String token, Map<String, dynamic> body) async {
    return _client.post<PostedGrn>(
      ApiConstants.pharmacyGrn(tenantId),
      body: body,
      fromJson: (d) => PostedGrn.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<List<GrnSummary>> recentGrns(String tenantId, String token, {int limit = 20}) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyRecentGrns(tenantId, limit: limit),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => GrnSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReturnableLine>> returnableLines(
      String tenantId, String token, String salePublicId) async {
    final list = await _client.get<List<dynamic>>(
      ApiConstants.pharmacyReturnable(tenantId, salePublicId),
      fromJson: (d) => d as List<dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
    return list.map((e) => ReturnableLine.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PostedReturn> postReturn(String tenantId, String token, Map<String, dynamic> body) async {
    return _client.post<PostedReturn>(
      ApiConstants.pharmacyReturns(tenantId),
      body: body,
      fromJson: (d) => PostedReturn.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<MoneyView> moneyView(String tenantId, String token, {String? date}) async {
    return _client.get<MoneyView>(
      ApiConstants.pharmacyMoneyDay(tenantId, date: date),
      fromJson: (d) => MoneyView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }

  Future<MoneyView> closeDay(String tenantId, String token, Map<String, dynamic> body) async {
    return _client.post<MoneyView>(
      ApiConstants.pharmacyDayClose(tenantId),
      body: body,
      fromJson: (d) => MoneyView.fromJson(d as Map<String, dynamic>),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }
}
