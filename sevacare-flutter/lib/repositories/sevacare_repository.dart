import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../data/models/models.dart';

class SevaCareRepository {
  final ApiClient _client;

  SevaCareRepository(this._client);

  // ── Public ──────────────────────────────────────────────────────────────────

  Future<List<TenantSummary>> listTenants() async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.publicTenants,
      fromJson: (d) => d as Map<String, dynamic>,
    );
    final list = data['tenants'] as List? ?? [];
    final tenants = list.map((e) => TenantSummary.fromJson(e as Map<String, dynamic>)).toList();
    // Assign ascending distances for display
    for (var i = 0; i < tenants.length; i++) {
      // We can't mutate const, so recreate with distance
    }
    return tenants.asMap().entries.map((entry) {
      final t = entry.value;
      return TenantSummary(
        tenantPublicId: t.tenantPublicId,
        hospitalName: t.hospitalName,
        city: t.city,
        specialty: t.specialty,
        themeKey: t.themeKey,
        distance: '${entry.key + 1}.0 km',
      );
    }).toList();
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

  Future<void> requestOtp(OtpRequest req) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.otpRequest,
      body: req.toJson(),
      fromJson: (d) => d as Map<String, dynamic>,
    );
  }

  Future<AuthenticatedSession> verifyOtp(OtpVerifyRequest req) async {
    return _client.post<AuthenticatedSession>(
      ApiConstants.otpVerify,
      body: req.toJson(),
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
      String tenantId, String patientId, String token, AppointmentBookingRequest body) async {
    return _client.post<Map<String, dynamic>>(
      ApiConstants.bookAppointment(tenantId, patientId),
      body: body.toJson(),
      fromJson: (d) => d as Map<String, dynamic>,
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
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
      String tenantId, int page, int size, String? search, String token) async {
    return _client.get<Map<String, dynamic>>(
      ApiConstants.adminPatients(tenantId, page: page, size: size, search: search),
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

  Future<void> deleteDoctorRecord(String tenantId, String doctorId, String token) async {
    await _client.delete<dynamic>(
      ApiConstants.doctorRecord(tenantId, doctorId),
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
    await _client.patch<Map<String, dynamic>>(
      ApiConstants.completeAppointment(tenantId, doctorId, appointmentId),
      fromJson: (d) => d as Map<String, dynamic>,
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
        if (targetDoctorId case final id?) 'targetDoctorId': id,
        if (targetSpecialty case final s?) 'targetSpecialty': s,
      },
      fromJson: (d) => d.toString(),
      extraHeaders: {'Authorization': 'Bearer $token', 'X-Tenant-Id': tenantId},
    );
  }
}
