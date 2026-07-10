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
