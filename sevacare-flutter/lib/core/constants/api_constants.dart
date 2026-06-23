class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://localhost:8081/api/v1';

  // Auth
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';

  // Public
  static const String publicTenants = '/public/tenants';
  static const String publicLookups = '/public/lookups';
  static String publicDoctors(String tenantId) => '/public/tenants/$tenantId/doctors';
  static String publicOnboardingRequest = '/public/onboarding/request';

  // Patient
  static String patientHome(String tenantId, String patientId) => '/patients/$tenantId/$patientId/home';
  static String bookingSetup(String tenantId, String patientId) => '/patients/$tenantId/$patientId/booking/setup';
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

  // Platform Admin
  static const String platformOverview = '/platform-admin/overview';
  static const String platformTenants = '/platform-admin/tenants';
  static String platformTenant(String tenantId) => '/platform-admin/tenants/$tenantId';
  static String generateQrCode(String tenantId) => '/platform-admin/tenants/$tenantId/qrcode/generate';
  static String qrCodeFormData(String uuid) => '/public/qrcode/$uuid/form-data';
  static String qrCodeAppointmentRequest(String uuid) => '/public/qrcode/$uuid/appointment-request';
  static const String platformOnboardingRequests = '/platform-admin/onboarding-requests';
  static const String platformAdminUsers = '/platform-admin/users';
  static String platformAdminUser(String adminId) => '/platform-admin/users/$adminId';
  static String deactivatePlatformAdmin(String adminId) => '/platform-admin/users/$adminId/deactivate';
}
