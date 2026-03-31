import type {
  AdminOverview,
  AdminUserCollection,
  AdminUserRecord,
  AdminUserUpsertRequest,
  AppointmentActionResult,
  AppointmentBookingRequest,
  AppointmentBookingResult,
  AppointmentCancelRequest,
  AppointmentCollection,
  AppointmentRecord,
  AppointmentRescheduleRequest,
  AppointmentUpsertRequest,
  ApiEnvelope,
  AuthenticatedSession,
  BookingSetupView,
  DoctorCollection,
  DoctorDashboardView,
  DoctorQueueDayView,
  DoctorPatientCollection,
  DoctorPrescriptionCollection,
  DoctorRecord,
  DoctorSummary,
  DoctorUpsertRequest,
  MedicalHistoryView,
  OtpRequest,
  OtpVerifyRequest,
  OnboardingDocumentView,
  PatientCollection,
  PatientHomeView,
  PatientRecord,
  PatientUpsertRequest,
  PlatformAdminOverview,
  PlatformOnboardingCollection,
  PlatformTenantCollection,
  PrescriptionCollectionView,
  PrescriptionDetailView,
  PrescriptionUploadRequest,
  PrescriptionUploadResult,
  ReferenceLookups,
  TenantOnboardingAccepted,
  TenantOnboardingRequest,
  TenantOnboardingUploadFile,
  TenantSummary,
} from './types';

const API_BASE_URL = process.env.EXPO_PUBLIC_API_BASE_URL ?? 'http://localhost:8081/api/v1';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });

  if (!response.ok) {
    throw new Error(`API request failed (${response.status})`);
  }

  const payload = (await response.json()) as ApiEnvelope<T>;
  return payload.data;
}

export const sevacareApi = {
  listTenants: () => request<{ tenants: TenantSummary[] }>('/public/tenants'),
  getLookups: () => request<ReferenceLookups>('/public/lookups'),
  listDoctors: (tenantPublicId: string) => request<{ tenantPublicId: string; doctors: DoctorSummary[] }>(`/public/tenants/${tenantPublicId}/doctors`),
  requestOtp: (body: OtpRequest) => request<{ tenantPublicId: string; role: string; mobileNumber: string; otpHint: string }>('/auth/otp/request', {
    method: 'POST',
    body: JSON.stringify(body),
  }),
  verifyOtp: (body: OtpVerifyRequest) => request<AuthenticatedSession>('/auth/otp/verify', {
    method: 'POST',
    body: JSON.stringify(body),
  }),
  requestTenantOnboarding: (body: TenantOnboardingRequest) => request<TenantOnboardingAccepted>('/public/onboarding/request', {
    method: 'POST',
    body: JSON.stringify(body),
  }),
  requestTenantOnboardingMultipart: async (body: TenantOnboardingRequest, files: TenantOnboardingUploadFile[]) => {
    const formData = new FormData();
    formData.append('payload', JSON.stringify(body));

    for (const selectedFile of files) {
      if (selectedFile.file) {
        formData.append('files', selectedFile.file, selectedFile.name);
      } else {
        formData.append('files', {
          uri: selectedFile.uri,
          name: selectedFile.name,
          type: selectedFile.mimeType ?? 'application/octet-stream',
        } as unknown as Blob);
      }
    }

    const response = await fetch(`${API_BASE_URL}/public/onboarding/request-multipart`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`API request failed (${response.status})`);
    }

    const payload = (await response.json()) as ApiEnvelope<TenantOnboardingAccepted>;
    return payload.data;
  },
  listOnboardingDocuments: (requestPublicId: string) =>
    request<OnboardingDocumentView[]>(`/public/onboarding/request/${requestPublicId}/documents`),
  getOnboardingDocumentDownloadUrl: (requestPublicId: string, documentPublicId: string) =>
    `${API_BASE_URL}/public/onboarding/request/${requestPublicId}/documents/${documentPublicId}/download`,
  getPatientHome: (tenantPublicId: string, patientPublicId: string, token: string) =>
    request<PatientHomeView>(`/patients/${tenantPublicId}/${patientPublicId}/home`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getBookingSetup: (tenantPublicId: string, patientPublicId: string, token: string) =>
    request<BookingSetupView>(`/patients/${tenantPublicId}/${patientPublicId}/booking/setup`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  bookAppointment: (tenantPublicId: string, patientPublicId: string, token: string, body: AppointmentBookingRequest) =>
    request<AppointmentBookingResult>(`/patients/${tenantPublicId}/${patientPublicId}/appointments`, {
      method: 'POST',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  listDoctorRecords: (tenantPublicId: string, token: string) =>
    request<DoctorCollection>(`/doctors/${tenantPublicId}/records`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getDoctorRecord: (tenantPublicId: string, doctorPublicId: string, token: string) =>
    request<DoctorRecord>(`/doctors/${tenantPublicId}/records/${doctorPublicId}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getNextDoctorPublicId: (tenantPublicId: string, token: string) =>
    request<string>(`/doctors/${tenantPublicId}/records/next-public-id`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  createDoctorRecord: (tenantPublicId: string, token: string, body: DoctorUpsertRequest) =>
    request<DoctorRecord>(`/doctors/${tenantPublicId}/records`, {
      method: 'POST',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  upsertDoctorRecord: (tenantPublicId: string, doctorPublicId: string, token: string, body: DoctorUpsertRequest) =>
    request<DoctorRecord>(`/doctors/${tenantPublicId}/records/${doctorPublicId}`, {
      method: 'PUT',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  deleteDoctorRecord: (tenantPublicId: string, doctorPublicId: string, token: string) =>
    request<string>(`/doctors/${tenantPublicId}/records/${doctorPublicId}`, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  listPatientRecords: (tenantPublicId: string, token: string) =>
    request<PatientCollection>(`/patients/${tenantPublicId}/records`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getPatientRecord: (tenantPublicId: string, patientPublicId: string, token: string) =>
    request<PatientRecord>(`/patients/${tenantPublicId}/records/${patientPublicId}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  upsertPatientRecord: (tenantPublicId: string, patientPublicId: string, token: string, body: PatientUpsertRequest) =>
    request<PatientRecord>(`/patients/${tenantPublicId}/records/${patientPublicId}`, {
      method: 'PUT',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  deletePatientRecord: (tenantPublicId: string, patientPublicId: string, token: string) =>
    request<string>(`/patients/${tenantPublicId}/records/${patientPublicId}`, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  listAppointmentRecords: (tenantPublicId: string, token: string) =>
    request<AppointmentCollection>(`/patients/${tenantPublicId}/appointments`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getAppointmentRecord: (tenantPublicId: string, appointmentPublicId: string, token: string) =>
    request<AppointmentRecord>(`/patients/${tenantPublicId}/appointments/${appointmentPublicId}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  upsertAppointmentRecord: (tenantPublicId: string, appointmentPublicId: string, token: string, body: AppointmentUpsertRequest) =>
    request<AppointmentRecord>(`/patients/${tenantPublicId}/appointments/${appointmentPublicId}`, {
      method: 'PUT',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  deleteAppointmentRecord: (tenantPublicId: string, appointmentPublicId: string, token: string) =>
    request<string>(`/patients/${tenantPublicId}/appointments/${appointmentPublicId}`, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getDoctorDashboard: (tenantPublicId: string, doctorPublicId: string, token: string) =>
    request<DoctorDashboardView>(`/doctors/${tenantPublicId}/${doctorPublicId}/dashboard`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getDoctorQueueByDate: (tenantPublicId: string, doctorPublicId: string, date: string, token: string) =>
    request<DoctorQueueDayView>(`/doctors/${tenantPublicId}/${doctorPublicId}/queue?date=${encodeURIComponent(date)}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getPlatformOverview: (token: string) =>
    request<PlatformAdminOverview>('/platform-admin/overview', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }),
  listPlatformTenants: (token: string) =>
    request<PlatformTenantCollection>('/platform-admin/tenants', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }),
  listPlatformOnboardingRequests: (token: string) =>
    request<PlatformOnboardingCollection>('/platform-admin/onboarding-requests', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }),
  getAdminOverview: (tenantPublicId: string, token: string) =>
    request<AdminOverview>(`/admin/${tenantPublicId}/overview`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  listAdminUsers: (tenantPublicId: string, token: string, activeOnly = false) =>
    request<AdminUserCollection>(`/admin/${tenantPublicId}/users${activeOnly ? '?activeOnly=true' : ''}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getAdminUser: (tenantPublicId: string, adminPublicId: string, token: string) =>
    request<AdminUserRecord>(`/admin/${tenantPublicId}/users/${adminPublicId}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getNextAdminPublicId: (tenantPublicId: string, token: string) =>
    request<string>(`/admin/${tenantPublicId}/users/next-public-id`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  createAdminUser: (tenantPublicId: string, token: string, body: AdminUserUpsertRequest) =>
    request<AdminUserRecord>(`/admin/${tenantPublicId}/users`, {
      method: 'POST',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  updateAdminUser: (tenantPublicId: string, adminPublicId: string, token: string, body: AdminUserUpsertRequest) =>
    request<AdminUserRecord>(`/admin/${tenantPublicId}/users/${adminPublicId}`, {
      method: 'PUT',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  deactivateAdminUser: (tenantPublicId: string, adminPublicId: string, token: string) =>
    request<AdminUserRecord>(`/admin/${tenantPublicId}/users/${adminPublicId}/deactivate`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  // Phase 3: Prescription APIs
  getPatientPrescriptions: (tenantPublicId: string, patientPublicId: string, token: string) =>
    request<PrescriptionCollectionView>(`/patients/${tenantPublicId}/${patientPublicId}/prescriptions`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getPrescriptionDetail: (tenantPublicId: string, prescriptionPublicId: string, token: string) =>
    request<PrescriptionDetailView>(`/prescriptions/${tenantPublicId}/${prescriptionPublicId}/detail`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  uploadPrescription: (tenantPublicId: string, doctorPublicId: string, token: string, body: PrescriptionUploadRequest) =>
    request<PrescriptionUploadResult>(`/doctors/${tenantPublicId}/${doctorPublicId}/prescriptions`, {
      method: 'POST',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  downloadPrescription: (tenantPublicId: string, prescriptionPublicId: string, token: string) =>
    `${API_BASE_URL}/prescriptions/${tenantPublicId}/${prescriptionPublicId}/download?token=${token}`,
  getPatientMedicalHistory: (tenantPublicId: string, patientPublicId: string, token: string) =>
    request<MedicalHistoryView>(`/patients/${tenantPublicId}/${patientPublicId}/medical-history`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),

  // Phase 5: Doctor-scoped APIs
  getDoctorPatients: (tenantPublicId: string, doctorPublicId: string, token: string) =>
    request<DoctorPatientCollection>(`/doctors/${tenantPublicId}/${doctorPublicId}/patients`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  getDoctorPrescriptions: (tenantPublicId: string, doctorPublicId: string, token: string) =>
    request<DoctorPrescriptionCollection>(`/doctors/${tenantPublicId}/${doctorPublicId}/prescriptions/list`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),

  // Phase 5: Appointment cancel/reschedule
  cancelAppointment: (tenantPublicId: string, patientPublicId: string, appointmentPublicId: string, token: string, body?: AppointmentCancelRequest) =>
    request<AppointmentActionResult>(`/patients/${tenantPublicId}/${patientPublicId}/appointments/${appointmentPublicId}/cancel`, {
      method: 'PUT',
      body: JSON.stringify(body ?? {}),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  rescheduleAppointment: (tenantPublicId: string, patientPublicId: string, appointmentPublicId: string, token: string, body: AppointmentRescheduleRequest) =>
    request<AppointmentActionResult>(`/patients/${tenantPublicId}/${patientPublicId}/appointments/${appointmentPublicId}/reschedule`, {
      method: 'PUT',
      body: JSON.stringify(body),
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
  deletePatientAppointment: (tenantPublicId: string, patientPublicId: string, appointmentPublicId: string, token: string) =>
    request<AppointmentActionResult>(`/patients/${tenantPublicId}/${patientPublicId}/appointments/${appointmentPublicId}`, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': tenantPublicId,
      },
    }),
};
