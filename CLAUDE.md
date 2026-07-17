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

# Android APK, built against the local backend.
# --target-platform is not optional: a bare `flutter build apk --release` bundles all
# three ABIs (arm, arm64, x86_64) — three whole copies of the engine and of your Dart —
# and weighs 65MB. arm64 alone, obfuscated, is 22.8MB and is what every real phone runs.
flutter build apk --release --target-platform android-arm64 \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=LOCAL_BACKEND_HOST=<this Mac's LAN IP>

# For the Play Store, ship the bundle and let Play slice it per device — never a universal APK:
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
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
`user_passcode`, `auth_refresh_token`, `revoked_access_token`, `audit_log`,
`idempotency_key`) live in `public`.

**A session may only ever touch its own tenant, and the token is what says which.**
`X-Tenant-Id` is typed by the client, and `TenantHeaderFilter` turns it straight into the
schema every query runs against — so it is an *input*, never the answer. `TenantAccessFilter`
pins it to the tenant claim in the bearer token and answers **403** on a mismatch. Until it
existed, a real admin token from one hospital, replayed with another hospital's id in the
header, returned that hospital's patient list — names, mobiles, ages, visit history. The
`"Tenant mismatch"` guard copy-pasted through ~100 controller methods does *not* close this:
it compares the path variable with `TenantContext`, i.e. the header against the path, both
chosen by the caller, so it only ever checked that the client agreed with itself. Keep those
guards as a second wall; never let them be the first. Never take the tenant, role or subject
from anywhere but the signed token. The full chain, in order:
`TenantHeaderFilter` → `TokenAuthenticationFilter` → `TenantAccessFilter` → `ModuleAccessFilter`
→ `@PreAuthorize`.

**Login is a passcode, not an SMS.** Nothing is ever sent to a phone. Every user starts on
the shared default OTP `0000` and can set their own 4-digit passcode (Profile → Login
Passcode); the moment they do, `0000` stops working for them. `public.user_passcode` holds
only BCrypt hashes, keyed by mobile — one passcode per person across roles and tenants.
`PasscodeService.verify` is the single entry point: **5 wrong attempts lock the account for
15 minutes** (DB-persisted, so it holds across Cloud Run instances → 429), and an unreadable
credential store **fails closed** (503) — never a silent fall back to `0000`. `0000` itself
is rejected as a chosen passcode. Resets clear the row (back to `0000`): a tenant admin can
reset own-tenant users (`POST /admin/{t}/passcode-reset`, gated on the mobile being known to
that tenant), a platform admin anyone. `/auth/otp/request` returns `credentialMode`
(`DEFAULT_OTP`|`PASSCODE`) so the login screen asks for the right thing — "OTP sent" copy for
default users, "Enter your 4-digit passcode" once they've set one. `RateLimitFilter` caps
auth and public-booking POSTs at 30/min/IP (sized for a clinic behind one shared WiFi IP; the
DB lockout, not the rate limit, is what stops a guesser).

**A token expires; the session survives it.** Access tokens are real JWTs (60 min,
`sub`/`tenant`/`role`/`iat`/`exp`/`jti`, HS256 over SHA-256 of `SEVACARE_AUTH_SECRET`) — the
previous format had **no expiry at all**, so one captured token was valid forever. Sessions
outlive the hour via an opaque rotating refresh token (`/auth/refresh`, 30 days, only its
SHA-256 stored in `auth_refresh_token`): every refresh rotates, and a rotated-out token
presented again is treated as a replayed theft and refused. `/auth/logout` revokes the
refresh token *and* the bearer's `jti` (checked via a 60s cache over
`revoked_access_token` — deliberately fail-open, the window is bounded by `exp`). The
Flutter `ApiClient` refreshes on 401 (single-flight — parallel refreshes would revoke each
other) and retries once; only an unrescuable 401 wipes the session. Client rule: hard
sign-out and account deletion call `logoutEverywhere()` first; **soft sign-out (keeping
biometric) must not** — the fingerprint has to restore a live session.

**Every PHI touch leaves a row.** `AuditLogInterceptor` (registered in `WebConfiguration`)
matches patient-data routes and appends who/what/when/IP to `public.audit_log`, whose
UPDATE/DELETE trigger makes it append-only like the stock ledger. The actor comes from the
token claims, never the request. New controller exposing patient data → add its path to the
interceptor's rule table. An audit failure logs ERROR but never fails the request it records.

**A retried POST must not book or dispense twice.** Booking and counter-sale POSTs accept an
`Idempotency-Key` header; `IdempotencyService.execute` claims the key, runs the operation and
stores its response *in one transaction*, so a crash rolls back claim and work together, a
racer blocks on the PK and then replays the stored response, and a rolled-back operation
leaves the key spendable again. The Flutter side generates one key per attempt
(`newIdempotencyKey()`), reuses it across retries, and clears it **only on success**. Keys
prune after 48h. No header → runs untouched (old clients keep their old risk).

**A cached tenant is a tenant you cannot cut off.** `resolveTenantSchema` is `@Cacheable`
and its query only ever matches an *active* tenant — so the cache is the only thing that can
keep a suspended one alive. It used to sit in an unbounded `ConcurrentMapCacheManager` with
no TTL and no `@CacheEvict` anywhere in the codebase, which meant marking a tenant `inactive`
did nothing at all: their admin kept reading patient records until the process restarted. It
is now Caffeine with a **60s TTL** and a size bound, plus `@CacheEvict` on `updateTenant` /
`deleteTenant`. The TTL is the correctness guarantee and the evict is only the fast path — an
evict clears one Cloud Run instance's map, so without the TTL every *other* instance keeps
serving the suspended tenant forever. This is not the TTL that was banned from the pharmacy
catalog: that was a staleness cache over data that changes on every sale, this is the ceiling
on how long a cut-off customer keeps working. `TenantModuleService` stays deliberately
uncached — read its class comment before changing that.

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

**Reports are counted, never estimated.** `GET /admin/{tenant}/reports?period=today|week|
month|year` (`AdminDomainService.report`) counts every figure from that tenant's own rows
for the window asked for — visits by status, new patients, prescriptions, the busiest
hour, the day-by-day trend, and revenue as the sum of *the treating doctor's own fee* over
completed visits (`consultation_fee` if stamped, else the digits of `doctor.fee`). The
Reports tab used to read the all-time overview counters and multiply completed visits by a
flat ₹500, so it showed the same numbers every day whichever period button was pressed. A
doctor with no fee on file contributes 0, and the tab says so rather than inventing a
number.

**Anything labelled with a time-word is counted for that window.** The Dashboard's
"Today at a Glance" reads `report('today')` — the same counted path as Reports, so the two
tabs cannot disagree. `overview()` is all-time and its labels now say so ("Total patients",
"Upcoming appointments"). It called an all-time patient count **"Daily visits"**, which the
dashboard rendered as "Today's Patients" under a LIVE badge: a hospital saw its lifetime
total (18) where the truth was 0, and it never moved. Being all-time was fine; rendering it
as *today* was the bug. Never source a today/this-week number from `overview()`.

**A tenant accepts the Terms once, and it is recorded.** `tenant_registry.terms_version /
_accepted_at / _accepted_by`, owned by `TermsService` (which also holds `CURRENT_VERSION`).
The document is served from the API (`GET /api/v1/public/terms`) rather than baked into the
app, so a revision reaches an installed APK without a release. Consent is captured either at
onboarding (the platform-admin form's checkbox, ticked by default) or, for a tenant that has
none, by a one-time blocking sheet on the first screen its admin lands on — `maybeAskForTerms`
in `admin_dashboard_screen` and `pharmacy_shell_screen`. `/capabilities` carries
`termsAccepted` so login needs no extra round-trip. Bumping `CURRENT_VERSION` re-asks every
customer; do it only when the agreement's meaning changes.

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

**A restored session carries no capabilities — never route on them without asking.**
`AuthNotifier.restore()` rebuilds the session from secure storage, but capabilities are
deliberately not persisted (a stale module flag must not outlive a session). So on the cold
start that follows the OS killing a long-idle app, `isPharmacyOnly` reads false and a
*pharmacy* owner is routed to `/admin`. That is what produced the "black screen after an
hour": the hospital dashboard then took its tenant id from `hospitalProvider` — which only a
hospital *search* fills, so for a pharmacy user it was empty — and asked for
`/admin//overview`. An empty path segment matches no handler, Spring answers **401**, and the
global 401 handler reads that as "your token died" and wipes the session. One unset id
silently destroyed a good login. Screens that can be reached by a restored session must
settle capabilities *before* they load anything module-specific (`_bootstrap()` in
`AdminDashboardScreen`), take the tenant from `auth.tenantPublicId` (the session) rather than
`hospitalProvider` (the last thing browsed), and `ApiClient` now refuses to send any path
containing `//` so this class of bug fails loudly and locally instead of logging the user out.

**The public tenant directory is module-filtered, in SQL.** `GET /api/v1/public/tenants`
takes `?module=clinical` (Search Hospitals) or `?module=pharmacy` (Search Pharmacies);
anything else lists everything, so an old client still works. Each `TenantSummary` also
carries `hasClinical` / `hasPharmacy`, because a tenant is a *set* of modules — a hospital
with a dispensary is a truthful result in **both** lists, not a bug. Filter in the query, not
in memory: the directory is what every anonymous visitor hits first.

**One appointment queue.** Every booking — slot or token, from any of the four channels
(patient app, IP-Staff, QR portal, chatbot) — draws a token from the same
per-`(doctor, date, session)` counter, and every channel funnels through
`PatientDomainService.bookAppointment`. Put cross-channel behaviour there, once.

**A slot is booked once, and the database says so.** The check-then-insert in
`bookAppointment`/`rescheduleAppointment` ("is this slot free?" then insert) is a race —
two parallel requests both read free and both insert. The real arbiter is a *partial
unique index* (tenant `V13`) on `(doctor_public_id, appointment_slot)` `WHERE
appointment_status = 'upcoming' AND booking_type = 'SLOT'`; the save is a `saveAndFlush`
so the violation surfaces there (converted to "slot already booked"), not at commit. The
index is scoped on purpose: **TOKEN bookings deliberately share a session-start slot
string** (every morning token is `"<date> 09:00"`), so a naive unique index on
`(doctor, slot)` would reject the second token of a session. A plain unique index here is
a bug; keep the `booking_type='SLOT'` predicate.

**Booking source is whitelisted.** `normalizeBookingSource` silently maps anything it
doesn't recognise to `PATIENT_APP`. Add new sources to that switch or they vanish from
the admin channel analytics. Current set: `QR_CODE`, `IP_STAFF`, `CHATBOT`, `ABDM`.

**Queue ETAs are measured, never guessed.** `appointment.completed_at` (tenant V14) is
stamped once when a consult completes; `measuredConsultPace` averages the gaps between a
doctor's consecutive completions today (only 2–45 min gaps count, so a lunch break
doesn't) and that number replaces the old hardcoded `tokensAhead * 10` /
`avgConsultMinutes = 15`. The day view carries per-facet `estimatedCallAt` (live day
only), `QueueStatusView` carries a real wait + call time, and the queue board shows when
the session clears. Completing a consult also enqueues a WhatsApp "your turn is near"
nudge to the patient ~3 tokens back — event-driven from `completeAppointment`, deduped by
the outbox's (tenant, type, reference) key, and never allowed to fail the completion.

**The refill loop is counted from the store's own sales.** `RefillReminderService`
(pharmacy module) derives a purchase rhythm per (customer mobile, SKU) — ≥2 purchase
days, cadence = span/intervals bounded to 7–120 days (cast `::int`: date + bigint has no
operator) — and opens one cycle per rhythm in `refill_reminder` (tenant V15), made
idempotent by a partial unique index over open cycles. Due cycles get a WhatsApp nudge
(direct outbox insert — pharmacy never imports the patient module) and appear as the Sell
tab's "Refills (n)" worklist (`/pharmacy/{t}/refills/due`); a newer sale auto-fulfils the
cycle. The scan runs from `/internal/jobs` (hour ≥ 8 IST, per-instance day guard) and a
08:30 cron twin; every statement is safe to re-run.

**The voice scribe drafts; the doctor authors.** `POST /api/v1/doctors/{t}/scribe`
(`ScribeService`) sends a device-transcribed dictation to the Claude API
(`claude-opus-4-8`, structured-output JSON schema — raw `java.net.http` like
WhatsAppService, never an SDK) and returns a draft the consultation form pre-fills;
nothing is saved or sent by the endpoint, and audio never leaves the phone
(`speech_to_text` on-device, en/hi/te). Inert until `SEVACARE_ANTHROPIC_API_KEY` is set:
the endpoint 503s and `/capabilities` reports `voiceScribe: false`, which is the only
thing that makes the mic visible. For a pharmacy tenant, drafted medicines are matched
against the store's own `medicine_sku` so the prescription is dispensable as typed. The
scribe path is in `AuditLogInterceptor`'s rule table.

**ABDM ships dark until registered.** `/api/v1/abdm/**` (Scan & Share webhook +
status) answers 404 until `SEVACARE_ABDM_CLIENT_ID`/`_SECRET` exist — the jobs-token
pattern. A profile share maps `metadata.hipId` → `tenant_registry.abdm_hip_id` (public
V44) and rides the existing `submitAppointmentRequest` pipeline with source `ABDM`
(auto-token, front-desk inbox). The path is tenant-free: it is in `TenantHeaderFilter`'s
skip list, Security's permit list, and the public-POST rate-limit bucket — a path missing
any of those surfaces as a confusing 401. `patient.abha_number/_address` (tenant V16)
exist but aren't in any form yet. Operator steps live in `docs/abdm/ABDM_INTEGRATION.md`.

**Times are IST.** The JVM default is set in `SevaCareApiApplication` and Hikari runs
`SET TIME ZONE 'Asia/Kolkata'` on every connection, because Cloud SQL defaults to UTC.
That same `connection-init-sql` also sets `statement_timeout` / `lock_timeout` /
`idle_in_transaction_session_timeout` (env-overridable) so one runaway query or a stuck
lock cannot pin a pooled connection and starve every request. Raise them for a deliberately
long migration/backfill; do not remove them. The app also runs `server.shutdown: graceful`
so a Cloud Run SIGTERM lets an in-flight booking/sale finish instead of being severed.

**The doctor's queue ships attachment metadata, never the bytes.** That day view is polled
every 20 s; it used to re-send every patient-uploaded prescription's full base64 on every
poll. The facet now carries only `AttachmentView` metadata (`dataBase64` null) via a closed
projection (`AppointmentAttachmentRepository.findMeta…`), and the image is pulled once, on
open, from `GET /patients/{t}/attachments/{id}` (Flutter `_AttachmentImage`, cached). Do not
put the bytes back in the facet. For the same reason, list/queue reads use the photo-free
`PatientRepository.PatientCard` projection — loading full `Patient` entities dragged the
`photo_base64` TEXT column along too.

**`appointment_slot` is a string** in `yyyy-MM-dd HH:mm` form, so a lexicographic
comparison is also a chronological one — range queries in SQL are safe.

**Uploaded files live in the database, never on disk.** Cloud Run's filesystem is
per-instance and wiped on restart, so a file written there is unreadable from the next
instance and gone after a deploy — onboarding documents used to vanish this way.
`OnboardingDocumentService` stores bytes in `tenant_onboarding_document.file_bytes`
(small one-time uploads; they ride the DB's own backups at no extra cost). Any new
upload feature gets the same treatment until an object store is deliberately adopted.

**`@Scheduled` does not run reliably on Cloud Run.** Request-based billing throttles
CPU to near-zero between requests, so background timers fire late or never on a quiet
instance. Every background job is therefore also runnable via
`POST /internal/jobs/run` (shared-secret header `X-Jobs-Token` = `SEVACARE_JOBS_TOKEN`,
unset → 404), driven by one free-tier Cloud Scheduler job every 5 minutes — see
DEPLOYMENT.md. Double-running with the timers is safe (SKIP LOCKED claims, dedupe
checks, idempotent prunes); a new background job must keep that property and be added
to `InternalJobsController`. The endpoint is tenant-free: it is in
`TenantHeaderFilter`'s skip list, and a path missing from that list that carries no
`X-Tenant-Id` surfaces as a 401 (the 400 error-dispatches into the protected `/error`).

**Boot skips tenant schemas that are already current.** `migrateAll` probes each
schema's `flyway_tenant_history` max version with one cheap query and only runs full
Flyway (connection + lock + validation, ~200ms each) for stale schemas — otherwise
every instance start would pay one Flyway per tenant, turning scale-out during a spike
into minutes of cold start. Anything doubtful takes the full path;
`provisionTenant` always does.

**Filter and window in SQL, never in memory.** The doctor's day queue
(`getDoctorQueueForDate`, polled every 20s) is cut with a slot BETWEEN on
`(doctor_public_id, appointment_slot)` (index in tenant V12), the follow-up badge is
one batch `findPatientIdsSeenBefore` query, and the doctor's patient list is a SQL
GROUP BY. Do not reintroduce `findByTenant…()`-then-filter — several of those loaded a
tenant's entire appointment history per request.

**Production logs are structured JSON** (`logging.structured.format.console: ecs` —
`gcp` is NOT a valid Spring Boot format and crashes startup with "Unknown format 'gcp'";
only `ecs`/`gelf`/`logstash` are built in), so
Cloud Logging parses severity — log-based metrics/alerts (e.g. `cross_tenant_denied`)
depend on it. Flutter crash reporting is Sentry, inert unless the build passes
`--dart-define=SENTRY_DSN=…`; its init is crash-only and must never attach request
bodies or screenshots (PHI).

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
