import { expect, test } from '@playwright/test';

const HOSPITAL_NAME = 'Kishore Hospital';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => window.localStorage.clear());
  await page.reload();
});

async function openHospitalLogin(page: import('@playwright/test').Page) {
  await expect(page.getByText('SevaCare').first()).toBeVisible();
  await page.waitForTimeout(500);
  await page.getByText('Search Hospitals', { exact: true }).first().click();
  await page.getByText(HOSPITAL_NAME).first().click();
  await expect(page.getByPlaceholder('Mobile number')).toBeVisible({ timeout: 15_000 });
}

test('patient login smoke', async ({ page }) => {
  await openHospitalLogin(page);

  await page.getByPlaceholder('Mobile number').fill('9000000000');
  await page.getByText('Send OTP', { exact: true }).click();
  await expect(page.getByPlaceholder('Enter OTP')).toBeVisible({ timeout: 5_000 });
  await page.getByPlaceholder('Enter OTP').fill('0000');
  await page.getByText('Continue', { exact: true }).click();

  await expect(page.getByText('Patient actions')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByText(HOSPITAL_NAME).first()).toBeVisible();
});

test('hospital admin login smoke', async ({ page }) => {
  await openHospitalLogin(page);

  await page.getByText('Hospital Admin', { exact: true }).click();
  await page.getByPlaceholder('Mobile number or employee ID').fill('9000000003');
  await page.getByText('Send OTP', { exact: true }).click();
  await expect(page.getByPlaceholder('Enter secure PIN')).toBeVisible({ timeout: 5_000 });
  await page.getByPlaceholder('Enter secure PIN').fill('0000');
  await page.getByText('Continue', { exact: true }).click();

  await expect(page.getByText('Operations dashboard')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByText(HOSPITAL_NAME).first()).toBeVisible();
});

test('platform admin login smoke', async ({ page }) => {
  await expect(page.getByText('SevaCare').first()).toBeVisible();
  await page.waitForTimeout(500);
  await page.getByText('Features', { exact: false }).first().click();
  await expect(page.getByText('Platform admin sign in')).toBeVisible({ timeout: 10_000 });
  await page.getByText('Platform admin sign in', { exact: true }).click();

  await expect(page.getByText('SevaCare Platform')).toBeVisible({ timeout: 10_000 });
  await page.getByPlaceholder('Platform admin mobile number').fill('9000000999');
  await page.getByText('Send OTP', { exact: true }).click();
  await expect(page.getByPlaceholder('Enter platform OTP')).toBeVisible({ timeout: 5_000 });
  await page.getByPlaceholder('Enter platform OTP').fill('0000');
  await page.getByText('Continue', { exact: true }).click();

  await expect(page.getByText('All tenants and onboarding visibility')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByText('Active tenants').first()).toBeVisible();
  await expect(page.getByText(HOSPITAL_NAME).first()).toBeVisible();
});