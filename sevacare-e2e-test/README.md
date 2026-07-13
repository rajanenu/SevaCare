# SevaCare E2E Test

API-level Playwright tests against a locally running backend (`:8081`).
The old browser UI specs targeted a frontend that no longer exists and were
removed — `api.spec.ts` and `qr-appointment-request.spec.ts` are the suite.

## Run

```bash
npm test        # backend must already be running
npm run report
```

Suggested direction for the next phase:

- Maestro or Patrol for Flutter mobile E2E
- API assertions + screenshots against the deployed Flutter web build
  (element selectors are impractical against CanvasKit)
