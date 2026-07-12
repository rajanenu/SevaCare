# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

SevaCare is a multi-tenant hospital management platform: a Spring Boot API, a Flutter
app (Android + web), and a Postgres database with one schema per hospital.

| Path | What lives there |
|---|---|
| `sevacare-backend/` | Maven multi-module Spring Boot API (Java 21) |
| `sevacare-flutter/` | Flutter app — Android APK and the web frontend, one codebase |
| `sevacare-deploy/` | Dockerfiles, Cloud Build configs, `DEPLOYMENT.md` |
| `scripts/` | Local dev helpers (`start-backend.sh`, `status.sh`, …) |
| `docs/` | Design docs and feature blueprints |
| `sevacare-e2e-test/` | Only `api.spec.ts` still works; the UI specs target a frontend that no longer exists |

Backend modules: `sevacare-api` (controllers, config, Flyway migrations, scheduled
tasks) depends on `-patient`, `-doctor`, `-admin`, `-tenant`, all of which depend on
`-shared` (DTOs, `TenantContext`).

## Build, run, verify

```bash
# Backend — compile before you claim anything works
cd sevacare-backend && mvn -q -T1C -DskipTests compile

# Pharmacy integration tests need Docker (Testcontainers). Always pass -am:
# a bare -pl sevacare-api resolves a stale sevacare-pharmacy jar.
cd sevacare-backend && mvn -pl sevacare-api -am test

# Flutter — analyze must stay at zero errors/warnings (16 pre-existing infos are fine)
cd sevacare-flutter && flutter analyze

# Android APK, built against the local backend
flutter build apk --release --dart-define=LOCAL_BACKEND_HOST=<this Mac's LAN IP>
```

Detect the LAN IP yourself (`ipconfig getifaddr en0`) rather than asking. The APK must
stay at `sevacare-flutter/build/app/outputs/flutter-apk/app-release.apk` — never copy it
elsewhere.

Restart the local backend yourself after backend edits, and share the fresh LAN IP.
Do not invoke `scripts/start-backend.sh` directly — it blocks on a trailing `wait`.

## Architecture facts that are easy to get wrong

**Tenancy.** `TenantContext` holds `(tenantPublicId, tenantSchema)` per request.
`T-1013` → schema `tenant_t_1013`. Public endpoints (QR booking, chatbot quick-booking)
carry no tenant context, so they set it explicitly and restore the previous value.
Cross-tenant tables (`tenant_registry`, `appointment_request`, `whatsapp_outbox`,
`user_otp_override`) live in `public`.

**Tenant schemas are versioned.** Migrations in `sevacare-tenant/.../db/tenant` run once
per tenant schema, tracked in that schema's own `flyway_tenant_history`, driven by
`TenantMigrationService`. `V1__tenant_baseline.sql` is a *reconciling* baseline that
converges every schema to one shape, so V2 onward may be ordinary forward migrations
that assume that shape. Flyway is baselined at version **0**, not its default of 1 —
at 1 it records V1 as applied and silently skips it.

Public-schema migrations (`sevacare-api/.../db/migration`) are separate and still run
via Spring Boot's auto-configured Flyway. Old ones loop over `tenant_t_%` and guard each
statement with `to_regclass(...) IS NULL` (see `V32__whatsapp_outbox_and_perf_indexes.sql`);
do not write new ones that way — put per-tenant DDL in `db/tenant`.

**A DB change means both databases.** Local `seva_care` and the Cloud SQL prod DB must
stay structurally identical, so schema drift never returns. Verify on a `pg_dump` clone
first, apply locally, then sync Cloud SQL — but ask before touching prod (see "Never
deploy unprompted"). Prove parity by diffing `information_schema`, don't assume it.

**A tenant is a set of modules, not a kind of business.** `tenant_registry` carries
`clinical_enabled` (doctors/patients/prescriptions) and `pharmacy_profile_key` (NULL =
no pharmacy); a check constraint forbids both being off. There is no `tenant_kind`
column — `TenantKind` is only the onboarding question, translated once and discarded.
`TenantModuleService` is the sole owner of "does this tenant have X?"; the API gate,
`GET /api/v1/capabilities` and the pharmacy policy engine all delegate to it. A module
the tenant lacks answers **404, not 403** — 403 leaks that it exists. A standalone
medical store is a first-class customer, not a hospital with the doctors deleted.

**A migration cannot ask what modules a tenant has.** `provisionTenant` migrates the
schema on Flyway's own connection *before* it commits the `tenant_registry` row, so from
inside a tenant migration that row does not exist yet. A migration that gates on it reads
NULL and silently does nothing — which is exactly what the old starter-catalog seed (V6)
did for every tenant onboarded through the app, leaving every new pharmacy with an empty
search box. Anything that depends on a tenant's modules belongs in a service that runs
after the commit. The starter catalog is now `PharmacyCatalogSeeder`, driven by the
after-commit `PharmacyEnabledEvent` and by a boot sweep that heals stores onboarded
before the fix. It seeds only a store whose catalog *and* ledger are both empty, and its
rows are marked `ref_type = 'SEED'` so `TenantModuleService` still counts an
only-ever-seeded pharmacy as unused and lets it be switched back off.

**The counter's catalog is versioned, not timed.** `/catalog/stock` is stamped with a
version read from the data — SKU count, newest SKU edit, highest `ledger_id`, newest batch
edit — which is the server's cache key *and* the HTTP ETag. The client holds the catalog
and revalidates with `If-None-Match`, so reopening the till is a 304 and a sale on another
device is visible at once. Do not put a TTL back: the old 12-hour cache was invalidated
only by catalog writes (so a sale left on-hand stale) and only on the one Cloud Run
instance that served the write. `ETag` must stay in the CORS `exposedHeaders` or the
browser hides it from the web app.

**Stock is a ledger, never a quantity.** `stock_ledger` is append-only and
`batch_balance` is a cache of its sum. Postgres triggers enforce both: the ledger raises
on UPDATE/DELETE, and the balance raises on any write that did not `SET LOCAL
sevacare.ledger_append = 'on'` — which only `StockLedgerService` does, inside a
transaction. Correct a mistake with a compensating row (`correction_of`), never an edit.
Quantities are base units (tablets, ml); money is integer paise; GST is basis points.

**Pharmacy rules are OFF/SUGGEST/ENFORCE knobs**, resolved platform default →
`platform.capability_profile` → tenant `pharmacy_config`. Never a boolean.
`EXPIRED_BATCH_DISPENSE` is the one knob with no OFF. A negative balance is information
(a receipt was never entered), not corruption — only ENFORCE refuses it. Pharmacy is off
for a tenant whose `tenant_registry.pharmacy_profile_key` is NULL.

**The counter sale prices at MRP, and backs GST out of it.** Indian retail MRP is
GST-inclusive: a ₹105 line at 5% is ₹100 taxable + ₹5 GST, not ₹105 + ₹5.25. The one
extraction rule lives in `CounterSaleService.taxableFromInclusive` (public, unit-tested).
The client sends *what* and *how many*, never a price — billing charges the batch's
printed MRP (the deliberate exception is `mrpOverridePaise`, honoured only when
`PRICE_EDIT_AT_BILLING` isn't OFF). One sale line per (sku, batch) because a recall must
find which customer got which batch, so a FEFO split across two batches is two lines and
two ledger rows. Sale + `sale_line` + the ledger append commit in one transaction: a
receipt without a dispense, or the reverse, cannot exist.

**Pharmacy REST is `/api/v1/pharmacy/**`** (not `/api/pharmacy` — that was an early
inconsistency), gated by `ModuleAccessFilter` (404 for a tenant without pharmacy) and
`@PreAuthorize("hasAnyRole('ADMIN','STAFF')")` — the owner and the counter pharmacist, not
doctors. Every response is a `ContractResponse` envelope (`data`), because the Flutter
`ApiClient` always unwraps `data` — a controller returning a bare record breaks the client.

**The Flutter app builds its shell from `/api/v1/capabilities`, not the role.** Login (and
biometric restore) fetch capabilities into `AuthState.capabilities`; a pharmacy-only tenant
lands on `/pharmacy`, and admin/staff of a hospital-with-pharmacy get a Pharmacy shortcut in
their dashboard hero. The counter itself is `PharmacyShellScreen` (Sell / Stock / Today).

**One appointment queue.** Every booking — slot or token, from any of the four channels
(patient app, IP-Staff, QR portal, chatbot) — draws a token from the same
per-`(doctor, date, session)` counter, and every channel funnels through
`PatientDomainService.bookAppointment`. Put cross-channel behaviour there, once.

**Booking source is whitelisted.** `normalizeBookingSource` silently maps anything it
doesn't recognise to `PATIENT_APP`. Add new sources to that switch or they vanish from
the admin channel analytics.

**Times are IST.** The JVM default is set in `SevaCareApiApplication` and Hikari runs
`SET TIME ZONE 'Asia/Kolkata'` on every connection, because Cloud SQL defaults to UTC.

**`appointment_slot` is a string** in `yyyy-MM-dd HH:mm` form, so a lexicographic
comparison is also a chronological one — range queries in SQL are safe.

## Flutter conventions

- **`AppShell` with a `RefreshIndicator` + `ListView` body needs `scrollable: false`.**
  Otherwise the screen renders blank at runtime with zero analyzer errors.
- **Tab screens pin the header and tabs** (`scrollable: false`) and put an `IndexedStack`
  of per-tab scroll areas below. Do not scroll the whole page on tab switch, and never
  `jumpTo(0)` on tab change — that was tried and rejected.
- Hidden `IndexedStack` tabs still build. Anything polling behind `AutoRefreshMixin`
  must check visibility, or every tab polls at once.
- Riverpod forbids mutating provider state during `dispose()`; capture the notifiers in
  `initState` and defer the write with `Future.microtask`.

## Working style

- Be concise. Minimal narration; report findings and outcomes, not each step.
- **Never deploy unprompted.** Build and test locally; the user decides when to release.
- **Do not delete a UI control because it looks confusing.** Diagnose the underlying
  layout bug (usually `Row` overflow → `Wrap`) instead.
- Prefer fixing the query over adding a cache; several "slow screens" were unbounded
  `findByTenant…()` calls filtered in memory.
- When a fix "doesn't work", suspect a stale `mvn`/backend process before suspecting the
  code.

## Deploying

Cloud Run + Cloud SQL, GCP project `sevacareapp`, region `asia-south1`. Full commands in
`sevacare-deploy/DEPLOYMENT.md`. Two things bite:

- `export CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11` — the bundled Python 3.9 fails.
- `gcloud builds submit` uploads the whole working tree first. Untracked large
  directories (e.g. `marketing/`) make deploys hang for 15+ minutes with no log output.
  Check `.gcloudignore` before blaming the build.

**"The deploy didn't work" is usually a stale client.** Prove the deploy landed by grepping
the served bundle for a string only the new code has:

```bash
curl -s https://sevacare-frontend-2glz4tgi3q-el.a.run.app/main.dart.js | grep -c 'Hide OTP'
```

Flutter web puts no content hash in any filename, so `sevacare-deploy/nginx.conf` sends
`Cache-Control: no-cache` — it still caches, but revalidates against the ETag, so an
unchanged 5 MB `main.dart.js` costs a 304 rather than a re-download. Without that header
browsers heuristically cache the bundle and a released change stays invisible. And a Cloud
Run deploy never updates an installed APK — rebuild and reinstall that separately.

## WhatsApp delivery

Prescriptions, booking confirmations and follow-up reminders are enqueued into
`public.whatsapp_outbox` inside the triggering transaction, then delivered by
`WhatsAppService.drainOutbox()`. Enqueueing never throws — a courtesy message must not
fail the consult that produced it. Without `SEVACARE_WHATSAPP_PHONE_NUMBER_ID` and
`SEVACARE_WHATSAPP_ACCESS_TOKEN` the rows park as `NO_PROVIDER` with an intact `wa.me`
link; nothing is lost and nothing is sent.
