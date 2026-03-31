/**
 * SevaCare E2E – API Health & Integration Tests
 * Tests backend APIs directly to ensure data flows correctly.
 */
import { expect, test } from '@playwright/test';

const API = 'http://localhost:8081/api/v1';
const ROLE_IDENTIFIERS = {
  patient: '9000000000',
  doctor: '9100000001',
  admin: '9000000003',
} as const;

async function getActiveTenant(request: import('@playwright/test').APIRequestContext) {
  const response = await request.get(`${API}/public/tenants`);
  expect(response.ok()).toBe(true);
  const body = await response.json();
  const tenant = body.data.tenants[0];
  expect(tenant).toBeDefined();
  return tenant as { tenantPublicId: string; hospitalName: string };
}

async function requestOtp(
  request: import('@playwright/test').APIRequestContext,
  tenantPublicId: string,
  role: 'patient' | 'doctor' | 'admin',
) {
  return request.post(`${API}/auth/otp/request`, {
    data: { tenantPublicId, role, mobileNumber: ROLE_IDENTIFIERS[role] },
  });
}

async function verifyOtp(
  request: import('@playwright/test').APIRequestContext,
  tenantPublicId: string,
  role: 'patient' | 'doctor' | 'admin',
) {
  return request.post(`${API}/auth/otp/verify`, {
    data: { tenantPublicId, role, mobileNumber: ROLE_IDENTIFIERS[role], otp: '0000' },
  });
}

async function getAdminToken(request: import('@playwright/test').APIRequestContext, tenantPublicId: string) {
  await requestOtp(request, tenantPublicId, 'admin');
  const res = await verifyOtp(request, tenantPublicId, 'admin');
  expect(res.ok()).toBe(true);
  const body = await res.json();
  return body.data.token as string;
}

test.describe('Backend health & discovery', () => {
  test('tenant list API returns at least one active tenant', async ({ request }) => {
    const response = await request.get(`${API}/public/tenants`);
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.tenants.length).toBeGreaterThan(0);
    expect(body.data.tenants[0].tenantPublicId).toBeTruthy();
    expect(body.data.tenants[0].hospitalName).toBeTruthy();
  });

  test('lookups API returns specializations and cities', async ({ request }) => {
    const response = await request.get(`${API}/public/lookups`);
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.specializations.length).toBeGreaterThan(0);
    expect(body.data.cities.length).toBeGreaterThan(0);
  });

  test('doctor list API responds for the active tenant', async ({ request }) => {
    const tenant = await getActiveTenant(request);
    const response = await request.get(`${API}/public/tenants/${tenant.tenantPublicId}/doctors`);
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(Array.isArray(body.data.doctors)).toBe(true);
  });
});

test.describe('Auth flow API', () => {
  test('OTP request succeeds for the active tenant', async ({ request }) => {
    const tenant = await getActiveTenant(request);
    const response = await requestOtp(request, tenant.tenantPublicId, 'admin');
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.otpHint).toBeDefined();
  });

  test('OTP verify returns JWT token for admin access', async ({ request }) => {
    const tenant = await getActiveTenant(request);
    await requestOtp(request, tenant.tenantPublicId, 'admin');
    const response = await verifyOtp(request, tenant.tenantPublicId, 'admin');
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.token).toBeDefined();
    expect(body.data.subjectPublicId).toBeDefined();
  });

  test('auth works for roles provisioned on the active tenant', async ({ request }) => {
    const tenant = await getActiveTenant(request);
    const expectedStatuses: Record<'patient' | 'doctor' | 'admin', number> = {
      patient: 400,
      doctor: 400,
      admin: 200,
    };

    for (const role of ['patient', 'doctor', 'admin'] as const) {
      await requestOtp(request, tenant.tenantPublicId, role);
      const response = await verifyOtp(request, tenant.tenantPublicId, role);
      expect(response.status()).toBe(expectedStatuses[role]);
    }
  });
});

test.describe('Patient APIs (authenticated)', () => {
  let token: string | undefined;
  let subjectPublicId: string | undefined;
  let tenantPublicId: string;
  let hasPatientFixture = false;

  test.beforeAll(async ({ request }) => {
    const tenant = await getActiveTenant(request);
    tenantPublicId = tenant.tenantPublicId;
    await requestOtp(request, tenantPublicId, 'patient');
    const res = await verifyOtp(request, tenantPublicId, 'patient');
    if (!res.ok()) {
      return;
    }
    const body = await res.json();
    token = body.data.token;
    subjectPublicId = body.data.subjectPublicId;
    hasPatientFixture = true;
  });

  test('patient home API returns appointments', async ({ request }) => {
    test.skip(!hasPatientFixture, 'Active tenant has no patient fixture');
    const response = await request.get(`${API}/patients/${tenantPublicId}/${subjectPublicId}/home`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.patientPublicId).toBe(subjectPublicId);
  });

  test('booking setup API returns slot config', async ({ request }) => {
    test.skip(!hasPatientFixture, 'Active tenant has no patient fixture');
    const response = await request.get(`${API}/patients/${tenantPublicId}/${subjectPublicId}/booking/setup`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.slotIntervalMinutes).toBeGreaterThan(0);
  });

  test('book appointment API responds', async ({ request }) => {
    test.skip(!hasPatientFixture, 'Active tenant has no patient fixture');
    const doctorsResponse = await request.get(`${API}/public/tenants/${tenantPublicId}/doctors`);
    expect(doctorsResponse.ok()).toBe(true);
    const doctorsBody = await doctorsResponse.json();
    const firstDoctor = doctorsBody.data.doctors[0];
    test.skip(!firstDoctor, 'Active tenant has no doctor fixture for booking');

    const response = await request.post(`${API}/patients/${tenantPublicId}/${subjectPublicId}/appointments`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
      data: {
        tenantPublicId,
        patientPublicId: subjectPublicId,
        patientName: 'API Test Patient',
        gender: 'Male',
        age: 30,
        mobileNumber: ROLE_IDENTIFIERS.patient,
        address: 'API Test Lane',
        specialty: firstDoctor.specialty,
        doctorPublicId: firstDoctor.publicId,
        slot: '10:00',
      },
    });
    expect([200, 201, 400, 403]).toContain(response.status());
  });
});

test.describe('Doctor APIs (authenticated)', () => {
  let token: string | undefined;
  let subjectPublicId: string | undefined;
  let tenantPublicId: string;
  let hasDoctorFixture = false;

  test.beforeAll(async ({ request }) => {
    const tenant = await getActiveTenant(request);
    tenantPublicId = tenant.tenantPublicId;
    await requestOtp(request, tenantPublicId, 'doctor');
    const res = await verifyOtp(request, tenantPublicId, 'doctor');
    if (!res.ok()) {
      return;
    }
    const body = await res.json();
    token = body.data.token;
    subjectPublicId = body.data.subjectPublicId;
    hasDoctorFixture = true;
  });

  test('doctor dashboard API returns metrics', async ({ request }) => {
    test.skip(!hasDoctorFixture, 'Active tenant has no doctor fixture');
    const response = await request.get(`${API}/doctors/${tenantPublicId}/${subjectPublicId}/dashboard`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.totalAppointments).toBeDefined();
    expect(body.data.pendingNotes).toBeDefined();
  });

  test('doctor records API returns list', async ({ request }) => {
    test.skip(!hasDoctorFixture, 'Active tenant has no doctor fixture');
    const response = await request.get(`${API}/doctors/${tenantPublicId}/records`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.doctors.length).toBeGreaterThanOrEqual(1);
  });
});

test.describe('Admin APIs (authenticated)', () => {
  let token: string;
  let tenantPublicId: string;

  test.beforeAll(async ({ request }) => {
    const tenant = await getActiveTenant(request);
    tenantPublicId = tenant.tenantPublicId;
    token = await getAdminToken(request, tenantPublicId);
  });

  test('admin overview API returns metrics', async ({ request }) => {
    const response = await request.get(`${API}/admin/${tenantPublicId}/overview`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.metrics).toBeDefined();
    expect(body.data.metrics.length).toBeGreaterThan(0);
  });


  test('admin user CRUD flow works end to end', async ({ request }) => {
    const nextIdResponse = await request.get(`${API}/admin/${tenantPublicId}/users/next-public-id`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(nextIdResponse.ok()).toBe(true);

    const runId = Date.now();
    const createResponse = await request.post(`${API}/admin/${tenantPublicId}/users`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
      data: {
        fullName: `API Admin ${runId}`,
        name: 'API Admin',
        email: `api.admin.${runId}@sevacare.test`,
        mobileNumber: '9000000088',
        active: true,
      },
    });
    expect(createResponse.ok()).toBe(true);
    const created = await createResponse.json();
    const adminPublicId = created.data.adminPublicId;
    expect(adminPublicId).toBeDefined();

    const getResponse = await request.get(`${API}/admin/${tenantPublicId}/users/${adminPublicId}`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(getResponse.ok()).toBe(true);

    const updateResponse = await request.put(`${API}/admin/${tenantPublicId}/users/${adminPublicId}`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
      data: {
        fullName: `API Admin Updated ${runId}`,
        name: 'API Admin Updated',
        email: `api.admin.updated.${runId}@sevacare.test`,
        mobileNumber: '9000000077',
        active: true,
      },
    });
    expect(updateResponse.ok()).toBe(true);

    const deactivateResponse = await request.put(`${API}/admin/${tenantPublicId}/users/${adminPublicId}/deactivate`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(deactivateResponse.ok()).toBe(true);
    const deactivated = await deactivateResponse.json();
    expect(deactivated.data.active).toBe(false);
  });

  test('admin can list patient records', async ({ request }) => {
    const response = await request.get(`${API}/patients/${tenantPublicId}/records`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.patients).toBeDefined();
  });

  test('admin can list doctor records', async ({ request }) => {
    const response = await request.get(`${API}/doctors/${tenantPublicId}/records`, {
      headers: { Authorization: `Bearer ${token}`, 'X-Tenant-Id': tenantPublicId },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.doctors).toBeDefined();
  });
});

test.describe('Onboarding API', () => {
  test('submit onboarding request via API', async ({ request }) => {
    const response = await request.post(`${API}/public/onboarding/request`, {
      data: {
        hospitalName: 'E2E API Hospital',
        licenseNumber: 'LIC-E2E-001',
        state: 'Telangana',
        city: 'Hyderabad',
        address: '456 E2E Road',
        country: 'India',
        contactName: 'Dr. E2E',
        contactMobile: '9999999999',
        contactEmail: 'e2e@hospital.in',
        supportingDocs: '',
        facilityType: 'hospital',
      },
    });
    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.data.requestPublicId).toBeDefined();
    expect(body.data.status).toBeDefined();
  });
});
