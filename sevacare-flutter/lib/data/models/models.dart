// Complete data model layer — mirrors sevacare-frontend/src/api/types.ts

// ── Auth ──────────────────────────────────────────────────────────────────────

enum UserRole { patient, doctor, admin, staff, platformAdmin }

extension UserRoleX on UserRole {
  String get apiValue => switch (this) {
    UserRole.patient => 'patient',
    UserRole.doctor => 'doctor',
    UserRole.admin => 'admin',
    UserRole.staff => 'admin',
    UserRole.platformAdmin => 'platform_admin',
  };

  String get label => switch (this) {
    UserRole.patient => 'Patient',
    UserRole.doctor => 'Doctor',
    UserRole.admin => 'Hospital Admin',
    UserRole.staff => 'IP-Staff',
    UserRole.platformAdmin => 'Platform Admin',
  };

  static UserRole fromApi(String role, {String? userType}) {
    if (role == 'admin' && userType == 'STAFF') return UserRole.staff;
    return switch (role) {
      'patient' => UserRole.patient,
      'doctor' => UserRole.doctor,
      'admin' => UserRole.admin,
      'platform_admin' => UserRole.platformAdmin,
      _ => UserRole.patient,
    };
  }
}

class OtpRequest {
  final String tenantPublicId;
  final String role;
  final String mobileNumber;

  const OtpRequest({
    required this.tenantPublicId,
    required this.role,
    required this.mobileNumber,
  });

  Map<String, dynamic> toJson() => {
    'tenantPublicId': tenantPublicId,
    'role': role,
    'mobileNumber': mobileNumber,
  };
}

class OtpVerifyRequest {
  final String tenantPublicId;
  final String role;
  final String mobileNumber;
  final String otp;

  const OtpVerifyRequest({
    required this.tenantPublicId,
    required this.role,
    required this.mobileNumber,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
    'tenantPublicId': tenantPublicId,
    'role': role,
    'mobileNumber': mobileNumber,
    'otp': otp,
  };
}

class AuthenticatedSession {
  final String tenantPublicId;
  final String role;
  final String subjectPublicId;
  final String token;
  final bool isGeneric;
  final String subjectName;
  final String userType;

  const AuthenticatedSession({
    required this.tenantPublicId,
    required this.role,
    required this.subjectPublicId,
    required this.token,
    this.isGeneric = false,
    this.subjectName = '',
    this.userType = 'ADMIN',
  });

  factory AuthenticatedSession.fromJson(Map<String, dynamic> json) => AuthenticatedSession(
    tenantPublicId: json['tenantPublicId'] as String,
    role: json['role'] as String,
    subjectPublicId: json['subjectPublicId'] as String,
    token: json['token'] as String,
    isGeneric: json['isGeneric'] as bool? ?? false,
    subjectName: json['subjectName'] as String? ?? '',
    userType: json['userType'] as String? ?? 'ADMIN',
  );
}

// ── Tenant ────────────────────────────────────────────────────────────────────

class TenantSummary {
  final String tenantPublicId;
  final String hospitalName;
  final String city;
  final String specialty;
  final String themeKey;
  final String? distance;

  const TenantSummary({
    required this.tenantPublicId,
    required this.hospitalName,
    required this.city,
    required this.specialty,
    required this.themeKey,
    this.distance,
  });

  factory TenantSummary.fromJson(Map<String, dynamic> json) => TenantSummary(
    tenantPublicId: json['tenantPublicId'] as String,
    hospitalName: json['hospitalName'] as String,
    city: json['city'] as String? ?? 'Unknown city',
    specialty: json['specialty'] as String? ?? 'General medicine',
    themeKey: json['themeKey'] as String? ?? 'premium',
    distance: json['distance'] as String?,
  );
}

class ReferenceLookups {
  final List<String> specializations;
  final List<String> cities;

  const ReferenceLookups({required this.specializations, required this.cities});

  factory ReferenceLookups.fromJson(Map<String, dynamic> json) => ReferenceLookups(
    specializations: List<String>.from(json['specializations'] as List? ?? []),
    cities: List<String>.from(json['cities'] as List? ?? []),
  );
}

// ── Doctor ────────────────────────────────────────────────────────────────────

class DoctorSummary {
  final String doctorPublicId;
  final String name;
  final String specialty;
  final String availability;
  final String fee;
  final String? experience;
  final String? imageUrl;
  final String? rating;
  final String bookingMode;
  final int? experienceYears;
  final String? qualification;

  const DoctorSummary({
    required this.doctorPublicId,
    required this.name,
    required this.specialty,
    required this.availability,
    required this.fee,
    this.experience,
    this.imageUrl,
    this.rating,
    this.bookingMode = 'BOTH',
    this.experienceYears,
    this.qualification,
  });

  factory DoctorSummary.fromJson(Map<String, dynamic> json) => DoctorSummary(
    doctorPublicId: json['doctorPublicId'] as String,
    name: json['name'] as String? ?? '',
    specialty: json['specialty'] as String? ?? '',
    availability: json['availability'] as String? ?? '',
    fee: json['fee'] as String? ?? '',
    experience: json['experience'] as String?,
    imageUrl: json['imageUrl'] as String?,
    rating: json['rating'] as String?,
    bookingMode: json['bookingMode'] as String? ?? 'BOTH',
    experienceYears: json['experienceYears'] as int?,
    qualification: json['qualification'] as String?,
  );
}

class DoctorRecord {
  final String doctorPublicId;
  final String tenantPublicId;
  final String fullName;
  final String specialty;
  final String availability;
  final String fee;
  final bool active;
  final int? age;
  final String? address;
  final String? aboutMe;
  final String? experience;
  final String? imageUrl;
  final String? mobileNumber;
  final String? email;
  final List<String>? qualifications;
  final String? availableFrom;
  final bool? readyToLookPatients;
  final String bookingMode;
  final int? experienceYears;
  final String? qualification;

  const DoctorRecord({
    required this.doctorPublicId,
    required this.tenantPublicId,
    required this.fullName,
    required this.specialty,
    required this.availability,
    required this.fee,
    required this.active,
    this.age,
    this.address,
    this.aboutMe,
    this.experience,
    this.imageUrl,
    this.mobileNumber,
    this.email,
    this.qualifications,
    this.availableFrom,
    this.readyToLookPatients,
    this.bookingMode = 'BOTH',
    this.experienceYears,
    this.qualification,
  });

  factory DoctorRecord.fromJson(Map<String, dynamic> json) => DoctorRecord(
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    specialty: json['specialty'] as String? ?? '',
    availability: json['availability'] as String? ?? '',
    fee: json['fee'] as String? ?? '',
    active: json['active'] as bool? ?? true,
    age: json['age'] as int?,
    address: json['address'] as String?,
    aboutMe: json['aboutMe'] as String?,
    experience: json['experience'] as String?,
    imageUrl: json['imageUrl'] as String?,
    mobileNumber: json['mobileNumber'] as String?,
    email: json['email'] as String?,
    qualifications: json['qualifications'] != null ? List<String>.from(json['qualifications'] as List) : null,
    availableFrom: json['availableFrom'] as String?,
    readyToLookPatients: json['readyToLookPatients'] as bool?,
    bookingMode: json['bookingMode'] as String? ?? 'BOTH',
    experienceYears: json['experienceYears'] as int?,
    qualification: json['qualification'] as String?,
  );
}

class DoctorUpsertRequest {
  final String fullName;
  final String specialty;
  final String availability;
  final String fee;
  final bool active;
  final int? age;
  final String? address;
  final String? aboutMe;
  final String? experience;
  final String? mobileNumber;
  final String? email;
  final String bookingMode;
  final int? experienceYears;
  final String? qualification;

  const DoctorUpsertRequest({
    required this.fullName,
    required this.specialty,
    required this.availability,
    required this.fee,
    required this.active,
    this.age,
    this.address,
    this.aboutMe,
    this.experience,
    this.mobileNumber,
    this.email,
    this.bookingMode = 'BOTH',
    this.experienceYears,
    this.qualification,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'specialty': specialty,
    'availability': availability,
    'fee': fee,
    'active': active,
    if (age != null) 'age': age,
    if (address != null) 'address': address,
    if (aboutMe != null) 'aboutMe': aboutMe,
    if (experience != null) 'experience': experience,
    if (mobileNumber != null) 'mobileNumber': mobileNumber,
    if (email != null) 'email': email,
    'bookingMode': bookingMode,
    if (experienceYears != null) 'experienceYears': experienceYears,
    if (qualification != null) 'qualification': qualification,
  };
}

class DoctorDashboardView {
  final String doctorPublicId;
  final String tenantPublicId;
  final int totalAppointments;
  final int pendingNotes;
  final String nextPatientPublicId;
  final String nextPatientName;
  final List<AppointmentRecord>? patientQueue;

  const DoctorDashboardView({
    required this.doctorPublicId,
    required this.tenantPublicId,
    required this.totalAppointments,
    required this.pendingNotes,
    required this.nextPatientPublicId,
    required this.nextPatientName,
    this.patientQueue,
  });

  factory DoctorDashboardView.fromJson(Map<String, dynamic> json) => DoctorDashboardView(
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    totalAppointments: json['totalAppointments'] as int? ?? 0,
    pendingNotes: json['pendingNotes'] as int? ?? 0,
    nextPatientPublicId: json['nextPatientPublicId'] as String? ?? '',
    nextPatientName: json['nextPatientName'] as String? ?? '',
    patientQueue: json['patientQueue'] != null
        ? (json['patientQueue'] as List).map((e) => AppointmentRecord.fromJson(e as Map<String, dynamic>)).toList()
        : null,
  );
}

class MedicineView {
  final String name;
  final String strength;
  final String frequency;
  final String duration;
  final String? instructions;

  const MedicineView({
    required this.name,
    required this.strength,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  factory MedicineView.fromJson(Map<String, dynamic> json) => MedicineView(
    name: (json['medicineName'] ?? json['name']) as String? ?? '',
    strength: json['strength'] as String? ?? '',
    frequency: json['frequency'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
    instructions: json['instructions'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'medicineName': name,
    'strength': strength,
    'frequency': frequency,
    'duration': duration,
    if (instructions != null && instructions!.isNotEmpty) 'instructions': instructions,
  };
}

class AttachmentUploadRequest {
  final String fileName;
  final String mimeType;
  final String dataBase64;

  const AttachmentUploadRequest({
    required this.fileName,
    required this.mimeType,
    required this.dataBase64,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'mimeType': mimeType,
    'dataBase64': dataBase64,
  };
}

class AttachmentView {
  final String attachmentPublicId;
  final String fileName;
  final String mimeType;
  final String dataBase64;
  final String? uploadedBy;

  const AttachmentView({
    required this.attachmentPublicId,
    required this.fileName,
    required this.mimeType,
    required this.dataBase64,
    this.uploadedBy,
  });

  factory AttachmentView.fromJson(Map<String, dynamic> json) => AttachmentView(
    attachmentPublicId: json['attachmentPublicId'] as String? ?? '',
    fileName: json['fileName'] as String? ?? '',
    mimeType: json['mimeType'] as String? ?? '',
    dataBase64: json['dataBase64'] as String? ?? '',
    uploadedBy: json['uploadedBy'] as String?,
  );
}

class DoctorQueueFacetView {
  final String appointmentPublicId;
  final String patientPublicId;
  final String patientName;
  final String slot;
  final String status;
  final bool followUp;
  final String? symptoms;
  final String? diagnosis;
  final List<MedicineView> medicines;
  final String? rxNotes;
  final String? vitals;
  final List<AttachmentView> attachments;
  final String bookingType;
  final int? tokenNumber;
  final String? tokenSession;
  final String bookingSource;

  const DoctorQueueFacetView({
    required this.appointmentPublicId,
    required this.patientPublicId,
    required this.patientName,
    required this.slot,
    required this.status,
    required this.followUp,
    this.symptoms,
    this.diagnosis,
    required this.medicines,
    this.rxNotes,
    this.vitals,
    this.attachments = const [],
    this.bookingType = 'SLOT',
    this.tokenNumber,
    this.tokenSession,
    this.bookingSource = 'PATIENT_APP',
  });

  bool get isQrBooking => bookingSource == 'QR_CODE';

  factory DoctorQueueFacetView.fromJson(Map<String, dynamic> json) => DoctorQueueFacetView(
    appointmentPublicId: json['appointmentPublicId'] as String? ?? '',
    patientPublicId: json['patientPublicId'] as String? ?? '',
    patientName: json['patientName'] as String? ?? '',
    slot: json['slot'] as String? ?? '',
    status: json['status'] as String? ?? '',
    followUp: json['followUp'] as bool? ?? false,
    symptoms: json['symptoms'] as String?,
    diagnosis: json['diagnosis'] as String?,
    medicines: json['medicines'] != null
        ? (json['medicines'] as List).map((e) => MedicineView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    rxNotes: json['rxNotes'] as String?,
    vitals: json['vitals'] as String?,
    attachments: json['attachments'] != null
        ? (json['attachments'] as List).map((e) => AttachmentView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    bookingType: json['bookingType'] as String? ?? 'SLOT',
    tokenNumber: json['tokenNumber'] as int?,
    tokenSession: json['tokenSession'] as String?,
    bookingSource: json['bookingSource'] as String? ?? 'PATIENT_APP',
  );
}

class DoctorQueueDayView {
  final String tenantPublicId;
  final String doctorPublicId;
  final String date;
  final int totalAppointments;
  final int pendingNotes;
  final int avgConsultMinutes;
  final List<DoctorQueueFacetView> facets;

  const DoctorQueueDayView({
    required this.tenantPublicId,
    required this.doctorPublicId,
    required this.date,
    required this.totalAppointments,
    required this.pendingNotes,
    required this.avgConsultMinutes,
    required this.facets,
  });

  factory DoctorQueueDayView.fromJson(Map<String, dynamic> json) => DoctorQueueDayView(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    date: json['date'] as String? ?? '',
    totalAppointments: json['totalAppointments'] as int? ?? 0,
    pendingNotes: json['pendingNotes'] as int? ?? 0,
    avgConsultMinutes: json['avgConsultMinutes'] as int? ?? 0,
    facets: json['facets'] != null
        ? (json['facets'] as List).map((e) => DoctorQueueFacetView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
  );
}

class DoctorPatientView {
  final String patientPublicId;
  final String fullName;
  final String mobileNumber;
  final String status;
  final String? lastAppointmentSlot;

  const DoctorPatientView({
    required this.patientPublicId,
    required this.fullName,
    required this.mobileNumber,
    required this.status,
    this.lastAppointmentSlot,
  });

  factory DoctorPatientView.fromJson(Map<String, dynamic> json) => DoctorPatientView(
    patientPublicId: json['patientPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    mobileNumber: json['mobileNumber'] as String? ?? '',
    status: json['status'] as String? ?? '',
    lastAppointmentSlot: json['lastAppointmentSlot'] as String?,
  );
}

// ── Patient ───────────────────────────────────────────────────────────────────

class PatientRecord {
  final String patientPublicId;
  final String tenantPublicId;
  final String fullName;
  final String mobileNumber;
  final String status;
  final String? email;
  final String? gender;
  final int? age;
  final String? address;

  const PatientRecord({
    required this.patientPublicId,
    required this.tenantPublicId,
    required this.fullName,
    required this.mobileNumber,
    required this.status,
    this.email,
    this.gender,
    this.age,
    this.address,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
    patientPublicId: json['patientPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    mobileNumber: json['mobileNumber'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    email: json['email'] as String?,
    gender: json['gender'] as String?,
    age: json['age'] as int?,
    address: json['address'] as String?,
  );
}

class PatientSummary {
  final String patientPublicId;
  final String fullName;
  final String mobileNumber;
  final String? gender;
  final int? age;
  final String? lastAppointment;

  const PatientSummary({
    required this.patientPublicId,
    required this.fullName,
    required this.mobileNumber,
    this.gender,
    this.age,
    this.lastAppointment,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) => PatientSummary(
    patientPublicId: json['patientPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    mobileNumber: json['mobileNumber'] as String? ?? '',
    gender: json['gender'] as String?,
    age: json['age'] as int?,
    lastAppointment: json['lastAppointment'] as String?,
  );
}

class PatientUpsertRequest {
  final String fullName;
  final String mobileNumber;
  final String status;
  final String? email;
  final String? gender;
  final int? age;
  final String? address;

  const PatientUpsertRequest({
    required this.fullName,
    required this.mobileNumber,
    required this.status,
    this.email,
    this.gender,
    this.age,
    this.address,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'mobileNumber': mobileNumber,
    'status': status,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (gender != null) 'gender': gender,
    if (age != null) 'age': age,
    if (address != null && address!.isNotEmpty) 'address': address,
  };
}

// ── Appointment ───────────────────────────────────────────────────────────────

class AppointmentView {
  final String appointmentPublicId;
  final String doctorPublicId;
  final String doctorName;
  final String slot;
  final String status;
  final String? note;
  final String bookingType;
  final int? tokenNumber;
  final String? tokenSession;

  const AppointmentView({
    required this.appointmentPublicId,
    required this.doctorPublicId,
    required this.doctorName,
    required this.slot,
    required this.status,
    this.note,
    this.bookingType = 'SLOT',
    this.tokenNumber,
    this.tokenSession,
  });

  factory AppointmentView.fromJson(Map<String, dynamic> json) => AppointmentView(
    appointmentPublicId: json['appointmentPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    doctorName: json['doctorName'] as String? ?? '',
    slot: json['slot'] as String? ?? '',
    status: json['status'] as String? ?? '',
    note: json['note'] as String?,
    bookingType: json['bookingType'] as String? ?? 'SLOT',
    tokenNumber: json['tokenNumber'] as int?,
    tokenSession: json['tokenSession'] as String?,
  );
}

class AppointmentRecord {
  final String appointmentPublicId;
  final String patientPublicId;
  final String doctorPublicId;
  final String slot;
  final String status;
  final String? note;
  final String bookingType;
  final int? tokenNumber;
  final String? tokenSession;

  const AppointmentRecord({
    required this.appointmentPublicId,
    required this.patientPublicId,
    required this.doctorPublicId,
    required this.slot,
    required this.status,
    this.note,
    this.bookingType = 'SLOT',
    this.tokenNumber,
    this.tokenSession,
  });

  factory AppointmentRecord.fromJson(Map<String, dynamic> json) => AppointmentRecord(
    appointmentPublicId: json['appointmentPublicId'] as String? ?? '',
    patientPublicId: json['patientPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    slot: json['slot'] as String? ?? '',
    status: json['status'] as String? ?? '',
    note: json['note'] as String?,
    bookingType: json['bookingType'] as String? ?? 'SLOT',
    tokenNumber: json['tokenNumber'] as int?,
    tokenSession: json['tokenSession'] as String?,
  );
}

class AppointmentBookingRequest {
  final String tenantPublicId;
  final String patientPublicId;
  final String patientName;
  final String gender;
  final int age;
  final String mobileNumber;
  final String address;
  final String specialty;
  final String doctorPublicId;
  final String slot;
  final String bookingType;
  final String? tokenSession;
  final String? note;
  final String? vitals;
  final List<AttachmentUploadRequest>? attachments;
  final String? bookingSource;

  const AppointmentBookingRequest({
    required this.tenantPublicId,
    required this.patientPublicId,
    required this.patientName,
    required this.gender,
    required this.age,
    required this.mobileNumber,
    required this.address,
    required this.specialty,
    required this.doctorPublicId,
    required this.slot,
    this.bookingType = 'SLOT',
    this.tokenSession,
    this.note,
    this.vitals,
    this.attachments,
    this.bookingSource,
  });

  Map<String, dynamic> toJson() => {
    'tenantPublicId': tenantPublicId,
    'patientPublicId': patientPublicId,
    'patientName': patientName,
    'gender': gender,
    'age': age,
    'mobileNumber': mobileNumber,
    'address': address,
    'specialty': specialty,
    'doctorPublicId': doctorPublicId,
    'slot': slot,
    'bookingType': bookingType,
    if (tokenSession != null) 'tokenSession': tokenSession,
    if (note != null) 'note': note,
    if (vitals != null && vitals!.isNotEmpty) 'vitals': vitals,
    if (attachments != null && attachments!.isNotEmpty)
      'attachments': attachments!.map((a) => a.toJson()).toList(),
    if (bookingSource != null) 'bookingSource': bookingSource,
  };
}

class TokenPreviewView {
  final String doctorPublicId;
  final String date;
  final String session;
  final int nextTokenNumber;

  const TokenPreviewView({
    required this.doctorPublicId,
    required this.date,
    required this.session,
    required this.nextTokenNumber,
  });

  factory TokenPreviewView.fromJson(Map<String, dynamic> json) => TokenPreviewView(
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    date: json['date'] as String? ?? '',
    session: json['session'] as String? ?? '',
    nextTokenNumber: json['nextTokenNumber'] as int? ?? 1,
  );
}

class StaffBookingStat {
  final String staffId;
  final String staffName;
  final String? mobileNumber;
  final int todayCount;
  final int weekCount;
  final int monthCount;
  final int yearCount;

  const StaffBookingStat({
    required this.staffId,
    required this.staffName,
    this.mobileNumber,
    required this.todayCount,
    required this.weekCount,
    required this.monthCount,
    required this.yearCount,
  });

  factory StaffBookingStat.fromJson(Map<String, dynamic> json) => StaffBookingStat(
    staffId: json['staffId'] as String? ?? '',
    staffName: json['staffName'] as String? ?? '',
    mobileNumber: json['mobileNumber'] as String?,
    todayCount: json['todayCount'] as int? ?? 0,
    weekCount: json['weekCount'] as int? ?? 0,
    monthCount: json['monthCount'] as int? ?? 0,
    yearCount: json['yearCount'] as int? ?? 0,
  );
}

class BookingSourceCount {
  final String source; // PATIENT_APP | QR_CODE | IP_STAFF
  final String label;
  final int today;
  final int week;
  final int month;
  final int year;

  const BookingSourceCount({
    required this.source,
    required this.label,
    required this.today,
    required this.week,
    required this.month,
    required this.year,
  });

  factory BookingSourceCount.fromJson(Map<String, dynamic> json) => BookingSourceCount(
    source: json['source'] as String? ?? '',
    label: json['label'] as String? ?? '',
    today: json['today'] as int? ?? 0,
    week: json['week'] as int? ?? 0,
    month: json['month'] as int? ?? 0,
    year: json['year'] as int? ?? 0,
  );
}

class BookingChannelStats {
  final String tenantPublicId;
  final List<BookingSourceCount> sources;
  final int qrPendingRequests;

  const BookingChannelStats({
    required this.tenantPublicId,
    required this.sources,
    required this.qrPendingRequests,
  });

  factory BookingChannelStats.fromJson(Map<String, dynamic> json) => BookingChannelStats(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    sources: json['sources'] != null
        ? (json['sources'] as List).map((e) => BookingSourceCount.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    qrPendingRequests: json['qrPendingRequests'] as int? ?? 0,
  );
}

class BookingSetupView {
  final String tenantPublicId;
  final int slotIntervalMinutes;
  final List<String> specialties;
  final List<String> availableDates;
  final List<String> morningSlots;
  final List<String> eveningSlots;

  const BookingSetupView({
    required this.tenantPublicId,
    required this.slotIntervalMinutes,
    required this.specialties,
    required this.availableDates,
    required this.morningSlots,
    required this.eveningSlots,
  });

  factory BookingSetupView.fromJson(Map<String, dynamic> json) => BookingSetupView(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    slotIntervalMinutes: json['slotIntervalMinutes'] as int? ?? 15,
    specialties: List<String>.from(json['specialties'] as List? ?? []),
    availableDates: List<String>.from(json['availableDates'] as List? ?? []),
    morningSlots: List<String>.from(json['morningSlots'] as List? ?? []),
    eveningSlots: List<String>.from(json['eveningSlots'] as List? ?? []),
  );
}

// ── Slot blocking & availability ────────────────────────────────────────────

class SlotBlockView {
  final String blockPublicId;
  final String doctorPublicId;
  final String date;
  final String startTime;
  final String endTime;
  final String reason;

  const SlotBlockView({
    required this.blockPublicId,
    required this.doctorPublicId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.reason,
  });

  factory SlotBlockView.fromJson(Map<String, dynamic> json) => SlotBlockView(
    blockPublicId: json['blockPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    date: json['date'] as String? ?? '',
    startTime: json['startTime'] as String? ?? '',
    endTime: json['endTime'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
  );
}

class SlotStatusView {
  final String doctorPublicId;
  final String date;
  final List<String> bookedSlots;
  final List<String> blockedSlots;
  final bool doctorOnLeave;

  const SlotStatusView({
    required this.doctorPublicId,
    required this.date,
    required this.bookedSlots,
    required this.blockedSlots,
    required this.doctorOnLeave,
  });

  factory SlotStatusView.fromJson(Map<String, dynamic> json) => SlotStatusView(
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    date: json['date'] as String? ?? '',
    bookedSlots: List<String>.from(json['bookedSlots'] as List? ?? []),
    blockedSlots: List<String>.from(json['blockedSlots'] as List? ?? []),
    doctorOnLeave: json['doctorOnLeave'] as bool? ?? false,
  );
}

class DoctorAvailabilityView {
  final String doctorPublicId;
  final String fullName;
  final String specialty;
  final String date;
  final bool onLeave;
  final List<SlotBlockView> blocks;
  final String status; // AVAILABLE | ON_LEAVE | PARTIALLY_AVAILABLE

  const DoctorAvailabilityView({
    required this.doctorPublicId,
    required this.fullName,
    required this.specialty,
    required this.date,
    required this.onLeave,
    required this.blocks,
    required this.status,
  });

  factory DoctorAvailabilityView.fromJson(Map<String, dynamic> json) => DoctorAvailabilityView(
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    specialty: json['specialty'] as String? ?? '',
    date: json['date'] as String? ?? '',
    onLeave: json['onLeave'] as bool? ?? false,
    blocks: json['blocks'] != null
        ? (json['blocks'] as List).map((e) => SlotBlockView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    status: json['status'] as String? ?? 'AVAILABLE',
  );
}

class AppointmentCancelRequest {
  final String? reason;
  const AppointmentCancelRequest({this.reason});
  Map<String, dynamic> toJson() => {if (reason != null) 'reason': reason};
}

class AppointmentRescheduleRequest {
  final String newSlot;
  const AppointmentRescheduleRequest({required this.newSlot});
  Map<String, dynamic> toJson() => {'newSlot': newSlot};
}

class AppointmentActionResult {
  final String appointmentPublicId;
  final String status;
  final String message;

  const AppointmentActionResult({
    required this.appointmentPublicId,
    required this.status,
    required this.message,
  });

  factory AppointmentActionResult.fromJson(Map<String, dynamic> json) => AppointmentActionResult(
    appointmentPublicId: json['appointmentPublicId'] as String? ?? '',
    status: json['status'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );
}

// ── Prescription ──────────────────────────────────────────────────────────────

class PrescriptionDetailView {
  final String prescriptionPublicId;
  final String doctorPublicId;
  final String doctorName;
  final String? doctorSpecialty;
  final String? patientPublicId;
  final String? patientName;
  final String issuedOn;
  final String? validUntil;
  final List<MedicineView> medicines;
  final String? notes;
  final String? fileUrl;
  final String status;

  const PrescriptionDetailView({
    required this.prescriptionPublicId,
    required this.doctorPublicId,
    required this.doctorName,
    this.doctorSpecialty,
    this.patientPublicId,
    this.patientName,
    required this.issuedOn,
    this.validUntil,
    required this.medicines,
    this.notes,
    this.fileUrl,
    required this.status,
  });

  factory PrescriptionDetailView.fromJson(Map<String, dynamic> json) => PrescriptionDetailView(
    prescriptionPublicId: json['prescriptionPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    doctorName: json['doctorName'] as String? ?? '',
    doctorSpecialty: json['doctorSpecialty'] as String?,
    patientPublicId: json['patientPublicId'] as String?,
    patientName: json['patientName'] as String?,
    issuedOn: json['issuedOn'] as String? ?? '',
    validUntil: json['validUntil'] as String?,
    medicines: json['medicines'] != null
        ? (json['medicines'] as List).map((e) => MedicineView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    notes: json['notes'] as String?,
    fileUrl: json['fileUrl'] as String?,
    status: json['status'] as String? ?? 'active',
  );
}

class PrescriptionCollectionView {
  final String tenantPublicId;
  final String patientPublicId;
  final List<PrescriptionDetailView> prescriptions;

  const PrescriptionCollectionView({
    required this.tenantPublicId,
    required this.patientPublicId,
    required this.prescriptions,
  });

  factory PrescriptionCollectionView.fromJson(Map<String, dynamic> json) => PrescriptionCollectionView(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    patientPublicId: json['patientPublicId'] as String? ?? '',
    prescriptions: json['prescriptions'] != null
        ? (json['prescriptions'] as List).map((e) => PrescriptionDetailView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
  );
}

class PrescriptionUploadRequest {
  final String patientPublicId;
  final String doctorPublicId;
  final String doctorName;
  final String? appointmentPublicId;
  final List<MedicineView> medicines;
  final String? notes;

  const PrescriptionUploadRequest({
    required this.patientPublicId,
    required this.doctorPublicId,
    required this.doctorName,
    this.appointmentPublicId,
    required this.medicines,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'patientPublicId': patientPublicId,
    'doctorPublicId': doctorPublicId,
    'doctorName': doctorName,
    if (appointmentPublicId != null) 'appointmentPublicId': appointmentPublicId,
    'medicines': medicines.map((m) => m.toJson()).toList(),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}

class PatientHomeView {
  final String patientPublicId;
  final String tenantPublicId;
  final List<AppointmentView> appointments;
  final List<PrescriptionDetailView> prescriptions;

  const PatientHomeView({
    required this.patientPublicId,
    required this.tenantPublicId,
    required this.appointments,
    required this.prescriptions,
  });

  factory PatientHomeView.fromJson(Map<String, dynamic> json) => PatientHomeView(
    patientPublicId: json['patientPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    appointments: json['appointments'] != null
        ? (json['appointments'] as List).map((e) => AppointmentView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    prescriptions: json['prescriptions'] != null
        ? (json['prescriptions'] as List).map((e) => PrescriptionDetailView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
  );
}

class MedicalHistoryView {
  final String patientPublicId;
  final String tenantPublicId;
  final List<AppointmentView> appointments;
  final List<PrescriptionDetailView> prescriptions;
  final bool followUpRequired;
  final String? lastCheckup;

  const MedicalHistoryView({
    required this.patientPublicId,
    required this.tenantPublicId,
    required this.appointments,
    required this.prescriptions,
    required this.followUpRequired,
    this.lastCheckup,
  });

  factory MedicalHistoryView.fromJson(Map<String, dynamic> json) => MedicalHistoryView(
    patientPublicId: json['patientPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    appointments: json['appointments'] != null
        ? (json['appointments'] as List).map((e) => AppointmentView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    prescriptions: json['prescriptions'] != null
        ? (json['prescriptions'] as List).map((e) => PrescriptionDetailView.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    followUpRequired: json['followUpRequired'] as bool? ?? false,
    lastCheckup: json['lastCheckup'] as String?,
  );
}

// ── Admin ─────────────────────────────────────────────────────────────────────

class AdminOverviewMetric {
  final String label;
  final String value;
  final String trend;

  const AdminOverviewMetric({
    required this.label,
    required this.value,
    required this.trend,
  });

  factory AdminOverviewMetric.fromJson(Map<String, dynamic> json) => AdminOverviewMetric(
    label: json['label'] as String? ?? '',
    value: json['value'] as String? ?? '0',
    trend: json['trend'] as String? ?? '+0',
  );
}

class AdminOverview {
  final String tenantPublicId;
  final List<AdminOverviewMetric> metrics;

  const AdminOverview({required this.tenantPublicId, required this.metrics});

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    metrics: json['metrics'] != null
        ? (json['metrics'] as List).map((e) => AdminOverviewMetric.fromJson(e as Map<String, dynamic>)).toList()
        : [],
  );
}

class AdminUserRecord {
  final String adminPublicId;
  final String tenantPublicId;
  final String fullName;
  final String? email;
  final String? mobileNumber;
  final bool active;
  final String? createdAt;
  final String userType;

  const AdminUserRecord({
    required this.adminPublicId,
    required this.tenantPublicId,
    required this.fullName,
    this.email,
    this.mobileNumber,
    required this.active,
    this.createdAt,
    this.userType = 'ADMIN',
  });

  bool get isStaff => userType == 'STAFF';

  factory AdminUserRecord.fromJson(Map<String, dynamic> json) => AdminUserRecord(
    adminPublicId: json['adminPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
    email: json['email'] as String?,
    mobileNumber: json['mobileNumber'] as String?,
    active: json['active'] as bool? ?? true,
    createdAt: json['createdAt'] as String?,
    userType: json['userType'] as String? ?? 'ADMIN',
  );
}

class AdminUserUpsertRequest {
  final String fullName;
  final String? email;
  final String? mobileNumber;
  final bool? active;
  final String? userType;

  const AdminUserUpsertRequest({
    required this.fullName,
    this.email,
    this.mobileNumber,
    this.active,
    this.userType,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (mobileNumber != null && mobileNumber!.isNotEmpty) 'mobileNumber': mobileNumber,
    if (active != null) 'active': active,
    if (userType != null) 'userType': userType,
  };
}

// ── Platform Admin ────────────────────────────────────────────────────────────

class PlatformAdminOverview {
  final int activeTenants;
  final int onboardingRequests;
  final int approvedOnboardings;
  final int platformAdmins;

  const PlatformAdminOverview({
    required this.activeTenants,
    required this.onboardingRequests,
    required this.approvedOnboardings,
    required this.platformAdmins,
  });

  factory PlatformAdminOverview.fromJson(Map<String, dynamic> json) => PlatformAdminOverview(
    activeTenants: json['activeTenants'] as int? ?? 0,
    onboardingRequests: json['onboardingRequests'] as int? ?? 0,
    approvedOnboardings: json['approvedOnboardings'] as int? ?? 0,
    platformAdmins: json['platformAdmins'] as int? ?? 0,
  );
}

class PlatformTenantRecord {
  final String tenantPublicId;
  final String hospitalName;
  final String city;
  final String pinCode;
  final String themeKey;
  final String schemaName;
  final String status;

  const PlatformTenantRecord({
    required this.tenantPublicId,
    required this.hospitalName,
    this.city = '',
    this.pinCode = '',
    required this.themeKey,
    required this.schemaName,
    required this.status,
  });

  factory PlatformTenantRecord.fromJson(Map<String, dynamic> json) => PlatformTenantRecord(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    hospitalName: json['hospitalName'] as String? ?? '',
    city: json['city'] as String? ?? '',
    pinCode: json['pinCode'] as String? ?? '',
    themeKey: json['themeKey'] as String? ?? 'premium',
    schemaName: json['schemaName'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );
}

class PlatformTenantUpsertRequest {
  final String hospitalName;
  final String? city;
  final String? pinCode;
  final String? themeKey;
  final String? contactName;
  final String? contactMobile;
  final String? contactEmail;
  final String? status;

  const PlatformTenantUpsertRequest({
    required this.hospitalName,
    this.city,
    this.pinCode,
    this.themeKey,
    this.contactName,
    this.contactMobile,
    this.contactEmail,
    this.status,
  });

  Map<String, dynamic> toJson() => {
    'hospitalName': hospitalName,
    if (city != null) 'city': city,
    if (pinCode != null) 'pinCode': pinCode,
    if (themeKey != null) 'themeKey': themeKey,
    if (contactName != null) 'contactName': contactName,
    if (contactMobile != null) 'contactMobile': contactMobile,
    if (contactEmail != null) 'contactEmail': contactEmail,
    if (status != null) 'status': status,
  };
}

class PlatformAdminUserRecord {
  final String platformAdminPublicId;
  final String fullName;
  final String mobileNumber;
  final String? email;
  final bool active;
  final String? createdAt;

  const PlatformAdminUserRecord({
    required this.platformAdminPublicId,
    required this.fullName,
    required this.mobileNumber,
    this.email,
    required this.active,
    this.createdAt,
  });

  factory PlatformAdminUserRecord.fromJson(Map<String, dynamic> json) => PlatformAdminUserRecord(
    platformAdminPublicId: json['platformAdminPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    mobileNumber: json['mobileNumber'] as String? ?? '',
    email: json['email'] as String?,
    active: json['active'] as bool? ?? true,
    createdAt: json['createdAt'] as String?,
  );
}

class PlatformAdminUserUpsertRequest {
  final String fullName;
  final String mobileNumber;
  final String? email;
  final bool? active;

  const PlatformAdminUserUpsertRequest({
    required this.fullName,
    required this.mobileNumber,
    this.email,
    this.active,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'mobileNumber': mobileNumber,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (active != null) 'active': active,
  };
}

class PlatformOnboardingRequestRecord {
  final String requestPublicId;
  final String hospitalName;
  final String city;
  final String facilityType;
  final String status;
  final String contactName;
  final String contactMobile;
  final String contactEmail;
  final String requestedAt;

  const PlatformOnboardingRequestRecord({
    required this.requestPublicId,
    required this.hospitalName,
    required this.city,
    required this.facilityType,
    required this.status,
    required this.contactName,
    required this.contactMobile,
    required this.contactEmail,
    required this.requestedAt,
  });

  factory PlatformOnboardingRequestRecord.fromJson(Map<String, dynamic> json) => PlatformOnboardingRequestRecord(
    requestPublicId: json['requestPublicId'] as String? ?? '',
    hospitalName: json['hospitalName'] as String? ?? '',
    city: json['city'] as String? ?? '',
    facilityType: json['facilityType'] as String? ?? '',
    status: json['status'] as String? ?? '',
    contactName: json['contactName'] as String? ?? '',
    contactMobile: json['contactMobile'] as String? ?? '',
    contactEmail: json['contactEmail'] as String? ?? '',
    requestedAt: json['requestedAt'] as String? ?? '',
  );
}

// ── Onboarding ────────────────────────────────────────────────────────────────

class TenantOnboardingRequest {
  final String hospitalName;
  final String licenseNumber;
  final String state;
  final String city;
  final String address;
  final String country;
  final String contactName;
  final String contactMobile;
  final String contactEmail;
  final String? hospitalLogoFileName;
  final String? supportingDocs;
  final String facilityType;

  const TenantOnboardingRequest({
    required this.hospitalName,
    required this.licenseNumber,
    required this.state,
    required this.city,
    required this.address,
    required this.country,
    required this.contactName,
    required this.contactMobile,
    required this.contactEmail,
    this.hospitalLogoFileName,
    this.supportingDocs,
    required this.facilityType,
  });

  Map<String, dynamic> toJson() => {
    'hospitalName': hospitalName,
    'licenseNumber': licenseNumber,
    'state': state,
    'city': city,
    'address': address,
    'country': country,
    'contactName': contactName,
    'contactMobile': contactMobile,
    'contactEmail': contactEmail,
    if (hospitalLogoFileName != null) 'hospitalLogoFileName': hospitalLogoFileName,
    if (supportingDocs != null) 'supportingDocs': supportingDocs,
    'facilityType': facilityType,
  };
}

class TenantOnboardingAccepted {
  final String requestPublicId;
  final String status;
  final String message;

  const TenantOnboardingAccepted({
    required this.requestPublicId,
    required this.status,
    required this.message,
  });

  factory TenantOnboardingAccepted.fromJson(Map<String, dynamic> json) => TenantOnboardingAccepted(
    requestPublicId: json['requestPublicId'] as String? ?? '',
    status: json['status'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );
}

// ── Leave Requests ────────────────────────────────────────────────────────────

class LeaveRequestRecord {
  final String requestPublicId;
  final String tenantPublicId;
  final String doctorPublicId;
  final String doctorName;
  final String leaveType;
  final String? fromDate;
  final String? toDate;
  final String message;
  final String status; // PENDING | APPROVED | DECLINED | AUTO_APPROVED
  final String? adminResponse;
  final String submittedAt;
  final String? respondedAt;
  final String? startTime; // HH:mm — set only for hourly (partial-day) leave
  final String? endTime;
  final String requesterType; // DOCTOR | STAFF

  const LeaveRequestRecord({
    required this.requestPublicId,
    required this.tenantPublicId,
    required this.doctorPublicId,
    required this.doctorName,
    required this.leaveType,
    this.fromDate,
    this.toDate,
    required this.message,
    required this.status,
    this.adminResponse,
    required this.submittedAt,
    this.respondedAt,
    this.startTime,
    this.endTime,
    this.requesterType = 'DOCTOR',
  });

  bool get isHourly => startTime != null && startTime!.isNotEmpty;
  bool get isStaffRequest => requesterType.toUpperCase() == 'STAFF';

  factory LeaveRequestRecord.fromJson(Map<String, dynamic> json) => LeaveRequestRecord(
    requestPublicId: json['requestPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    doctorName: json['doctorName'] as String? ?? '',
    leaveType: json['leaveType'] as String? ?? '',
    fromDate: json['fromDate'] as String?,
    toDate: json['toDate'] as String?,
    message: json['message'] as String? ?? '',
    status: json['status'] as String? ?? 'PENDING',
    adminResponse: json['adminResponse'] as String?,
    submittedAt: json['submittedAt'] as String? ?? '',
    respondedAt: json['respondedAt'] as String?,
    startTime: json['startTime'] as String?,
    endTime: json['endTime'] as String?,
    requesterType: json['requesterType'] as String? ?? 'DOCTOR',
  );
}

class LeaveRequestCollection {
  final String tenantPublicId;
  final List<LeaveRequestRecord> requests;

  const LeaveRequestCollection({required this.tenantPublicId, required this.requests});

  factory LeaveRequestCollection.fromJson(Map<String, dynamic> json) => LeaveRequestCollection(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    requests: json['requests'] != null
        ? (json['requests'] as List).map((e) => LeaveRequestRecord.fromJson(e as Map<String, dynamic>)).toList()
        : [],
  );
}

// ── In-app Notifications ──────────────────────────────────────────────────────

class AppNotification {
  final String notificationPublicId;
  final String recipientId;
  final String recipientType;
  final String notifType;
  final String title;
  final String body;
  final String? referenceId;
  final bool read;
  final String createdAt;

  const AppNotification({
    required this.notificationPublicId,
    required this.recipientId,
    required this.recipientType,
    required this.notifType,
    required this.title,
    required this.body,
    this.referenceId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    notificationPublicId: json['notificationPublicId'] as String? ?? '',
    recipientId: json['recipientId'] as String? ?? '',
    recipientType: json['recipientType'] as String? ?? '',
    notifType: json['notifType'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    referenceId: json['referenceId'] as String?,
    read: json['read'] as bool? ?? false,
    createdAt: json['createdAt'] as String? ?? '',
  );
}

class NotificationCollection {
  final String tenantPublicId;
  final List<AppNotification> notifications;
  final int unreadCount;

  const NotificationCollection({
    required this.tenantPublicId,
    required this.notifications,
    required this.unreadCount,
  });

  factory NotificationCollection.fromJson(Map<String, dynamic> json) => NotificationCollection(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    notifications: json['notifications'] != null
        ? (json['notifications'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList()
        : [],
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  );
}

// ── QR Appointment Requests (doctor inbox) ──────────────────────────────────────

/// A patient's booking request submitted by scanning a hospital QR code.
/// Surfaces in the respective doctor's "Booking Requests" inbox.
class AppointmentRequest {
  final String requestPublicId;
  final String patientMobile;
  final String patientName;
  final int patientAge;
  final String symptoms;
  final String doctorPublicId;
  final String specialty;
  final String preferredDate;
  final String requestStatus; // 'pending' | 'confirmed'
  final String? assignedSlot;
  final String? notes;
  final String? createdAt;

  const AppointmentRequest({
    required this.requestPublicId,
    required this.patientMobile,
    required this.patientName,
    required this.patientAge,
    required this.symptoms,
    required this.doctorPublicId,
    required this.specialty,
    required this.preferredDate,
    required this.requestStatus,
    this.assignedSlot,
    this.notes,
    this.createdAt,
  });

  bool get isPending => requestStatus.toLowerCase() == 'pending';

  factory AppointmentRequest.fromJson(Map<String, dynamic> json) => AppointmentRequest(
    requestPublicId: json['requestPublicId'] as String? ?? '',
    patientMobile: json['patientMobile'] as String? ?? '',
    patientName: json['patientName'] as String? ?? '',
    patientAge: (json['patientAge'] as num?)?.toInt() ?? 0,
    symptoms: json['symptoms'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    specialty: json['specialty'] as String? ?? '',
    preferredDate: json['preferredDate']?.toString() ?? '',
    requestStatus: json['requestStatus'] as String? ?? 'pending',
    assignedSlot: json['assignedSlot'] as String?,
    notes: json['notes'] as String?,
    createdAt: json['createdAt']?.toString(),
  );
}

class AppointmentRequestCollection {
  final String tenantPublicId;
  final String doctorPublicId;
  final List<AppointmentRequest> requests;

  const AppointmentRequestCollection({
    required this.tenantPublicId,
    required this.doctorPublicId,
    required this.requests,
  });

  int get pendingCount => requests.where((r) => r.isPending).length;

  factory AppointmentRequestCollection.fromJson(Map<String, dynamic> json) => AppointmentRequestCollection(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    requests: json['requests'] != null
        ? (json['requests'] as List).map((e) => AppointmentRequest.fromJson(e as Map<String, dynamic>)).toList()
        : [],
  );
}
