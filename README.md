# SevaCare

A multi-tenant healthcare platform for Indian hospitals, clinics and medical stores.
One customer ("tenant") buys a **set of modules** — clinical, pharmacy, or both — and
gets an isolated Postgres schema, a web app, and an Android app.

| | |
|---|---|
| **Backend** | Spring Boot 3 / Java 21, Maven multi-module |
| **Frontend** | Flutter — one codebase, ships as Android APK **and** the web app |
| **Database** | PostgreSQL — one schema per tenant, plus a shared `public` schema |
| **Hosting** | Cloud Run + Cloud SQL (GCP `sevacareapp`, region `asia-south1`) |

---

## The one idea you must understand first

**A tenant is a set of modules, not a kind of business.**

`public.tenant_registry` carries two switches:

- `clinical_enabled` — doctors, patients, prescriptions
- `pharmacy_profile_key` — the pharmacy module (`NULL` = no pharmacy)

A check constraint forbids both being off. There is *no* `tenant_kind` column. A standalone
medical store is a first-class customer, not "a hospital with the doctors deleted"; a hospital
with a dispensary is one tenant with both modules on.

`TenantModuleService` is the single owner of *"does this tenant have X?"*. The API gate,
`GET /api/v1/capabilities`, and the pharmacy policy engine all delegate to it.

**A module the tenant does not have answers `404`, not `403`** — 403 would leak that the
feature exists and hand an attacker a map of what each customer bought.

The Flutter app builds its whole navigation shell from `/api/v1/capabilities`, never from the
user's role.

---

## Repository layout

| Path | What lives there |
|---|---|
| `sevacare-backend/` | Maven multi-module Spring Boot API (Java 21) |
| `sevacare-flutter/` | Flutter app — Android APK and the web frontend, one codebase |
| `sevacare-deploy/` | Dockerfiles, Cloud Build configs, `DEPLOYMENT.md` |
| `scripts/` | Local dev helpers (`start-backend.sh`, `status.sh`, …) |
| `docs/` | Design docs and feature blueprints |
| `sevacare-e2e-test/` | Only `api.spec.ts` still works — the UI specs target a frontend that no longer exists |

### Backend modules

```
sevacare-api        controllers, security filters, Flyway (public schema), scheduled tasks
  ├── sevacare-patient    appointments, the booking queue, WhatsApp outbox
  ├── sevacare-doctor     consultations, prescriptions, availability
  ├── sevacare-admin      hospital admin, staff, reports
  ├── sevacare-pharmacy   stock ledger, counter sale, GRN, policy engine
  ├── sevacare-tenant     tenant registry, per-tenant migrations, capabilities
  └── sevacare-shared     DTOs, TenantContext  ← everything depends on this
```

---

## Build, run, verify

### Prerequisites

| Software | Version |
|---|---|
| Java | 21 |
| Maven | 3.9+ |
| Flutter | 3.11.5+ |
| PostgreSQL | 15+ |
| Docker | for the pharmacy integration tests (Testcontainers) |

### Backend

```bash
cd sevacare-backend

# Compile — do this before claiming anything works
mvn -q -T1C -DskipTests compile

# Tests. Always pass -am: a bare `-pl sevacare-api` resolves a stale pharmacy jar.
mvn -pl sevacare-api -am test
```

Local defaults (`application.yml`) point at `localhost:5432/seva_care`. Production overrides live
in `application-production.yml`, activated with `SPRING_PROFILES_ACTIVE=production`, where every
secret comes from the environment with **no fallback** so a missing secret fails fast at boot.

### Flutter

```bash
cd sevacare-flutter

flutter analyze        # must stay at zero errors/warnings

# Web
flutter run -d chrome

# Android APK against the local backend — detect the LAN IP, don't guess
flutter build apk --release --dart-define=LOCAL_BACKEND_HOST=$(ipconfig getifaddr en0)
```

The APK must stay at `sevacare-flutter/build/app/outputs/flutter-apk/app-release.apk`.

---

## Architecture: the load-bearing decisions

These are the things that are easy to get wrong, and expensive when you do.

### Tenancy

`TenantContext` holds `(tenantPublicId, tenantSchema)` per request. `T-1013` → schema
`tenant_t_1013`. Hibernate routes to that schema per connection (`SCHEMA` multi-tenancy).

Cross-tenant tables — `tenant_registry`, `appointment_request`, `whatsapp_outbox`,
`user_passcode`, `auth_refresh_token`, `revoked_access_token`, `audit_log`,
`idempotency_key` — live in `public`.

Public endpoints (QR booking, chatbot quick-booking) carry no tenant context, so they set it
explicitly and restore the previous value.

### Tenant schemas are versioned independently

Migrations in `sevacare-tenant/.../db/tenant` run **once per tenant schema**, tracked in that
schema's own `flyway_tenant_history`, driven by `TenantMigrationService`.

- `V1__tenant_baseline.sql` is a *reconciling* baseline that converges every schema to one shape.
  V2 onward may therefore be ordinary forward migrations that assume that shape.
- Flyway is baselined at version **0**, not its default of 1. At 1 it records V1 as applied and
  silently skips it.
- **A migration cannot ask what modules a tenant has.** `provisionTenant` migrates the schema on
  Flyway's own connection *before* it commits the `tenant_registry` row — so from inside a tenant
  migration, that row does not exist yet. Anything module-dependent belongs in a service that runs
  after the commit (see `PharmacyCatalogSeeder`, driven by the after-commit `PharmacyEnabledEvent`).

Public-schema migrations (`sevacare-api/.../db/migration`) are separate and run via Spring Boot's
auto-configured Flyway.

**A DB change means both databases.** Local `seva_care` and the Cloud SQL production DB must stay
structurally identical. Prove parity by diffing `information_schema` — don't assume it.

### Stock is a ledger, never a quantity

`stock_ledger` is append-only; `batch_balance` is a cache of its sum. Postgres triggers enforce
both: the ledger raises on `UPDATE`/`DELETE`, and the balance raises on any write that did not
`SET LOCAL sevacare.ledger_append = 'on'` — which only `StockLedgerService` does, inside a
transaction.

Correct a mistake with a compensating row (`correction_of`), never an edit.

Quantities are **base units** (tablets, ml). Money is **integer paise**. GST is **basis points**.

### The counter sale prices at MRP and backs GST out of it

Indian retail MRP is GST-inclusive: a ₹105 line at 5% is ₹100 taxable + ₹5 GST, *not* ₹105 + ₹5.25.
The one extraction rule lives in `CounterSaleService.taxableFromInclusive` (public, unit-tested).

The client sends *what* and *how many* — never a price. One sale line per `(sku, batch)`, because a
recall must find which customer got which batch. Sale + `sale_line` + the ledger append commit in
**one transaction**: a receipt without a dispense, or the reverse, cannot exist.

### Pharmacy rules are OFF/SUGGEST/ENFORCE knobs, never booleans

Resolved: platform default → `platform.capability_profile` → tenant `pharmacy_config`.
`EXPIRED_BATCH_DISPENSE` is the one knob with no OFF.

A negative balance is *information* (a receipt was never entered), not corruption — only ENFORCE
refuses it.

### One appointment queue

Every booking — slot or token, from any of the four channels (patient app, IP-Staff, QR portal,
chatbot) — draws a token from the same per-`(doctor, date, session)` counter, and every channel
funnels through `PatientDomainService.bookAppointment`. Put cross-channel behaviour there, once.

Booking source is whitelisted: `normalizeBookingSource` silently maps anything it does not
recognise to `PATIENT_APP`. Add new sources to that switch or they vanish from the admin channel
analytics.

### Times are IST

The JVM default is set in `SevaCareApiApplication`, and Hikari runs `SET TIME ZONE 'Asia/Kolkata'`
on every connection — Cloud SQL defaults to UTC.

`appointment_slot` is a **string** in `yyyy-MM-dd HH:mm` form, so a lexicographic comparison is also
a chronological one; range queries in SQL are safe.

### The counter's catalog is versioned, not timed

`/catalog/stock` is stamped with a version read from the data (SKU count, newest SKU edit, highest
`ledger_id`, newest batch edit). That version is both the server's cache key and the HTTP **ETag**.
The client revalidates with `If-None-Match`, so reopening the till is a 304 and a sale on another
device is visible at once.

Do not put a TTL back. `ETag` must stay in the CORS `exposedHeaders` or the browser hides it from
the web app.

### WhatsApp delivery is an outbox

Prescriptions, booking confirmations and follow-up reminders are enqueued into
`public.whatsapp_outbox` **inside the triggering transaction**, then delivered by
`WhatsAppService.drainOutbox()` (which claims rows with `FOR UPDATE SKIP LOCKED`, so it is safe on
many instances).

Enqueueing never throws — a courtesy message must not fail the consult that produced it. Without
`SEVACARE_WHATSAPP_PHONE_NUMBER_ID` and `SEVACARE_WHATSAPP_ACCESS_TOKEN`, rows park as `NO_PROVIDER`
with an intact `wa.me` link: nothing is lost and nothing is sent.

---

## API conventions

- Everything is under `/api/v1`.
- Pharmacy is `/api/v1/pharmacy/**` (not `/api/pharmacy` — that was an early inconsistency).
- **Every response is a `ContractResponse` envelope** (`{"data": …}`), because the Flutter
  `ApiClient` always unwraps `data`. A controller returning a bare record breaks the client.
- `ApiClient` refuses to send any path containing `//`, so a missing path segment fails loudly and
  locally instead of logging the user out.

### Request pipeline

```
TenantHeaderFilter         →  resolves X-Tenant-Id to a schema, sets TenantContext
TokenAuthenticationFilter  →  parses the bearer token, sets the Spring Security principal
TenantAccessFilter         →  403s a session reaching for a tenant that is not its own
ModuleAccessFilter         →  404s a module this tenant did not buy
@PreAuthorize              →  role check on the controller method
```

**`X-Tenant-Id` is an input, never an answer.** The client types that header, and it becomes the
Postgres schema every query runs against — so `TenantAccessFilter` pins it to the tenant baked into the
signed token. Never take the tenant, the role or the subject from anywhere but the token. The
`"Tenant mismatch"` check repeated through the controllers compares the *path* with the *header* — both
chosen by the caller — so it is a second wall, not the first one.

---

## Flutter conventions

- **`AppShell` with a `RefreshIndicator` + `ListView` body needs `scrollable: false`.** Otherwise
  the screen renders blank at runtime, with zero analyzer errors.
- **Tab screens pin the header and tabs** (`scrollable: false`) and put an `IndexedStack` of
  per-tab scroll areas below. Never `jumpTo(0)` on tab change — that was tried and rejected.
- Hidden `IndexedStack` tabs still build. Anything polling behind `AutoRefreshMixin` must check
  visibility, or every tab polls at once.
- Riverpod forbids mutating provider state during `dispose()`; capture the notifiers in `initState`
  and defer the write with `Future.microtask`.
- **A restored session carries no capabilities.** `AuthNotifier.restore()` rebuilds the session from
  secure storage, but capabilities are deliberately *not* persisted — a stale module flag must not
  outlive a session. Any screen reachable by a restored session must settle capabilities *before* it
  loads anything module-specific, and take the tenant from `auth.tenantPublicId` (the session), not
  from `hospitalProvider` (the last thing browsed).

---

## Deploying

Cloud Run + Cloud SQL. Full commands in [sevacare-deploy/DEPLOYMENT.md](sevacare-deploy/DEPLOYMENT.md).

Two things bite:

- `export CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11` — the bundled Python 3.9 fails.
- `gcloud builds submit` uploads the whole working tree first. Untracked large directories make
  deploys hang for 15+ minutes with no log output. Check `.gcloudignore` before blaming the build.

**"The deploy didn't work" is usually a stale client.** Flutter web puts no content hash in any
filename, so `sevacare-deploy/nginx.conf` sends `Cache-Control: no-cache` (it still caches, but
revalidates against the ETag). Prove the deploy landed by grepping the served bundle for a string
only the new code has:

```bash
curl -s https://<frontend-url>/main.dart.js | grep -c 'some-new-string'
```

A Cloud Run deploy never updates an installed APK — rebuild and reinstall that separately.

---

## Where the project is going

[docs/ARCHITECTURE_IMPROVEMENT_PLAN.md](docs/ARCHITECTURE_IMPROVEMENT_PLAN.md) is the current
security, scale and maintainability review — what was found, what is fixed, and what is next in
priority order.

The three blockers that gated real patient data are now closed:

- **Login is a self-set 4-digit passcode** (BCrypt-hashed, 5-attempt lockout, fail-closed).
  New users start on the shared default `0000` until they set their own — nothing is sent
  by SMS, so there is no per-message cost and no external provider.
- **Access tokens are real JWTs (60 min)** with rotating, server-side-revocable refresh
  tokens — logout revokes both halves for real.
- **Release builds are signed with a real upload key** kept outside the repo
  (`~/sevacare-keys/`); `key.properties` is git-ignored.

Also in place: an append-only `audit_log` for every PHI read/write, `Idempotency-Key`
dedupe on booking and counter-sale POSTs, per-IP auth rate limiting, and security headers
on both nginx and the API.

---

## Contributing

Read [CLAUDE.md](CLAUDE.md) — it carries the same architecture facts as this file plus the working
conventions, and it is what an AI assistant is given as context.

Before you open a PR:

```bash
cd sevacare-backend && mvn -q -T1C -DskipTests compile && mvn -pl sevacare-api -am test
cd sevacare-flutter && flutter analyze
```
