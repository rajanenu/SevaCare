/**
 * SevaCare E2E Test Helpers
 * Shared utilities for authentication, navigation, and API interaction.
 */
import { type Page, expect } from '@playwright/test';

const API_BASE = 'http://localhost:8081/api/v1';

export async function getActiveTenant() {
  const response = await fetch(`${API_BASE}/public/tenants`);
  const envelope = await response.json();
  const firstTenant = envelope?.data?.tenants?.[0];
  if (!firstTenant?.tenantPublicId || !firstTenant?.hospitalName) {
    throw new Error('No active tenant available for tests');
  }
  return firstTenant as { tenantPublicId: string; hospitalName: string };
}

/** Navigate to homepage and select active hospital */
export async function selectAuroraHospital(page: Page) {
  const tenant = await getActiveTenant();
  await page.goto('/');
  await expect(page.getByText('SevaCare').first()).toBeVisible();
  await page.getByText('Search Hospitals', { exact: true }).click();
  await page.getByText(tenant.hospitalName).first().click();
  await expect(page.getByText('Send OTP')).toBeVisible({ timeout: 15_000 });
}

/** Login as a given role on the login screen (assumes already on login page) */
export async function loginAs(page: Page, role: 'patient' | 'doctor' | 'admin') {
  if (role !== 'patient') {
    await page.getByText(role === 'doctor' ? 'Doctor' : 'Admin').first().click();
  }

  const buttonLabel = role === 'patient'
    ? 'Send OTP'
    : 'Send OTP';

  await page.getByText(buttonLabel).first().click();
}

/** Full flow: select Aurora → login as role */
export async function selectHospitalAndLogin(page: Page, role: 'patient' | 'doctor' | 'admin') {
  await selectAuroraHospital(page);
  await loginAs(page, role);
}

/** Clear localStorage to reset app state between tests */
export async function resetAppState(page: Page) {
  await page.evaluate(() => window.localStorage.clear());
}

/**
 * Select an option from a custom DropdownSelect component.
 * The component uses testID="dropdown-{label}" on its trigger.
 * @param page - Playwright page
 * @param label - The dropdown label (e.g., "Gender", "Specialization", "Specialty")
 * @param optionText - Exact text of the option to select
 */
export async function selectDropdown(page: Page, label: string, optionText: string) {
  await page.getByTestId(`dropdown-${label}`).click();
  await page.waitForTimeout(300);
  await page.getByText(optionText, { exact: true }).first().click();
  await page.waitForTimeout(200);
}

/** API helper: get auth token for a role on T-1001 */
export async function getAuthToken(role: 'patient' | 'doctor' | 'admin'): Promise<{ token: string; subjectPublicId: string }> {
  const tenant = await getActiveTenant();
  const mobileNumber = role === 'admin' ? '9000000003' : '9000000000';
  // Request OTP
  await fetch(`${API_BASE}/auth/otp/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tenantPublicId: tenant.tenantPublicId, role, mobileNumber }),
  });

  // Verify OTP
  const response = await fetch(`${API_BASE}/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tenantPublicId: tenant.tenantPublicId, role, mobileNumber, otp: '0000' }),
  });

  const envelope = await response.json();
  return { token: envelope.data.token, subjectPublicId: envelope.data.subjectPublicId };
}

/** API helper: make authenticated request */
export async function apiRequest<T>(path: string, token: string, options?: RequestInit, tenantPublicId?: string): Promise<T> {
  const tenantId = tenantPublicId ?? (await getActiveTenant()).tenantPublicId;
  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': tenantId,
      ...(options?.headers ?? {}),
    },
  });

  if (!response.ok) {
    throw new Error(`API ${path} failed: ${response.status}`);
  }

  const envelope = await response.json();
  return envelope.data as T;
}
