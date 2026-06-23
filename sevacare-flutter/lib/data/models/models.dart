// Complete data model layer — mirrors sevacare-frontend/src/api/types.ts

// ── Auth ──────────────────────────────────────────────────────────────────────

enum UserRole { patient, doctor, admin, platformAdmin }

extension UserRoleX on UserRole {
  String get apiValue => switch (this) {
    UserRole.patient => 'patient',
    UserRole.doctor => 'doctor',
    UserRole.admin => 'admin',
    UserRole.platformAdmin => 'platform_admin',
  };

  String get label => switch (this) {
    UserRole.patient => 'Patient',
    UserRole.doctor => 'Doctor',
    UserRole.admin => 'Hospital Admin',
    UserRole.platformAdmin => 'Platform Admin',
  };

  static UserRole fromApi(String value) => switch (value) {
    'patient' => UserRole.patient,
    'doctor' => UserRole.doctor,
    'admin' => UserRole.admin,
    'platform_admin' => UserRole.platformAdmin,
    _ => UserRole.patient,
  };
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

  const AuthenticatedSession({
    required this.tenantPublicId,
    required this.role,
    required this.subjectPublicId,
    required this.token,
    this.isGeneric = false,
  });

  factory AuthenticatedSession.fromJson(Map<String, dynamic> json) => AuthenticatedSession(
    tenantPublicId: json['tenantPublicId'] as String,
    role: json['role'] as String,
    subjectPublicId: json['subjectPublicId'] as String,
    token: json['token'] as String,
    isGeneric: json['isGeneric'] as bool? ?? false,
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

  const DoctorSummary({
    required this.doctorPublicId,
    required this.name,
    required this.specialty,
    required this.availability,
    required this.fee,
    this.experience,
    this.imageUrl,
    this.rating,
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
    name: json['name'] as String? ?? '',
    strength: json['strength'] as String? ?? '',
    frequency: json['frequency'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
    instructions: json['instructions'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'strength': strength,
    'frequency': frequency,
    'duration': duration,
    if (instructions != null) 'instructions': instructions,
  };
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
  });

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

  const AppointmentView({
    required this.appointmentPublicId,
    required this.doctorPublicId,
    required this.doctorName,
    required this.slot,
    required this.status,
    this.note,
  });

  factory AppointmentView.fromJson(Map<String, dynamic> json) => AppointmentView(
    appointmentPublicId: json['appointmentPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    doctorName: json['doctorName'] as String? ?? '',
    slot: json['slot'] as String? ?? '',
    status: json['status'] as String? ?? '',
    note: json['note'] as String?,
  );
}

class AppointmentRecord {
  final String appointmentPublicId;
  final String patientPublicId;
  final String doctorPublicId;
  final String slot;
  final String status;
  final String? note;

  const AppointmentRecord({
    required this.appointmentPublicId,
    required this.patientPublicId,
    required this.doctorPublicId,
    required this.slot,
    required this.status,
    this.note,
  });

  factory AppointmentRecord.fromJson(Map<String, dynamic> json) => AppointmentRecord(
    appointmentPublicId: json['appointmentPublicId'] as String? ?? '',
    patientPublicId: json['patientPublicId'] as String? ?? '',
    doctorPublicId: json['doctorPublicId'] as String? ?? '',
    slot: json['slot'] as String? ?? '',
    status: json['status'] as String? ?? '',
    note: json['note'] as String?,
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
  };
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
  final String? appointmentPublicId;
  final List<MedicineView> medicines;
  final String? notes;

  const PrescriptionUploadRequest({
    required this.patientPublicId,
    this.appointmentPublicId,
    required this.medicines,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'patientPublicId': patientPublicId,
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

  const AdminUserRecord({
    required this.adminPublicId,
    required this.tenantPublicId,
    required this.fullName,
    this.email,
    this.mobileNumber,
    required this.active,
    this.createdAt,
  });

  factory AdminUserRecord.fromJson(Map<String, dynamic> json) => AdminUserRecord(
    adminPublicId: json['adminPublicId'] as String? ?? '',
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
    email: json['email'] as String?,
    mobileNumber: json['mobileNumber'] as String?,
    active: json['active'] as bool? ?? true,
    createdAt: json['createdAt'] as String?,
  );
}

class AdminUserUpsertRequest {
  final String fullName;
  final String? email;
  final String? mobileNumber;
  final bool? active;

  const AdminUserUpsertRequest({
    required this.fullName,
    this.email,
    this.mobileNumber,
    this.active,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (mobileNumber != null && mobileNumber!.isNotEmpty) 'mobileNumber': mobileNumber,
    if (active != null) 'active': active,
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
  final String themeKey;
  final String schemaName;
  final String status;

  const PlatformTenantRecord({
    required this.tenantPublicId,
    required this.hospitalName,
    required this.themeKey,
    required this.schemaName,
    required this.status,
  });

  factory PlatformTenantRecord.fromJson(Map<String, dynamic> json) => PlatformTenantRecord(
    tenantPublicId: json['tenantPublicId'] as String? ?? '',
    hospitalName: json['hospitalName'] as String? ?? '',
    themeKey: json['themeKey'] as String? ?? 'premium',
    schemaName: json['schemaName'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );
}

class PlatformTenantUpsertRequest {
  final String hospitalName;
  final String? themeKey;
  final String? contactName;
  final String? contactMobile;
  final String? contactEmail;
  final String? status;

  const PlatformTenantUpsertRequest({
    required this.hospitalName,
    this.themeKey,
    this.contactName,
    this.contactMobile,
    this.contactEmail,
    this.status,
  });

  Map<String, dynamic> toJson() => {
    'hospitalName': hospitalName,
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
