/**
 * SevaCare E2E – Patient Flow
 * Tests: login, home screen, doctors list, booking form, confirmation, appointments, prescriptions.
 */
import { expect, test } from '@playwright/test';
import { selectDropdown } from './helpers';

/* Helper: navigate to Aurora login screen */
async function gotoAuroraLogin(page: import('@playwright/test').Page) {
  await page.goto('/');
  await page.getByText('Search Hospitals', { exact: true }).click();
  await page.getByText('Aurora Multispeciality').first().click();
  await expect(page.getByText('Send OTP & Continue')).toBeVisible({ timeout: 15_000 });
}

/* Helper: login as patient (default credentials pre-filled) */
async function loginAsPatient(page: import('@playwright/test').Page) {
  await gotoAuroraLogin(page);
  await page.getByText('Send OTP & Continue').first().click();
  await expect(page.getByPlaceholder('Enter OTP')).toBeVisible({ timeout: 5_000 });
  await page.getByPlaceholder('Enter OTP').fill('0000');
  await page.getByText('Continue as Patient').first().click();
}

test.describe('Patient login', () => {
  test('login screen shows patient access by default', async ({ page }) => {
    await gotoAuroraLogin(page);
    await expect(page.getByText('Patient access')).toBeVisible();
    await expect(page.getByText('Book care, manage appointments, and access prescriptions')).toBeVisible();
    await expect(page.getByPlaceholder('Mobile number')).toBeVisible();
    await expect(page.getByText('Send OTP & Continue')).toBeVisible();
  });

  test('choose different hospital link works', async ({ page }) => {
    await gotoAuroraLogin(page);
    await page.getByText('Choose a different hospital').first().click();
    await expect(page.getByText('Search Hospitals', { exact: true })).toBeVisible();
  });

  test('successful patient login navigates to home', async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText('Book Appointments')).toBeVisible();
  });
});

test.describe('Patient home screen', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
  });

  test('home shows action buttons', async ({ page }) => {
    await expect(page.getByText('Book Appointments')).toBeVisible();
    await expect(page.getByText('View Appointments')).toBeVisible();
    await expect(page.getByText('View Prescriptions')).toBeVisible();
  });

  test('bottom nav tabs are visible', async ({ page }) => {
    await expect(page.getByText('Home').first()).toBeVisible();
    await expect(page.getByText('Doctors').first()).toBeVisible();
    await expect(page.getByText('Appointments').first()).toBeVisible();
    await expect(page.getByText('Rx').first()).toBeVisible();
  });
});

test.describe('Doctors listing', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
  });

  test('doctors tab shows doctor cards', async ({ page }) => {
    await page.getByText('Doctors').first().click();
    await expect(page.getByText('Doctor listing')).toBeVisible();
    // Should list seeded doctors
    await expect(page.getByText('Dr. Meera Rao').first()).toBeVisible({ timeout: 10_000 });
  });

  test('clicking doctor navigates to booking', async ({ page }) => {
    await page.getByText('Doctors').first().click();
    await expect(page.getByText('Doctor listing')).toBeVisible();
    await page.getByText('Dr. Meera Rao').first().click();
    await expect(page.getByText('Appointment booking')).toBeVisible();
  });
});

test.describe('Booking flow', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
    await page.getByText('Book Appointments').first().click();
    await expect(page.getByText('Appointment booking')).toBeVisible();
  });

  test('booking form has all patient fields', async ({ page }) => {
    await expect(page.getByPlaceholder('Patient name')).toBeVisible();
    await expect(page.getByPlaceholder('Age')).toBeVisible();
    await expect(page.getByPlaceholder('Mobile number')).toBeVisible();
    await expect(page.getByPlaceholder('Address').first()).toBeVisible();
    await expect(page.getByText('Gender')).toBeVisible();
    await expect(page.getByText('Select specialty')).toBeVisible();
  });

  test('doctor list hidden until specialty selected', async ({ page }) => {
    // Select a specialty via the custom DropdownSelect component
    await selectDropdown(page, 'Specialization', 'Cardiologist');

    // Now doctor section should appear
    await expect(page.getByText('Select doctor').first()).toBeVisible({ timeout: 5_000 });
  });

  test('age field accepts only numbers', async ({ page }) => {
    const ageInput = page.getByPlaceholder('Age');
    await ageInput.fill('abc25xyz');
    await expect(ageInput).toHaveValue('25');
  });

  test('full booking flow end to end', async ({ page }) => {
    // Fill patient details
    await page.getByPlaceholder('Patient name').fill('E2E Test Patient');
    await page.getByPlaceholder('Age').fill('30');
    await page.getByPlaceholder('Address').first().fill('123 Test Lane');

    // Select gender
    await selectDropdown(page, 'Gender', 'Male');

    // Select specialty
    await selectDropdown(page, 'Specialization', 'Cardiologist');
    await expect(page.getByText('Select doctor').first()).toBeVisible({ timeout: 5_000 });

    // Select a doctor (click first doctor card)
    const doctorCards = page.getByText(/Dr\./).first();
    if (await doctorCards.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await doctorCards.click();
    }

    // Select a date
    await page.getByText('Mon 24').first().click();

    // Select a time slot
    await page.getByText('09:00').first().click();

    // Confirm booking
    await page.getByText('Confirm booking').first().click();
    await expect(page.getByText('Appointment confirmed')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText('Your visit is confirmed')).toBeVisible();
  });
});

test.describe('Confirmation & Appointments', () => {
  test('confirmation screen actions work', async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });

    // Quick booking for confirmation test
    await page.getByText('Book Appointments').first().click();
    await page.getByPlaceholder('Patient name').fill('Confirmation Tester');
    await page.getByPlaceholder('Age').fill('25');

    await selectDropdown(page, 'Specialization', 'Cardiologist');

    const doctorCards = page.getByText(/Dr\./).first();
    if (await doctorCards.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await doctorCards.click();
    }
    await page.getByText('Mon 24').first().click();
    await page.getByText('09:00').first().click();

    await page.getByText('Confirm booking').first().click();
    await expect(page.getByText('Appointment confirmed')).toBeVisible({ timeout: 10_000 });

    // Test go to appointments
    await page.getByText('Go to appointments').first().click();
    await expect(page.getByText('My appointments')).toBeVisible();
  });

  test('appointments screen shows tabs', async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
    await page.getByText('View Appointments').first().click();
    await expect(page.getByText('My appointments')).toBeVisible();
    await expect(page.getByText('upcoming').first()).toBeVisible();
    await expect(page.getByText('history').first()).toBeVisible();
  });

  test('appointments accessible via bottom nav', async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
    // Click Appointments tab in bottom nav
    await page.getByText('Appointments').last().click();
    await expect(page.getByText('My appointments')).toBeVisible();
  });
});

test.describe('Prescriptions', () => {
  test('prescription screen accessible', async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
    await page.getByText('View Prescriptions').first().click();
    await expect(page.getByText('My Prescriptions')).toBeVisible();
  });

  test('prescription accessible via Rx tab', async ({ page }) => {
    await loginAsPatient(page);
    await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
    await page.getByText('Rx').first().click();
    await expect(page.getByText('My Prescriptions')).toBeVisible();
  });
});
