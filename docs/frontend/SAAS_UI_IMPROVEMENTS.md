# SevaCare UI SaaS Improvement Roadmap

## 1) Multi-tenant token architecture

- Keep `figma-tokens.json` as source of truth, but split into:
  - `global.json` (color primitives, spacing, typography, radius)
  - `tenant/<tenant-id>.json` (brand overrides)
- Add a runtime token validator (Zod or JSON Schema) before applying tenant themes.
- Add a token fallback chain:
  1. Tenant token
  2. Global token
  3. Safe default token

## 2) Theme provider and component library

- Introduce a dedicated ThemeProvider and useTheme hook.
- Move reusable UI into `src/components/ui`:
  - Button
  - Input
  - Card
  - Badge
  - SegmentedControl
  - BottomNav
- Keep screens in `src/screens/<flow>/<screen>.tsx` and compose from UI primitives only.

## 3) Tenant-aware navigation and config

- Store tenant metadata in a tenant registry with:
  - tenantId
  - displayName
  - tokenSetVersion
  - featureFlags
  - enabledFlows
- Drive navigation visibility from tenant and role capabilities.

## 4) Feature flags and SaaS customization

- Add per-tenant and per-plan flags:
  - `enableQrLogin`
  - `enableVideoConsult`
  - `enableDigitalRx`
  - `enableAdminReports`
- Hide incomplete or disabled features via capability checks, not conditionals in screen JSX.

## 5) Data contracts for static-to-real migration

- Define typed contracts now for:
  - Tenant
  - Hospital
  - Doctor
  - Appointment
  - Prescription
- Keep demo data in a repository layer so backend integration is a drop-in swap.

## 6) Remove unnecessary coupling

- Reduce monolithic `App.tsx` into:
  - app shell
  - flow routers
  - screen modules
  - shared components
- Avoid hard-coded page strings in tests by using test IDs or stable semantic labels.

## 7) UI quality and accessibility

- Add accessibility labels and focus order for all tappable controls.
- Enforce 44+ px touch targets.
- Add contrast checks for each tenant token set.
- Add typography scale tokens for small/medium/large screens.

## 8) Test strategy for SaaS UI

- Keep smoke suite for critical path:
  - tenant selection
  - login
  - booking
- Add matrix testing by tenant:
  - Premium theme
  - Clinic theme
  - future tenant token sets
- Add visual snapshots per tenant for regressions.

## 9) Performance and reliability

- Precompute derived theme values once per tenant switch.
- Lazy-load heavy role screens and large lists.
- Add skeleton loading states for tenant and dashboard transitions.

## 10) Suggested next implementation steps

1. Extract ThemeProvider and UI primitives.
2. Split App.tsx into screen modules.
3. Add tenant registry + feature flags.
4. Add tenant matrix smoke tests.
5. Prepare API adapter interfaces for Spring Boot integration.
