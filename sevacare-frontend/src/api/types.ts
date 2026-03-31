export type ApiEnvelope<T> = {
  data: T;
  generatedAt: string;
};

export type TenantSummary = {
  tenantPublicId: string;
  hospitalName: string;
  city: string;
  specialty: string;
  themeKey: 'premium' | 'clinic';
};

export type DoctorSummary = {
  doctorPublicId: string;
  name: string;
  specialty: string;
  availability: string;
  fee: string;
  experience?: string;
  imageUrl?: string;
  rating?: string;
};

export type OtpRequest = {
  tenantPublicId: string;
  role: 'patient' | 'doctor' | 'admin' | 'platform_admin';
  mobileNumber: string;
};

export type OtpVerifyRequest = {
  tenantPublicId: string;
  role: 'patient' | 'doctor' | 'admin' | 'platform_admin';
  mobileNumber: string;
  otp: string;
};

export type AuthenticatedSession = {
  tenantPublicId: string;
  role: 'patient' | 'doctor' | 'admin' | 'platform_admin';
  subjectPublicId: string;
  token: string;
};

export type PlatformAdminOverview = {
  activeTenants: number;
  onboardingRequests: number;
  approvedOnboardings: number;
  platformAdmins: number;
};

export type PlatformTenantRecord = {
  tenantPublicId: string;
  hospitalName: string;
  themeKey: string;
  schemaName: string;
  status: string;
};

export type PlatformTenantCollection = {
  tenants: PlatformTenantRecord[];
};

export type PlatformOnboardingRequestRecord = {
  requestPublicId: string;
  hospitalName: string;
  city: string;
  facilityType: string;
  status: string;
  contactName: string;
  contactMobile: string;
  contactEmail: string;
  requestedAt: string;
};

export type PlatformOnboardingCollection = {
  requests: PlatformOnboardingRequestRecord[];
};

export type AppointmentView = {
  appointmentPublicId: string;
  doctorPublicId: string;
  doctorName: string;
  slot: string;
  status: 'upcoming' | 'past';
  note: string;
};

export type PrescriptionView = {
  prescriptionPublicId: string;
  doctorPublicId: string;
  doctorName: string;
  issuedOn: string;
  lines: string[];
};

export type PatientHomeView = {
  patientPublicId: string;
  tenantPublicId: string;
  appointments: AppointmentView[];
  prescriptions: PrescriptionView[];
};

export type TenantOnboardingRequest = {
  hospitalName: string;
  licenseNumber: string;
  state: string;
  city: string;
  address: string;
  country: string;
  contactName: string;
  contactMobile: string;
  contactEmail: string;
  supportingDocs?: string;
  facilityType: 'hospital' | 'clinic';
};

export type TenantOnboardingUploadFile = {
  uri: string;
  name: string;
  mimeType?: string;
  size?: number;
  file?: Blob;
};

export type OnboardingDocumentView = {
  documentPublicId: string;
  fileName: string;
  contentType: string;
  fileSize: number;
};

export type TenantOnboardingAccepted = {
  requestPublicId: string;
  status: string;
  message: string;
  documents: OnboardingDocumentView[];
};

export type ReferenceLookups = {
  specializations: string[];
  cities: string[];
};

export type BookingSetupView = {
  tenantPublicId: string;
  slotIntervalMinutes: number;
  specialties: string[];
  availableDates: string[];
  morningSlots: string[];
  eveningSlots: string[];
};

export type AppointmentBookingRequest = {
  tenantPublicId: string;
  patientPublicId: string;
  patientName: string;
  gender: 'male' | 'female' | 'other';
  age: number;
  mobileNumber: string;
  address: string;
  specialty: string;
  doctorPublicId: string;
  slot: string;
};

export type AppointmentBookingResult = {
  appointmentPublicId: string;
  tenantPublicId: string;
  doctorPublicId: string;
  patientPublicId: string;
  slot: string;
  status: string;
};

export type DoctorRecord = {
  doctorPublicId: string;
  tenantPublicId: string;
  fullName: string;
  specialty: string;
  availability: string;
  fee: string;
  active: boolean;
  age?: number;
  address?: string;
  aboutMe?: string;
  experience?: string;
  imageUrl?: string;
  mobileNumber?: string;
  email?: string;
  qualifications?: string[];
  availableFrom?: string;
  readyToLookPatients?: boolean;
};

export type DoctorCollection = {
  tenantPublicId: string;
  doctors: DoctorRecord[];
};

export type DoctorUpsertRequest = {
  fullName: string;
  specialty: string;
  availability: string;
  fee: string;
  active: boolean;
  age?: number;
  address?: string;
  aboutMe?: string;
  experience?: string;
  mobileNumber?: string;
  email?: string;
  qualifications?: string[];
  availableFrom?: string;
  readyToLookPatients?: boolean;
};

export type PatientRecord = {
  patientPublicId: string;
  tenantPublicId: string;
  fullName: string;
  mobileNumber: string;
  status: string;
  email?: string;
  gender?: 'male' | 'female' | 'other';
  age?: number;
  address?: string;
};

export type PatientCollection = {
  tenantPublicId: string;
  patients: PatientRecord[];
};

export type PatientUpsertRequest = {
  fullName: string;
  mobileNumber: string;
  status: string;
  email?: string;
  gender?: 'male' | 'female' | 'other';
  age?: number;
  address?: string;
};

export type AppointmentRecord = {
  appointmentPublicId: string;
  patientPublicId: string;
  doctorPublicId: string;
  slot: string;
  status: string;
  note: string;
};

export type AppointmentCollection = {
  tenantPublicId: string;
  appointments: AppointmentRecord[];
};

export type AppointmentUpsertRequest = {
  patientPublicId: string;
  doctorPublicId: string;
  slot: string;
  status: string;
  note: string;
};

export type DoctorDashboardView = {
  doctorPublicId: string;
  tenantPublicId: string;
  totalAppointments: number;
  pendingNotes: number;
  nextPatientPublicId: string;
  nextPatientName: string;
  patientQueue?: AppointmentRecord[];
};

export type DoctorQueueFacetView = {
  appointmentPublicId: string;
  patientPublicId: string;
  patientName: string;
  slot: string;
  status: string;
  followUp: boolean;
  symptoms: string;
  diagnosis: string;
  medicines: MedicineView[];
  rxNotes: string;
};

export type DoctorQueueDayView = {
  tenantPublicId: string;
  doctorPublicId: string;
  date: string;
  totalAppointments: number;
  pendingNotes: number;
  avgConsultMinutes: number;
  facets: DoctorQueueFacetView[];
};

export type AdminOverviewMetric = {
  label: string;
  value: string;
  trend: string;
};

export type AdminOverview = {
  tenantPublicId: string;
  metrics: AdminOverviewMetric[];
};

export type AdminUserRecord = {
  adminPublicId: string;
  tenantPublicId: string;
  fullName: string;
  name?: string;
  email?: string;
  mobileNumber?: string;
  active: boolean;
  createdAt?: string;
};

export type AdminUserCollection = {
  tenantPublicId: string;
  admins: AdminUserRecord[];
};

export type AdminUserUpsertRequest = {
  fullName: string;
  name?: string;
  email?: string;
  mobileNumber?: string;
  active?: boolean;
};

// Phase 2: Profile & Extended Types

export type ProfileImageUpload = {
  file: Blob;
  fileName: string;
  mimeType: string;
};

export type DisablePatientRequest = {
  patientPublicId: string;
  reason: string;
};

export type DisablePatientResult = {
  patientPublicId: string;
  status: string;
};

export type ApiError = {
  status: number;
  message: string;
  path?: string;
  timestamp?: string;
};

// Session/Auth types
export type AuthState = {
  isAuthenticated: boolean;
  token?: string;
  tenantId?: string;
  userId?: string;
  role?: 'patient' | 'doctor' | 'admin' | 'platform_admin';
  error?: string | null;
};

// Phase 3: Prescriptions

export type MedicineView = {
  name: string;
  strength: string;
  frequency: string;
  duration: string;
  instructions?: string;
};

export type PrescriptionDetailView = {
  prescriptionPublicId: string;
  doctorPublicId: string;
  doctorName: string;
  issuedOn: string;
  validUntil?: string;
  medicines: MedicineView[];
  notes?: string;
  fileUrl?: string;
  status: 'active' | 'cancelled' | 'expired';
};

export type PrescriptionCollectionView = {
  tenantPublicId: string;
  patientPublicId: string;
  prescriptions: PrescriptionDetailView[];
};

export type MedicineUploadInput = {
  name: string;
  strength: string;
  frequency: string;
  duration: string;
  instructions?: string;
};

export type PrescriptionUploadRequest = {
  patientPublicId: string;
  appointmentPublicId?: string;
  medicines: MedicineUploadInput[];
  notes?: string;
  file?: Blob;
};

export type PrescriptionUploadResult = {
  prescriptionPublicId: string;
  status: 'issued' | 'pending';
  issuedAt: string;
};

export type MedicalHistoryRecord = {
  recordType: 'allergy' | 'condition' | 'surgery' | 'vaccination' | 'other';
  recordValue: string;
  notes?: string;
  recordDate?: string;
};

export type MedicalHistoryView = {
  patientPublicId: string;
  tenantPublicId: string;
  appointments: AppointmentView[];
  prescriptions: PrescriptionDetailView[];
  medicalRecords: MedicalHistoryRecord[];
  allergies: MedicalHistoryRecord[];
  conditions: MedicalHistoryRecord[];
  lastCheckup?: string;
  followUpRequired: boolean;
};

// Phase 5: Doctor-scoped types

export type DoctorPatientView = {
  patientPublicId: string;
  fullName: string;
  mobileNumber: string;
  status: string;
  lastAppointmentSlot: string;
};

export type DoctorPatientCollection = {
  tenantPublicId: string;
  doctorPublicId: string;
  patients: DoctorPatientView[];
};

export type DoctorPrescriptionCollection = {
  tenantPublicId: string;
  doctorPublicId: string;
  prescriptions: PrescriptionDetailView[];
};

export type AppointmentCancelRequest = {
  reason?: string;
};

export type AppointmentRescheduleRequest = {
  newSlot: string;
};

export type AppointmentActionResult = {
  appointmentPublicId: string;
  status: string;
  message: string;
};
