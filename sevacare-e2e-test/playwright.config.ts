import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: {
    timeout: 10_000,
  },
  fullyParallel: false,
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: 'http://localhost:8087',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  // Frontend moved to Flutter (sevacare-flutter); use scripts/start-frontend.sh
  // to serve it on :8087 if a suite needs the browser/DOM. api.spec.ts only
  // needs the backend, so no webServer is started here.
});