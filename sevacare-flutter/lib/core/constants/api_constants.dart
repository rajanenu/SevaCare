import '../config/app_config.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';

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
