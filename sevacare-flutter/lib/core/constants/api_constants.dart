import '../config/app_config.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';

  // Standalone medical-store login (mobile-first; backend resolves the shop)
  static const String pharmacyAuthRequestOtp = '/auth/pharmacy/request-otp';
  static const String pharmacyAuthVerify = '/auth/pharmacy/verify';

  // Own login passcode (self-set 4-digit code; tenant-free, resolved from the token)
  static const String accountPasscode = '/account/passcode';
  static String adminPasscodeReset(String tenantId) => '/admin/$tenantId/passcode-reset';
  static const String platformPasscodeReset = '/platform-admin/passcode-reset';

  // Public
  static const String publicTenants = '/public/tenants';
  static const String publicLookups = '/public/lookups';
  static String publicTenantHeroImage(String tenantId) => '/public/tenants/$tenantId/hero-image';
  static String publicDoctors(String tenantId) => '/public/tenants/$tenantId/doctors';
  static String publicOnboardingRequest = '/public/onboarding/request';

  // Patient
  static String patientHome(String tenantId, String patientId) => '/patients/$tenantId/$patientId/home';
  static String bookingSetup(String tenantId, String patientId) => '/patients/$tenantId/$patientId/booking/setup';
  static String bookedSlots(String tenantId, String doctorId, String date) =>
      '/patients/$tenantId/booking/booked-slots?doctorId=${Uri.encodeComponent(doctorId)}&date=${Uri.encodeComponent(date)}';
  static String slotStatus(String tenantId, String doctorId, String date) =>
      '/patients/$tenantId/booking/slot-status?doctorId=${Uri.encodeComponent(doctorId)}&date=${Uri.encodeComponent(date)}';
  static String doctorSlots(String tenantId, String doctorId, String date) =>
      '/patients/$tenantId/booking/doctor-slots?doctorId=${Uri.encodeComponent(doctorId)}&date=${Uri.encodeComponent(date)}';
  static String doctorAvailableDates(String tenantId, String doctorId, String from, int days) =>
      '/patients/$tenantId/booking/doctor-available-dates?doctorId=${Uri.encodeComponent(doctorId)}&from=${Uri.encodeComponent(from)}&days=$days';
  static String tokenPreview(String tenantId, String doctorId, String date, String session) =>
      '/patients/$tenantId/booking/token-preview?doctorId=${Uri.encodeComponent(doctorId)}&date=${Uri.encodeComponent(date)}&session=${Uri.encodeComponent(session)}';
  static String tokenReset(String tenantId) => '/patients/$tenantId/booking/token-reset';
  static String bookAppointment(String tenantId, String patientId) => '/patients/$tenantId/$patientId/appointments';
  static String patientPrescriptions(String tenantId, String patientId) => '/patients/$tenantId/$patientId/prescriptions';
  static String patientMedicalHistory(String tenantId, String patientId) => '/patients/$tenantId/$patientId/medical-history';
  // Single attachment's bytes, fetched on demand (the queue ships metadata only).
  static String patientAttachment(String tenantId, String attachmentPublicId) => '/patients/$tenantId/attachments/$attachmentPublicId';
  static String patientRecord(String tenantId, String patientId) => '/patients/$tenantId/records/$patientId';
  static String patientRecords(String tenantId) => '/patients/$tenantId/records';
  static String patientAppointments(String tenantId) => '/patients/$tenantId/appointments';
  static String patientAppointment(String tenantId, String apptId) => '/patients/$tenantId/appointments/$apptId';
  static String cancelAppointment(String tenantId, String patientId, String apptId) =>
      '/patients/$tenantId/$patientId/appointments/$apptId/cancel';
  static String rescheduleAppointment(String tenantId, String patientId, String apptId) =>
      '/patients/$tenantId/$patientId/appointments/$apptId/reschedule';
  static String submitReview(String tenantId, String patientId, String apptId) =>
      '/patients/$tenantId/$patientId/appointments/$apptId/review';
  static String queueStatus(String tenantId, String patientId, String apptId) =>
      '/patients/$tenantId/$patientId/appointments/$apptId/queue-status';
  static String deletePatientAccount(String tenantId, String patientId) =>
      '/patients/$tenantId/$patientId/account';
  static String patientPhoto(String tenantId, String patientId) => '/patients/$tenantId/$patientId/photo';

  // Doctor
  static String doctorDashboard(String tenantId, String doctorId) => '/doctors/$tenantId/$doctorId/dashboard';
  static String doctorQueue(String tenantId, String doctorId, String date) =>
      '/doctors/$tenantId/$doctorId/queue?date=${Uri.encodeComponent(date)}';
  static String doctorRecords(String tenantId) => '/doctors/$tenantId/records';
  static String doctorRecord(String tenantId, String doctorId) => '/doctors/$tenantId/records/$doctorId';
  static String nextDoctorId(String tenantId) => '/doctors/$tenantId/records/next-public-id';
  static String doctorPatients(String tenantId, String doctorId) => '/doctors/$tenantId/$doctorId/patients';
  static String doctorPrescriptions(String tenantId, String doctorId) => '/doctors/$tenantId/$doctorId/prescriptions/list';
  static String uploadPrescription(String tenantId, String doctorId) => '/doctors/$tenantId/$doctorId/prescriptions';
  static String completeAppointment(String tenantId, String doctorId, String apptId) => '/doctors/$tenantId/$doctorId/appointments/$apptId/complete';
  static String slotBlocks(String tenantId, String doctorId) => '/doctors/$tenantId/$doctorId/slot-blocks';
  static String slotBlock(String tenantId, String doctorId, String blockId) => '/doctors/$tenantId/$doctorId/slot-blocks/$blockId';
  static String doctorAvailability(String tenantId, String date) =>
      '/doctors/$tenantId/availability?date=${Uri.encodeComponent(date)}';
  static String doctorWorkingHours(String tenantId, String doctorId) =>
      '/doctors/$tenantId/$doctorId/working-hours';
  static String doctorAppointmentRequests(String tenantId, String doctorId) =>
      '/doctors/$tenantId/$doctorId/appointment-requests';
  static String confirmAppointmentRequest(String tenantId, String doctorId, String requestId) =>
      '/doctors/$tenantId/$doctorId/appointment-requests/$requestId/confirm';
  static String deleteDoctorAccount(String tenantId, String doctorId) =>
      '/doctors/$tenantId/$doctorId/account';
  static String doctorPhoto(String tenantId, String doctorId) => '/doctors/$tenantId/$doctorId/photo';

  // Prescription
  static String prescriptionDetail(String tenantId, String rxId) => '/prescriptions/$tenantId/$rxId/detail';
  static String prescriptionDownload(String tenantId, String rxId, String token) =>
      '$baseUrl/prescriptions/$tenantId/$rxId/download?token=$token';

  // Admin
  static String adminOverview(String tenantId) => '/admin/$tenantId/overview';
  /// period: today | week | month | year
  static String adminReport(String tenantId, String period) => '/admin/$tenantId/reports?period=$period';
  static String adminUsers(String tenantId, {bool activeOnly = false}) =>
      '/admin/$tenantId/users${activeOnly ? '?activeOnly=true' : ''}';
  static String adminUser(String tenantId, String adminId) => '/admin/$tenantId/users/$adminId';
  static String nextAdminId(String tenantId) => '/admin/$tenantId/users/next-public-id';
  static String deactivateAdmin(String tenantId, String adminId) => '/admin/$tenantId/users/$adminId/deactivate';

  // Staff
  static String adminStaff(String tenantId, {bool activeOnly = false}) =>
      '/admin/$tenantId/staff${activeOnly ? '?activeOnly=true' : ''}';
  static String adminStaffMember(String tenantId, String staffId) => '/admin/$tenantId/staff/$staffId';
  static String deactivateStaff(String tenantId, String staffId) => '/admin/$tenantId/staff/$staffId/deactivate';
  static String staffBookingStats(String tenantId) => '/admin/$tenantId/staff-booking-stats';
  static String bookingChannelStats(String tenantId) => '/admin/$tenantId/booking-channel-stats';
  static String hospitalProfile(String tenantId) => '/admin/$tenantId/hospital-profile';
  static String adminPatients(String tenantId, {int page = 0, int size = 10, String? search, String? sortBy, String? sortDir, String? fromDate, String? toDate, String? specialty}) {
    final buf = StringBuffer('/admin/$tenantId/patients?page=$page&size=$size');
    if (search != null && search.isNotEmpty) buf.write('&search=${Uri.encodeComponent(search)}');
    if (sortBy != null && sortBy.isNotEmpty) buf.write('&sortBy=${Uri.encodeComponent(sortBy)}');
    if (sortDir != null && sortDir.isNotEmpty) buf.write('&sortDir=${Uri.encodeComponent(sortDir)}');
    if (fromDate != null && fromDate.isNotEmpty) buf.write('&fromDate=${Uri.encodeComponent(fromDate)}');
    if (toDate != null && toDate.isNotEmpty) buf.write('&toDate=${Uri.encodeComponent(toDate)}');
    // Hospital-wide today; department-scoped staff can pass their specialty later.
    if (specialty != null && specialty.isNotEmpty) buf.write('&specialty=${Uri.encodeComponent(specialty)}');
    return buf.toString();
  }
  static String adminDeletePatient(String tenantId, String patientId) => '/admin/$tenantId/patients/$patientId';
  static String deleteAdminOrStaffAccount(String tenantId, String adminId) => '/admin/$tenantId/users/$adminId/account';
  static String adminOrStaffPhoto(String tenantId, String adminId) => '/admin/$tenantId/users/$adminId/photo';

  // ── IPD rooms ──
  static String rooms(String tenantId) => '/admin/$tenantId/rooms';
  static String room(String tenantId, int roomId) => '/admin/$tenantId/rooms/$roomId';
  static String admissions(String tenantId, {String status = 'ADMITTED'}) =>
      '/admin/$tenantId/admissions?status=$status';
  static String admit(String tenantId) => '/admin/$tenantId/admissions';
  static String discharge(String tenantId, int admissionId) =>
      '/admin/$tenantId/admissions/$admissionId/discharge';

  // Leave Requests
  static String leaveRequests(String tenantId, String doctorId) => '/$tenantId/doctors/$doctorId/leave-requests';
  static String staffLeaveRequests(String tenantId, String staffId) => '/$tenantId/staff/$staffId/leave-requests';
  static String adminLeaveRequests(String tenantId) => '/$tenantId/admin/leave-requests';
  static String leaveRequestAction(String tenantId, String requestId) => '/$tenantId/admin/leave-requests/$requestId/action';

  // Notifications
  static String notifications(String tenantId, String recipientId, String recipientType) =>
      '/$tenantId/notifications?recipientId=${Uri.encodeComponent(recipientId)}&recipientType=${Uri.encodeComponent(recipientType)}';
  static String markNotificationRead(String tenantId, String notifId) => '/$tenantId/notifications/$notifId/read';
  static String markAllNotificationsRead(String tenantId, String recipientId, String recipientType) =>
      '/$tenantId/notifications/read-all?recipientId=${Uri.encodeComponent(recipientId)}&recipientType=${Uri.encodeComponent(recipientType)}';

  // Admin Messages
  static String adminMessages(String tenantId) => '/$tenantId/admin/messages';

  // Capabilities — "what is this tenant?", asked right after login
  static const String capabilities = '/capabilities';

  // Terms of service — the document is public, accepting it is the tenant's own act
  static const String publicTerms = '/public/terms';
  static const String termsAcceptance = '/terms/acceptance';
  static const String acceptTerms = '/terms/accept';

  // Pharmacy
  static String pharmacyCatalogSearch(String tenantId, String query, {int limit = 15}) =>
      '/pharmacy/$tenantId/catalog/search?q=${Uri.encodeComponent(query)}&limit=$limit';
  static String pharmacyCatalogStock(String tenantId) => '/pharmacy/$tenantId/catalog/stock';
  static String pharmacyCatalogImport(String tenantId) => '/pharmacy/$tenantId/catalog/import';
  static String pharmacyTopMedicines(String tenantId, {String period = 'WEEK', int limit = 15}) =>
      '/pharmacy/$tenantId/analytics/top-medicines?period=$period&limit=$limit';
  static String pharmacyCreateSku(String tenantId) => '/pharmacy/$tenantId/catalog/skus';
  static String pharmacyReceiveStock(String tenantId) => '/pharmacy/$tenantId/stock/receive';
  static String pharmacyNearExpiry(String tenantId) => '/pharmacy/$tenantId/inventory/near-expiry';
  static String pharmacyLowStock(String tenantId) => '/pharmacy/$tenantId/inventory/low-stock';
  static String pharmacySales(String tenantId) => '/pharmacy/$tenantId/sales';
  static String pharmacyRecentSales(String tenantId, {int limit = 20}) =>
      '/pharmacy/$tenantId/sales/recent?limit=$limit';
  static String pharmacyDaySummary(String tenantId, {String? date}) =>
      '/pharmacy/$tenantId/sales/day-summary${date != null ? '?date=$date' : ''}';
  static String pharmacyReceipt(String tenantId, String salePublicId) =>
      '/pharmacy/$tenantId/sales/$salePublicId';
  static String pharmacySuppliers(String tenantId) => '/pharmacy/$tenantId/suppliers';
  static String pharmacyGrn(String tenantId) => '/pharmacy/$tenantId/grn';
  static String pharmacyRecentGrns(String tenantId, {int limit = 20}) =>
      '/pharmacy/$tenantId/grn/recent?limit=$limit';
  static String pharmacyReturnable(String tenantId, String salePublicId) =>
      '/pharmacy/$tenantId/sales/$salePublicId/returnable';
  static String pharmacyReturns(String tenantId) => '/pharmacy/$tenantId/returns';
  static String pharmacyMoneyDay(String tenantId, {String? date}) =>
      '/pharmacy/$tenantId/money/day${date != null ? '?date=$date' : ''}';
  static String pharmacyDayClose(String tenantId) => '/pharmacy/$tenantId/day-close';
  static String pharmacySalesRegister(String tenantId, String from, String to) =>
      '/pharmacy/$tenantId/reports/sales-register?from=$from&to=$to';
  static String pharmacyRangeSummary(String tenantId, String from, String to) =>
      '/pharmacy/$tenantId/sales/range-summary?from=$from&to=$to';
  static String pharmacyDailyTotals(String tenantId, String from, String to) =>
      '/pharmacy/$tenantId/analytics/daily-totals?from=$from&to=$to';
  static String pharmacySalesInRange(String tenantId, String from, String to,
          {String sortBy = 'date', int limit = 100}) =>
      '/pharmacy/$tenantId/sales/in-range?from=$from&to=$to&sortBy=$sortBy&limit=$limit';
  static String pharmacyLastSaleForMobile(String tenantId, String mobile) =>
      '/pharmacy/$tenantId/sales/last-for-mobile?mobile=${Uri.encodeComponent(mobile)}';
  static String pharmacyCustomerHistory(String tenantId, String mobile, {int page = 0, int size = 5}) =>
      '/pharmacy/$tenantId/sales/customer-history?mobile=${Uri.encodeComponent(mobile)}&page=$page&size=$size';
  static String pharmacyVoidSale(String tenantId, String salePublicId) =>
      '/pharmacy/$tenantId/sales/$salePublicId/void';
  static String pharmacyRecentReturns(String tenantId, {int limit = 20}) =>
      '/pharmacy/$tenantId/returns/recent?limit=$limit';
  static String pharmacyCreditOutstanding(String tenantId) =>
      '/pharmacy/$tenantId/credit/outstanding';
  static String pharmacyCreditOutstandingFor(String tenantId, String mobile) =>
      '/pharmacy/$tenantId/credit/outstanding-for?mobile=${Uri.encodeComponent(mobile)}';
  static String pharmacyCreditPayments(String tenantId) =>
      '/pharmacy/$tenantId/credit/payments';
  static String pharmacyGstSummary(String tenantId, String from, String to) =>
      '/pharmacy/$tenantId/reports/gst-summary?from=$from&to=$to';
  static String pharmacyUpdateSku(String tenantId, String skuPublicId) =>
      '/pharmacy/$tenantId/catalog/skus/$skuPublicId';

  // Platform Admin
  static const String platformOverview = '/platform-admin/overview';
  static const String platformTenants = '/platform-admin/tenants';
  static const String platformPharmacyProfiles = '/platform-admin/pharmacy-profiles';
  static String platformTenant(String tenantId) => '/platform-admin/tenants/$tenantId';
  static String platformTenantHeroImage(String tenantId) => '/platform-admin/tenants/$tenantId/hero-image';
  static String generateQrCode(String tenantId) => '/platform-admin/tenants/$tenantId/qrcode/generate';
  static String qrCodeFormData(String uuid) => '/public/qrcode/$uuid/form-data';
  static String qrCodeAppointmentRequest(String uuid) => '/public/qrcode/$uuid/appointment-request';
  static String quickBookingRequest(String tenantId) => '/public/tenant/$tenantId/quick-booking';
  static const String platformOnboardingRequests = '/platform-admin/onboarding-requests';
  static const String platformAdminUsers = '/platform-admin/users';
  static String platformAdminUser(String adminId) => '/platform-admin/users/$adminId';
  static String deactivatePlatformAdmin(String adminId) => '/platform-admin/users/$adminId/deactivate';
  static String deletePlatformAdminAccount(String adminId) => '/platform-admin/users/$adminId/account';
}
