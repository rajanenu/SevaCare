/**
 * SevaCare E2E – Full Tenant Lifecycle
 * End-to-end flow: onboarding → patient booking → doctor consultation → admin management.
 * Uses T-1001 (Aurora Multispeciality) with seeded data.
 */
import { expect, test } from '@playwright/test';
import { selectDropdown } from './helpers';

/* Helper: navigate to Aurora and login as role */
async function loginAs(page: import('@playwright/test').Page, role: 'patient' | 'doctor' | 'admin') {
  await page.goto('/');
  await page.getByText('Search Hospitals', { exact: true }).click();
  await page.getByText('Aurora Multispeciality').first().click();
  await expect(page.getByText('Send OTP & Continue')).toBeVisible({ timeout: 15_000 });

  if (role === 'patient') {
    await page.getByText('Send OTP & Continue').first().click();
      await expect(page.getByPlaceholder('Enter OTP')).toBeVisible({ timeout: 5_000 });
      await page.getByPlaceholder('Enter OTP').fill('0000');
      await page.getByText('Continue as Patient').first().click();
  } else if (role === 'doctor') {
    await page.getByText('Doctor').first().click();
      await page.getByText('Send OTP & Continue').first().click();
      await expect(page.getByPlaceholder('Enter secure PIN')).toBeVisible({ timeout: 5_000 });
      await page.getByPlaceholder('Enter secure PIN').fill('0000');
      await page.getByText('Continue as Doctor').first().click();
  } else {
    await page.getByText('Admin').first().click();
      await page.getByText('Send OTP & Continue').first().click();
      await expect(page.getByPlaceholder('Enter secure PIN')).toBeVisible({ timeout: 5_000 });
      await page.getByPlaceholder('Enter secure PIN').fill('0000');
      await page.getByText('Continue as Admin').first().click();
  }
}

test.describe.serial('Full tenant lifecycle – T-1001 Aurora', () => {
  test('Step 1: Patient books an appointment', async ({ page }) => {
    await loginAs(page, 'patient');
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });

    // Navigate to booking
    await page.getByText('Book Appointments').first().click();
    await expect(page.getByText('Appointment booking')).toBeVisible();

    // Fill patient info
    await page.getByPlaceholder('Patient name').fill('Lifecycle Test Patient');
    await page.getByPlaceholder('Age').fill('35');
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
    await page.getByText('Mon 24').first().click();
    await page.getByText('09:00').first().click();

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
    await expect(page.getByText('dashboard')).toBeVisible({ timeout: 10_000 });

    // Verify metrics are loaded (from API)
    await expect(page.getByText('Appointments', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Pending notes')).toBeVisible();
    await expect(page.getByText('Avg consult')).toBeVisible();
  });

  test('Step 4: Doctor performs consultation', async ({ page }) => {
    await loginAs(page, 'doctor');
    await expect(page.getByText('dashboard')).toBeVisible({ timeout: 10_000 });

    await page.getByText('Open consultation').first().click();
    await expect(page.getByText('Consultation')).toBeVisible();
    await expect(page.getByText('Symptoms', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Diagnosis', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Rx', { exact: true }).first()).toBeVisible();
  });

  test('Step 5: Doctor navigation tabs are available', async ({ page }) => {
    await loginAs(page, 'doctor');
    await expect(page.getByText('dashboard')).toBeVisible({ timeout: 10_000 });

    await expect(page.getByText('Consult', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Rx', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Schedule').first()).toHaveCount(0);
  });

  test('Step 6: Admin views operational dashboard', async ({ page }) => {
    await loginAs(page, 'admin');
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });

    // Verify metrics visible
    const hasDailyVisits = await page.getByText('Daily visits').isVisible({ timeout: 5_000 }).catch(() => false);
    const hasBookedSlots = await page.getByText('Booked slots').isVisible({ timeout: 2_000 }).catch(() => false);
    expect(hasDailyVisits || hasBookedSlots).toBe(true);
  });

  test('Step 7: Admin manages doctors', async ({ page }) => {
    await loginAs(page, 'admin');
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });

    await page.getByText('Doctor Management', { exact: true }).click();
    await expect(page.getByText('Add or update doctor')).toBeVisible();
    await expect(page.getByText('Add or update doctor')).toBeVisible();

    // Add a test doctor
    await page.getByPlaceholder('Doctor ID (D-2001)').clear();
    await page.getByPlaceholder('Doctor ID (D-2001)').fill('D-LIFECYCLE');
    await page.getByPlaceholder('Doctor name').fill('Dr. Lifecycle Test');

    await selectDropdown(page, 'Specialty', 'Cardiologist');

    await page.getByText('Add / Update Doctor').first().click();
    await page.waitForTimeout(2_000);

    // Refresh and verify doctor list shows entries
    await page.getByText('Refresh').first().click();
    await page.waitForTimeout(2_000);

    const hasDoctors = await page.getByText(/D-\d+\s*·/).first().isVisible({ timeout: 5_000 }).catch(() => false);
    expect(hasDoctors).toBe(true);
  });

  test('Step 8: Admin views patient records', async ({ page }) => {
    await loginAs(page, 'admin');
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });

    await page.getByText('Doctor Management', { exact: true }).click();
    await expect(page.getByText('Patients (view only)')).toBeVisible({ timeout: 10_000 });

    // Should show patient public IDs from seeded data
    await expect(page.getByText(/P-\d+\s*·/).first()).toBeVisible({ timeout: 15_000 });
  });
});
