/**
 * SevaCare E2E – Doctor Flow
 * Tests: login, doctor overview timeline/facets, and consultation/rx navigation.
 */
import { expect, test } from '@playwright/test';
import { getActiveTenant } from './helpers';

/* Helper: navigate to active hospital and login as doctor */
async function loginAsDoctor(page: import('@playwright/test').Page) {
  const tenant = await getActiveTenant();
  await page.goto('/');
  await page.getByText('Search Hospitals', { exact: true }).click();
  await page.getByText(tenant.hospitalName).first().click();
  await expect(page.getByText('Send OTP')).toBeVisible({ timeout: 15_000 });
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
}

test.describe('Doctor login', () => {
  test('login screen shows doctor access option', async ({ page }) => {
    const tenant = await getActiveTenant();
    await page.goto('/');
    await page.getByText('Search Hospitals', { exact: true }).click();
    await page.getByText(tenant.hospitalName).first().click();
    await expect(page.getByText('Send OTP')).toBeVisible({ timeout: 15_000 });

    await page.getByText('Doctor').first().click();
    await expect(page.getByText('Doctor access')).toBeVisible();
    await expect(page.getByText('Send OTP')).toBeVisible();
  });

  test('successful doctor login shows dashboard', async ({ page }) => {
    const tenant = await getActiveTenant();
    await loginAsDoctor(page);
    await expect(page.getByText('Doctor Overview')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText(tenant.hospitalName).first()).toBeVisible();
  });
});

test.describe('Doctor dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsDoctor(page);
    await expect(page.getByText('Doctor Overview')).toBeVisible({ timeout: 10_000 });
  });

  test('shows metric tiles', async ({ page }) => {
    await expect(page.getByText('Appointments', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Pending notes', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Avg consult', { exact: true }).first()).toBeVisible();
  });

  test('shows queue timeline and date navigation', async ({ page }) => {
    await expect(page.getByText('Yesterday')).toBeVisible();
    await expect(page.getByText('Today')).toBeVisible();
    await expect(page.getByText('Tomorrow')).toBeVisible();
    await expect(page.getByText('Previous')).toBeVisible();
    await expect(page.getByText('Next')).toBeVisible();
  });

  test('shows patient queue section', async ({ page }) => {
    await expect(page.getByText('Patient Queue').first()).toBeVisible();
    await expect(page.getByText('Queue for selected day.')).toBeVisible();
  });

  test('does not render removed legacy sections', async ({ page }) => {
    await expect(page.getByText('Manage schedule')).toHaveCount(0);
    await expect(page.getByText('Patient control')).toHaveCount(0);
    await expect(page.getByText('My patients')).toHaveCount(0);
  });

  test('supports contextual consultation and rx actions from selected facet', async ({ page }) => {
    const hasQueue = await page.getByText('No appointments for selected day').count() === 0;

    if (!hasQueue) {
      test.skip(true, 'No queue facets available for this environment on the selected day.');
    }

    await expect(page.getByText('Open consultation')).toBeVisible();
    await expect(page.getByText('Issue Rx')).toBeVisible();
    await page.getByText('Issue Rx').first().click();
    await expect(page.getByText('Issue Prescription')).toBeVisible();
  });
});

test.describe('Doctor navigation tabs', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsDoctor(page);
    await expect(page.getByText('Doctor Overview')).toBeVisible({ timeout: 10_000 });
  });

  test('timeline labels are visible on dashboard', async ({ page }) => {
    await expect(page.getByText('Yesterday').first()).toBeVisible();
    await expect(page.getByText('Today').first()).toBeVisible();
    await expect(page.getByText('Tomorrow').first()).toBeVisible();
  });

  test('bottom navigation exposes Consult and Rx (without Schedule)', async ({ page }) => {
    await expect(page.getByText('Consult').first()).toBeVisible();
    await expect(page.getByText('Rx').first()).toBeVisible();
    await expect(page.getByText('Schedule').first()).toHaveCount(0);
  });

  test('navigate to Consult tab', async ({ page }) => {
    await page.getByText('Consult', { exact: true }).click();
    await expect(page.getByText('Consultation', { exact: true })).toBeVisible();
  });
});

test.describe('Consultation screen', () => {
  test('shows consultation details', async ({ page }) => {
    await loginAsDoctor(page);
    await expect(page.getByText('Doctor Overview')).toBeVisible({ timeout: 10_000 });
    await page.getByText('Consult', { exact: true }).click();
    await expect(page.getByText('Consultation', { exact: true })).toBeVisible();

    await expect(page.getByText('Symptoms', { exact: true })).toBeVisible();
    await expect(page.getByText('Diagnosis', { exact: true })).toBeVisible();
    await expect(page.getByText('Rx', { exact: true }).first()).toBeVisible();
  });
});
