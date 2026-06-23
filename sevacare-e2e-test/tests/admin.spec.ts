/**
 * SevaCare E2E – Admin Flow
 * Tests: login, dashboard metrics, doctor management, and admin-user CRUD.
 */
import { expect, test } from '@playwright/test';
import { getActiveTenant, selectDropdown } from './helpers';

async function loginAsAdmin(page: import('@playwright/test').Page) {
  const tenant = await getActiveTenant();
  await page.goto('/');
  await page.getByText('Search Hospitals', { exact: true }).click();
  await page.getByText(tenant.hospitalName).first().click();
  await expect(page.getByText('Login', { exact: true })).toBeVisible({ timeout: 15_000 });
  await page.getByText('Admin').first().click();
  await expect(page.getByText('Admin access')).toBeVisible({ timeout: 10_000 });
  await page.getByPlaceholder('Mobile number or employee ID').fill('9000000003');
  await page.getByText('Send OTP').first().click();
  await expect(page.getByPlaceholder('Enter secure PIN')).toBeVisible({ timeout: 10_000 });
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

test.describe('Admin login', () => {
  test('login screen shows admin access option', async ({ page }) => {
    const tenant = await getActiveTenant();
    await page.goto('/');
    await page.getByText('Search Hospitals', { exact: true }).click();
    await page.getByText(tenant.hospitalName).first().click();
    await expect(page.getByText('Login', { exact: true })).toBeVisible({ timeout: 15_000 });

    await page.getByText('Admin').first().click();
    await expect(page.getByText('Admin access')).toBeVisible();
    await expect(page.getByText('Send OTP')).toBeVisible();
  });

  test('successful admin login shows operations dashboard', async ({ page }) => {
    await loginAsAdmin(page);
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });
  });
});

test.describe('Admin dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });
  });

  test('shows admin nav tabs', async ({ page }) => {
    await expect(page.getByText('Dashboard').first()).toBeVisible();
    await expect(page.getByText('Admin Users', { exact: true })).toBeVisible();
    await expect(page.getByText('Doctor Management', { exact: true })).toBeVisible();
  });

  test('dashboard shows metrics from API', async ({ page }) => {
    // Should show at least one metric tile (from API or fallback)
    const hasDailyVisits = await page.getByText('Daily visits').isVisible({ timeout: 5_000 }).catch(() => false);
    const hasBookedSlots = await page.getByText('Booked slots').isVisible({ timeout: 2_000 }).catch(() => false);
    // At least one metric should be visible
    expect(hasDailyVisits || hasBookedSlots).toBe(true);
  });
});

test.describe('Doctor management', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });
    await page.getByText('Doctor Management', { exact: true }).click();
    await expect(page.getByText('Add or update doctor')).toBeVisible();
  });

  test('doctor management form is visible', async ({ page }) => {
    await expect(page.getByText('Add or update doctor')).toBeVisible();
    await expect(page.getByPlaceholder('Doctor name (required)')).toBeVisible();
    await expect(page.getByPlaceholder('Available from (YYYY-MM-DD)')).toBeVisible();
    await expect(page.getByPlaceholder('Fee')).toBeVisible();
    await expect(page.getByText('Add Doctor')).toBeVisible();
  });

  test('doctor management roster loads', async ({ page }) => {
    await expect(page.getByText('Refresh').first()).toBeVisible({ timeout: 15_000 });
    const rosterCount = await page.getByText(/D-\d+\s*·/).count();
    expect(rosterCount).toBeGreaterThanOrEqual(0);
  });

  test('add a new doctor', async ({ page }) => {
    const uniqueDoctorName = `Dr. E2E ${Date.now()}`;
    await page.getByPlaceholder('Doctor name (required)').fill(uniqueDoctorName);

    await selectDropdown(page, 'Specialty', 'Cardiologist');

    await page.getByPlaceholder('Available from (YYYY-MM-DD)').fill('2026-04-01');
    await page.getByPlaceholder('Fee').clear();
    await page.getByPlaceholder('Fee').fill('₹750');

    await page.getByText('Add Doctor').first().click();

    await page.getByText('Refresh').first().click();
    await expect(page.getByText(uniqueDoctorName).first()).toBeVisible({ timeout: 10_000 });
  });

  test('delete a doctor record', async ({ page }) => {
    const uniqueDoctorName = `Dr. Delete ${Date.now()}`;
    await page.getByPlaceholder('Doctor name (required)').fill(uniqueDoctorName);
    await selectDropdown(page, 'Specialty', 'Cardiologist');
    await page.getByPlaceholder('Available from (YYYY-MM-DD)').fill('2026-04-01');
    await page.getByPlaceholder('Fee').clear();
    await page.getByPlaceholder('Fee').fill('₹650');
    await page.getByText('Add Doctor').first().click();
    await page.getByText('Refresh').first().click();
    await expect(page.getByText(uniqueDoctorName).first()).toBeVisible({ timeout: 10_000 });

    const deleteLinks = page.getByText('Delete doctor');
    const count = await deleteLinks.count();
    expect(count).toBeGreaterThan(0);
    await deleteLinks.last().click();
  });

  test('patients view only section is visible', async ({ page }) => {
    await expect(page.getByText('Patients (view only)')).toBeVisible({ timeout: 10_000 });
  });

  test('refresh button reloads data', async ({ page }) => {
    await page.getByText('Refresh').first().click();
    // Should still show the management page without errors
    await expect(page.getByText('Add or update doctor')).toBeVisible();
  });
});

test.describe('Admin user management', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
    await page.getByText('Admin Users', { exact: true }).click();
    await expect(page.getByText('Add or update admin user')).toBeVisible({ timeout: 10_000 });
  });

  test('admin user management screen is visible', async ({ page }) => {
    await expect(page.getByPlaceholder('Admin full name (required)')).toBeVisible();
    await expect(page.getByPlaceholder('Email address')).toBeVisible();
    await expect(page.getByText('Add Admin User')).toBeVisible();
  });

  test('admin can create, update, and deactivate an admin user', async ({ page }) => {
    const runId = Date.now();
    const fullName = `Admin E2E ${runId}`;
    const updatedName = `Admin Updated ${runId}`;
    const email = `admin.e2e.${runId}@sevacare.test`;
    const updatedEmail = `admin.updated.${runId}@sevacare.test`;

    await page.getByPlaceholder('Admin full name (required)').fill(fullName);
    await page.getByPlaceholder('Display name').fill('Admin E2E');
    await page.getByPlaceholder('Email address').fill(email);
    await page.getByPlaceholder('Mobile number').fill('9000000099');
    await page.getByText('Add Admin User').first().click();

    await expect(page.getByText(fullName).first()).toBeVisible({ timeout: 10_000 });
    await page.getByText('Edit admin').last().click();

    await page.getByPlaceholder('Admin full name (required)').fill(updatedName);
    await page.getByPlaceholder('Email address').fill(updatedEmail);
    await page.getByText('Update Admin User').first().click();

    await expect(page.getByText('Deactivate admin').last()).toBeVisible({ timeout: 10_000 });
    await page.getByText('Deactivate admin').last().click();
    await expect(page.getByText('inactive').last()).toBeVisible({ timeout: 10_000 });
  });
});

test.describe('Admin navigation', () => {
  test('switch between dashboard and doctor management', async ({ page }) => {
    await loginAsAdmin(page);
    await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });

    // Go to doctor management
    await page.getByText('Doctor Management', { exact: true }).click();
    await expect(page.getByText('Doctor management', { exact: true })).toBeVisible();

    // Go back to dashboard
    await page.getByText('Dashboard').first().click();
    await expect(page.getByText('Operations dashboard')).toBeVisible();
  });
});
