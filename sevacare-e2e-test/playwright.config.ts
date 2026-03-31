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
  webServer: {
    command: 'cd ../sevacare-frontend && EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1 npm run web:preview',
    url: 'http://localhost:8087',
    timeout: 180_000,
    reuseExistingServer: true,
  },
});