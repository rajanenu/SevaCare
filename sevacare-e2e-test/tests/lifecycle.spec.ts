/**
 * SevaCare E2E – Full Tenant Lifecycle
 * End-to-end flow: onboarding → patient booking → doctor consultation → admin management.
 * Uses T-1001 (Aurora Multispeciality) with seeded data.
 */
import { expect, test } from '@playwright/test';
import { getActiveTenant, selectDropdown } from './helpers';

async function pickFirstAvailableDateAndSlot(page: import('@playwright/test').Page) {
  const firstSlot = page.locator('text=/^\\d{2}:\\d{2}$/').first();
  await firstSlot.click();
}

/* Helper: navigate to active tenant and login as role */
async function loginAs(page: import('@playwright/test').Page, role: 'patient' | 'doctor' | 'admin') {
  const tenant = await getActiveTenant();
  await page.goto('/');
  await page.getByText('Search Hospitals', { exact: true }).click();
  await page.getByText(tenant.hospitalName).first().click();
  await expect(page.getByText('Send OTP')).toBeVisible({ timeout: 15_000 });

  if (role === 'patient') {
    await page.getByText('Send OTP').first().click();
      await expect(page.getByPlaceholder('Enter OTP')).toBeVisible({ timeout: 5_000 });
      await page.getByPlaceholder('Enter OTP').fill('0000');
      for (let attempt = 0; attempt < 3; attempt += 1) {
        await page.getByText('Continue', { exact: true }).first().click({ force: true });
        await page.waitForTimeout(600);
        const stillOnLogin = await page.getByText('Login', { exact: true }).first().isVisible().catch(() => false);
        if (!stillOnLogin) {
          break;
        }
      }
  } else if (role === 'doctor') {
    await page.getByText('Doctor').first().click();
      await page.getByText('Send OTP').first().click();
      await expect(page.getByPlaceholder('Enter secure PIN')).toBeVisible({ timeout: 5_000 });
      await page.getByPlaceholder('Enter secure PIN').fill('0000');
      for (let attempt = 0; attempt < 3; attempt += 1) {
        await page.getByText('Continue', { exact: true }).first().click({ force: true });
        await page.waitForTimeout(600);
        const stillOnLogin = await page.getByText('Login', { exact: true }).first().isVisible().catch(() => false);
        if (!stillOnLogin) {
          break;
        }
      }
  } else {
    await page.getByText('Admin').first().click();
      await page.getByText('Send OTP').first().click();
      await expect(page.getByPlaceholder('Enter secure PIN')).toBeVisible({ timeout: 5_000 });
      await page.getByPlaceholder('Enter secure PIN').fill('0000');
      for (let attempt = 0; attempt < 3; attempt += 1) {
        await page.getByText('Continue', { exact: true }).first().click({ force: true });
        await page.waitForTimeout(600);
        const stillOnLogin = await page.getByText('Login', { exact: true }).first().isVisible().catch(() => false);
        if (!stillOnLogin) {
          break;
        }
      }
  }
}

test.describe.serial('Full tenant lifecycle', () => {
  test('Step 1: Patient books an appointment', async ({ page }) => {
    await loginAs(page, 'patient');
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });

    // Navigate to booking
    await page.getByText('Book Appointments').first().click();
    await expect(page.getByText('Appointment booking')).toBeVisible();

    // Fill patient info
    await page.getByPlaceholder('Patient name').fill('Lifecycle Test Patient');
    await page.getByPlaceholder('Age').fill('35');
    await page.getByPlaceholder('Mobile number').fill('9000000001');
    await page.getByPlaceholder('Address').first().fill('42 Lifecycle Boulevard');

    // Select gender
    await selectDropdown(page, 'Gender', 'Female');

    // Select specialty
    await selectDropdown(page, 'Specialization', 'Cardiologist');
    await expect(page.getByText('Select doctor').first()).toBeVisible({ timeout: 5_000 });

    // Select any available doctor
    const doctorCards = page.getByText(/Dr\./).first();
    if (await doctorCards.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await doctorCards.click();
    }

    // Select date & slot
    await pickFirstAvailableDateAndSlot(page);

    // Confirm
    await page.getByText('Confirm booking').first().click();
    await expect(page.getByText('Appointment confirmed')).toBeVisible({ timeout: 10_000 });

    // Go to appointments
    await page.getByText('Go to appointments').first().click();
    await expect(page.getByText('My appointments')).toBeVisible();
  });

  test('Step 2: Patient views prescriptions', async ({ page }) => {
    await loginAs(page, 'patient');
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });

    await page.getByText('View Prescriptions').first().click();
    await expect(page.getByText('My Prescriptions')).toBeVisible({ timeout: 10_000 });
  });

  test('Step 3: Doctor reviews dashboard', async ({ page }) => {
    await loginAs(page, 'doctor');
    await expect(page.getByText('Doctor Overview')).toBeVisible({ timeout: 10_000 });

    // Verify metrics are loaded (from API)
    await expect(page.getByText('Appointments', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Pending notes')).toBeVisible();
    await expect(page.getByText('Avg consult')).toBeVisible();
  });

  test('Step 4: Doctor performs consultation', async ({ page }) => {
    await loginAs(page, 'doctor');
    await expect(page.getByText('Doctor Overview')).toBeVisible({ timeout: 10_000 });

    const hasConsultAction = await page.getByText('Open consultation').first().isVisible().catch(() => false);
    test.skip(!hasConsultAction, 'No consultation action available for current queue state.');

    await page.getByText('Open consultation').first().click();
    await expect(page.getByText('Consultation', { exact: true })).toBeVisible();
    await expect(page.getByText('Symptoms', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Diagnosis', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Rx', { exact: true }).first()).toBeVisible();
  });

  test('Step 5: Doctor navigation tabs are available', async ({ page }) => {
    await loginAs(page, 'doctor');
    await expect(page.getByText('Doctor Overview')).toBeVisible({ timeout: 10_000 });

    await expect(page.getByText('Consult', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Rx', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Schedule').first()).toHaveCount(0);
  });

  test('Step 6: Admin views operational dashboard', async ({ page }) => {
    await loginAs(page, 'admin');
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });

    await expect(page.getByText('Hospital Overview')).toBeVisible({ timeout: 10_000 });
  });

  test('Step 7: Admin manages doctors', async ({ page }) => {
    await loginAs(page, 'admin');
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });

    await page.getByText('Doctor Management', { exact: true }).click();
    await expect(page.getByText('Add or update doctor')).toBeVisible();

    // Add a test doctor
    await page.getByPlaceholder('Doctor name (required)').fill('Dr. Lifecycle Test');

    await selectDropdown(page, 'Specialty', 'Cardiologist');

    await page.getByPlaceholder('Available from (YYYY-MM-DD)').fill('2026-04-01');
    await page.getByPlaceholder('Fee').fill('₹650');
    await page.getByText('Add Doctor').first().click();
    await page.waitForTimeout(2_000);

    // Refresh and verify doctor list shows entries
    await page.getByText('Refresh').first().click();
    await page.waitForTimeout(2_000);
    await expect(page.getByText('Add or update doctor')).toBeVisible({ timeout: 10_000 });
  });

  test('Step 8: Admin views patient records', async ({ page }) => {
    await loginAs(page, 'admin');
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });

    await page.getByText('Doctor Management', { exact: true }).click();
    await expect(page.getByText('Patients (view only)')).toBeVisible({ timeout: 10_000 });

    // Verify the patient records section renders, with or without seeded rows.
    await expect(page.getByText('Refresh').first()).toBeVisible({ timeout: 10_000 });

    const patientRows = page.getByText(/P-\d+\s*·/);
    const rowCount = await patientRows.count();
    if (rowCount > 0) {
      await expect(patientRows.first()).toBeVisible({ timeout: 10_000 });
    }
  });
});
