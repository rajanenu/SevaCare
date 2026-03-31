# SevaCare E2E Test

Playwright smoke tests are configured for local end-to-end validation.

## Smoke Test Command

Run from this folder:

```bash
npm run smoke
```

This suite auto-starts the frontend on http://localhost:8087 and validates:

- tenant entry to login
- patient booking to appointments

## Useful Commands

```bash
npm test
npm run smoke:headed
npm run report
```

Suggested direction for the next phase:

- Maestro or Detox for mobile E2E
- smoke flows for tenant selection and login
- patient booking regression suite
- doctor consultation regression suite
- admin dashboard smoke coverage