# SevaCare Frontend

This frontend is set up as a local-first mobile UI prototype for SevaCare.

## Chosen Stack

- Expo + React Native for fast mobile iteration on iOS, Android, and web previews.
- TypeScript for strict UI modeling and safer refactors.
- Expo device modules for local capabilities such as location and camera-based QR entry.
- Token-driven tenant theming so the same app shell can render premium and clinic variants.
- Zustand installed as the lightweight state layer for multi-step flow state as the app grows.

## Why This Stack

- It is the fastest path to a production-grade mobile UI without locking the team into native-only workflows too early.
- It supports local-only development now and can connect cleanly to a Spring Boot backend later.
- It keeps theming, design tokens, role-based navigation, and reusable components in one codebase.

## Current UI Coverage

- Tenant entry flow: search, nearby hospitals, QR scan, saved hospitals, tenant loading.
- Patient flow: login, dashboard, doctor listing, booking, confirmation, appointments, prescription.
- Doctor flow: login, dashboard, consultation, schedule.
- Admin flow: login, dashboard, doctor management, slot configuration, reports.

## Figma Reference Integration

- The app imports [src/figma-full-screens.json](src/figma-full-screens.json) and maps runtime screens to its page/frame structure.
- The app imports [src/figma-tokens.json](src/figma-tokens.json) and applies tenant color/button/radius tokens in [src/theme.ts](src/theme.ts).
- Welcome screen action cards are now generated from the JSON frame elements.
- Login CTA text adapts from the JSON login elements (for example OTP-specific patient CTA).
- The token parser resolves simple references like `{global.radius.lg}` and linear-gradient button backgrounds.

## Local Run

```bash
npm install
npm run start
```

From workspace root:

```bash
npm --prefix sevacare-frontend run start:local
```

From frontend folder:

```bash
cd sevacare-frontend
npm run start:local
```

## Recommended Next UI Steps

1. Break the prototype screens into a proper `src/screens` and `src/components` structure.
2. Add navigation and persisted app state once the final information architecture is confirmed.
3. Replace demo data with API contracts after the Spring Boot backend is defined.
4. Add visual regression and E2E coverage in the dedicated testing folder.