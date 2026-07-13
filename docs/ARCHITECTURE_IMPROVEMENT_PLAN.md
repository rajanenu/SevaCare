# SevaCare — Architecture, Security and Scale Plan

**Reviewed:** 2026-07-13 · **Reviewer role:** principal architect / healthcare domain
**Status of this document:** three findings below are already **fixed and verified**; the rest is ranked work.

---

## The headline

SevaCare is architecturally in better shape than most products at this stage. The module model
(`clinical_enabled` + `pharmacy_profile_key`, 404-not-403), the append-only stock ledger with DB-level
tripwires, the version-stamped catalog ETag, and the one-queue booking rule are all genuinely good
decisions, documented and defended.

But it is a **multi-tenant system holding patient health records**, and the tenant boundary itself —
the one invariant the whole product rests on — was not enforced. One hospital could read every other
hospital's patient list. That is now closed.

The pattern behind the three defects found is one idea:

> **Everything that decides *who you are* was trusted from the client, and everything that decides
> *whether you still count* was cached forever.**

Identity came from a header the caller typed. Revocation never arrived. Authority never expired.
Each is cheap to fix on its own; together they mean the platform had no way to contain a bad actor.

---

## Part 1 — Fixed and verified in this pass

### 1.1 Cross-tenant PHI breach 🔴 CRITICAL — **FIXED**

**What it was.** `TenantHeaderFilter` turned the client-supplied `X-Tenant-Id` header straight into the
Postgres schema every query then ran against. The auth token *carries* the tenant the user logged into —
and nothing ever compared the two.

**Proven, not theorised.** A real admin token for `T-1013`, replayed with `X-Tenant-Id: T-1017`:

```
GET /api/v1/admin/T-1017/patients      →  HTTP 200
{"patients":[{"fullName":"Lakshmi Devi","mobileNumber":"7000000012","age":55, …
GET /api/v1/admin/T-1017/users         →  HTTP 200   (staff names + mobile numbers)
```

Full patient list of another hospital: names, mobile numbers, gender, age, visit history.

**Why the existing guards did not catch it.** The `"Tenant mismatch"` check is copy-pasted ~100 times
across the controllers — but it compares the **path variable** against `TenantContext`, and
`TenantContext` came from the **header**. Both are chosen by the caller. Those 100 checks only ever
verified *that the client agreed with itself*.

**The fix.** [`TenantAccessFilter`](../sevacare-backend/sevacare-api/src/main/java/com/sevacare/api/security/TenantAccessFilter.java)
— one filter, between the token filter and the module gate, that pins the request's tenant to the
token's tenant.

- **403, not 404.** Unlike `ModuleAccessFilter` (where 404 hides what a customer bought), the tenant
  directory is already public via `GET /api/v1/public/tenants`, so concealing a tenant's existence buys
  nothing. And deliberately not 401 — the app signs the user out on 401, and a cross-tenant probe must
  not be able to destroy a good session.
- **Platform admin is denied too.** Their token's tenant is the sentinel `"platform"`, and every
  operator endpoint lives under `/api/v1/platform-admin` (which carries no tenant context). So they lose
  nothing, and a stolen operator token cannot be aimed at a customer's schema.
- Logged at **WARN** (`cross_tenant_denied`): no real client can produce this, so it is either an attack
  or a leak-shaped bug. It is the first alert to wire to a pager.

**Verified after the fix:**

| Request | Before | After |
|---|---|---|
| `T-1013` token → `T-1017` patients | 200 + full PHI | **403** |
| `T-1013` token → `T-1017` overview | 200 | **403** |
| `T-1019` store token → `T-1013` pharmacy | 200 | **403** |
| `T-1013` token → **own** patients | 200 | **200** (unchanged) |
| Pharmacy counter, own store | 200 | **200** (unchanged) |

6 unit tests + the full 72-test backend suite green.

> The ~100 per-controller `"Tenant mismatch"` checks are now **defence in depth** rather than the only
> line of defence. Leave them; they are cheap and they are a second wall.

### 1.2 A suspended tenant could not be cut off 🔴 CRITICAL — **FIXED**

**What it was.** `resolveTenantSchema` is `@Cacheable("tenantSchemas")` — and there was **not one
`@CacheEvict` in the entire codebase**, in an unbounded `ConcurrentMapCacheManager` with **no TTL**.

The lookup only ever matches an *active* tenant, so the cache was the only thing keeping a suspended one
alive. Proven on the local DB:

```sql
UPDATE tenant_registry SET tenant_status='inactive' WHERE tenant_public_id='T-1013';
```
```
GET /api/v1/admin/T-1013/patients  →  HTTP 200   ← still reading records, indefinitely
```

Suspending for non-payment, offboarding a customer, or cutting off a **breached** tenant did nothing on
any running instance, forever. Combined with tokens that never expire (§2.2), there was **no way to
revoke access at all**.

**The fix.** Caffeine, with a 60-second TTL and a size bound, plus `@CacheEvict` on `updateTenant` /
`deleteTenant`.

The TTL is the correctness guarantee, and the evict is only the fast path — an evict clears the map on
*one* Cloud Run instance, so without a TTL the other instances would keep serving the suspended tenant
forever. **Verified:** suspended tenant → still 200 inside the TTL window → **401 after it** → 200 again
once reinstated.

> This is *not* the TTL that was banned from the pharmacy catalog. That one was a staleness cache over
> data that changes on every sale, correctly replaced by a version read from the data. This is a
> **revocation bound** — the ceiling on how long a cut-off customer keeps working.

Also removed four cache names (`tenantDiscovery`, `doctorDirectory`, `patientViews`, `adminViews`) that
nothing was ever `@Cacheable` on. A cache name nobody uses reads like a performance story that was never
told. `TenantModuleService` stays **deliberately uncached** — its own doc comment argues that case well,
and a primary-key lookup on a one-row-per-tenant table is genuinely cheap.

### 1.3 The 70MB APK 🟡 — **FIXED: 65.6MB → 22.8MB**

Your instinct was right, and the cause is exact: **`flutter build apk --release` produces a universal
APK containing three complete copies of the app** — one per CPU architecture (`armeabi-v7a`, `arm64-v8a`,
`x86_64`), each with its own ~11MB engine and ~10MB of compiled Dart.

```
default universal build           65.6 MB   ← what you saw
arm64 only + obfuscated           22.8 MB   ← now, at the required app-release.apk path
```

`--target-platform android-arm64` alone removes ~40MB. Adding `--obfuscate --split-debug-info` strips
debug symbols out of `libapp.so` (11.4MB → 9.7MB) and, as a bonus, makes the shipped Dart much harder to
reverse-engineer — which matters for an app that talks to a health API.

**What the 22.8MB actually is, and the floor:**

| | |
|---|---|
| `libflutter.so` — the Flutter engine | 11.3 MB — **fixed cost, immovable** |
| `libapp.so` — all your Dart, AOT-compiled | 9.7 MB |
| `classes.dex`, resources, assets | ~1.8 MB |

**≈18–20MB is the floor for any Flutter app.** 22.8MB is normal and healthy. Chasing it further has poor
returns — with one exception below.

**Remaining, easy: ~0.5MB of dead font.** `font_awesome_flutter` is a direct dependency used for
**exactly one icon** (the WhatsApp mark, 3 call sites in `pharmacy_shell_screen.dart`). Icon tree-shaking
runs and shrinks the *Brands* font it actually uses to **1.6KB** — but FontAwesome's **Solid (401KB)** and
**Regular (85KB)** fonts ship at *full size*, because nothing references them at all, so the shaker never
processes them. 486KB of pure dead weight. Removing the dependency requires drawing the WhatsApp glyph as
a small `CustomPainter` path; worth doing, but do it deliberately — the green WhatsApp mark is meaningful
to Indian pharmacy users and should not be swapped for a generic chat bubble.

**Distribution, which matters more than the number:**
- Ship the **`.aab`** to Play (`flutter build appbundle`). The 47MB bundle is the *upload* artifact — Play
  slices it and each device downloads only its own ABI. Never upload a universal APK.
- Keep `--split-per-abi` for any APK you hand out directly (arm64 22.6MB / armv7 20.7MB).

---

## Part 2 — Security: the ranked backlog

> Framing: SevaCare stores name, mobile, age, gender, diagnosis, prescriptions and payment against
> identified individuals. Under India's **DPDP Act 2023** that is sensitive personal data, and a breach
> carries penalties up to ₹250 crore. The bar is not "typical SaaS". Plan for **ABDM/NDHM** alignment
> as the product grows.

### 2.1 🔴 The OTP is `0000` for every user, everywhere

```java
public static final String DEFAULT_OTP = "0000";   // OtpService
```

No OTP is sent. Anyone who knows a registered mobile number — and patient/staff numbers are *visible in
the app* — can log in as that doctor, that admin, or that **platform admin**, in one request. This is not
a weak password; it is **no authentication at all**. It is, today, a bigger hole than the one just fixed.

I did not change it in this pass because it is the demo login the whole team and your pilot customers are
using, and silently breaking every login is not my call. It is the **single most important thing to do
next**, and it must be done before real patient data goes in.

**Plan.**
1. Integrate a real SMS provider (MSG91 / Gupshup / Twilio — MSG91 is the pragmatic Indian default).
2. Generate a 6-digit cryptographically random OTP; store a **hash** (never plaintext, as
   `user_otp_override` does today); 5-minute expiry; single-use; invalidate on use.
3. **Rate-limit**: max 3 sends per number per 15 min, max 5 verify attempts before lockout. Without this,
   even a 6-digit OTP falls to brute force in minutes.
4. Keep a `sevacare.auth.dev-otp-enabled` flag, **hard-off in the `production` profile**, so local dev and
   demos keep the `0000` convenience without it ever being a production code path.

### 2.2 🔴 Tokens never expire and cannot be revoked

```java
payload = tenantPublicId + "|" + role + "|" + subjectPublicId   // TokenService
```

Base64 + HMAC-SHA256. No `exp`, no `iat`, no `jti`. Consequences:

- A token captured **once is valid forever** — from a shared laptop, a support screenshot, a proxy log.
- Logging out is a **client-side illusion**: the app deletes the token, the server would still accept it.
- The only revocation lever is rotating `SEVACARE_AUTH_SECRET`, which logs out **every customer at once**.
- No `alg` header and a hand-rolled `split("|")` parser — a payload containing `|` would mis-parse.

**Plan.** Move to real JWTs (`io.jsonwebtoken` / Nimbus): `sub`, `tenant`, `role`, `iat`, **`exp` (~30–60
min)**, `jti`. Add a **refresh token** (30 days, rotating, stored server-side and revocable) so a session
survives without an immortal access token. Keep a small `revoked_jti` table for real logout and forced
sign-out. The Flutter client already handles 401 by re-authenticating, so the refresh flow slots in with
little UI change.

### 2.3 🔴 The release APK is signed with the **debug** key

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        signingConfig = signingConfigs.getByName("debug")   // android/app/build.gradle.kts
    }
}
```

The Android **debug keystore is a publicly known private key**. Anyone can build an APK that a device
accepts as an *update* to SevaCare. Play Store will also refuse the upload. Generate a real keystore, keep
it in Secret Manager (never in git), wire `key.properties`, and enable **Play App Signing**.

### 2.4 🟠 No rate limiting anywhere

Nothing throttles OTP requests, login, QR booking, or the public chatbot. Costs: OTP brute-force (§2.1),
SMS-pumping fraud once real SMS is wired (each attempt costs money), and trivial DoS on the public
booking endpoints. **Plan:** Bucket4j or a Redis token bucket; strictest on `/auth/**` and the public
booking/chatbot routes, keyed by mobile number *and* IP.

### 2.5 🟠 No audit trail

Under DPDP — and for basic clinical safety — you must be able to answer *"who read this patient's record,
and when?"*. Today nothing records a read. **Plan:** an append-only `audit_log` (actor, tenant, action,
subject, timestamp, IP) written for every PHI read/write. You already have the right instincts here — the
stock ledger is append-only with DB triggers; apply the same discipline to record access.

### 2.6 🟠 Security headers and CORS

`Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy` are
all unset (add to `nginx.conf` and Spring). CORS allows `*` headers and, in local config, wildcard LAN
origins — fine for dev, but make sure `SEVACARE_CORS_ORIGINS` in production is an exact list. `csrf.disable()`
is correct for a stateless bearer-token API — keep it.

### 2.7 🟡 PHI at rest, and in logs

Patient mobile numbers and names sit in plaintext columns. Consider column-level encryption (pgcrypto) or
at minimum confirm Cloud SQL CMEK + audited backups. Separately, sweep logs for PII — several handlers log
mobile numbers, which then live in Cloud Logging for 30 days.

### 2.8 🟡 `health.show-details: always` in the base profile

Production correctly overrides to `never`, but the default leaks DB vendor and disk paths to anyone who
finds a non-production instance. Flip the default to `never` and opt *in* locally.

---

## Part 3 — Scalability

The stated goal is *"every request behaves with the same speed and quality under heavy traffic."*
The architecture is sound; these are the things that will bite first.

### 3.1 🟠 The connection pool is the real ceiling

`maximum-pool-size: 5` per instance against a **`db-g1-small`** Cloud SQL (~200 connections max). So you
top out around **~40 instances** before Postgres starts refusing connections — and Cloud Run will happily
scale past that and turn a traffic spike into a **hard outage**, not a slowdown.

**Plan:**
1. Set `--max-instances` on Cloud Run to a number your DB can actually support (start ~30) — a queue is
   survivable, connection exhaustion is not.
2. Size the DB up (`db-custom-2-7680`) before any real load; `db-g1-small` is a dev tier.
3. Then raise the pool. Note that **virtual threads are enabled**, so request threads are essentially free
   — the pool, not the thread pool, is your concurrency limit. This is the single most important
   scalability number in the system and it is currently set for a demo.

### 3.2 🟠 Cold starts break the "same speed every request" promise

Spring Boot on Cloud Run with `min-instances: 0` means the unlucky request that hits a cold instance waits
**10–20 seconds** — while a warm one takes 50ms. That *is* the inconsistency you are worried about.
**Plan:** `--min-instances=1` (2 for real traffic). It costs a few dollars a month and it is the difference
between a snappy product and a lottery. Consider CDS/AOT later if start time still hurts.

### 3.3 🟡 Reads that grow with the platform, not with the answer

The codebase has already fixed several of these (the module-filtered public directory, the counted
reports) — keep the rule and finish the sweep: **filter and paginate in SQL, never in memory.** Audit the
remaining `findByTenant…()` calls that materialise a whole table to count or filter it. `GET /admin/{t}/patients`
returns *every* patient — it needs a real page/limit before a hospital has 50,000 of them.

### 3.4 🟡 Per-request DB round-trips

Every module-scoped request pays one `tenant_registry` lookup (`manifestOf`) on top of the cached schema
resolution. That is a deliberate, documented trade (see §1.2) and it is fine — but it is a PK lookup you
pay on *every* request, so revisit it if profiling ever points here. Measure before you cache.

### 3.5 🟡 Observability

`prometheus` is exposed but nothing scrapes it. You cannot defend a latency promise you do not measure.
**Plan:** Cloud Monitoring dashboards for p50/p95/p99 by endpoint, DB pool saturation, and Caffeine hit
rate (`recordStats()` is now on). Alert on `cross_tenant_denied` — that one is a security page, not a
metric.

---

## Part 4 — Maintainability

### 4.1 The ~100 copy-pasted `"Tenant mismatch"` checks

The clearest maintainability smell in the codebase, and it is instructive: a **cross-cutting concern
implemented by copy-paste** was *both* the noisiest code in the controllers *and* — because it was at the
wrong layer, checking the wrong two things — no defence at all. A security rule repeated 100 times is a
security rule you cannot verify. It now sits in one filter, in one place, with tests.

**Rule going forward:** if a check must hold for *every* request, it belongs in the filter chain, not in
every method. Keep the controller guards as a second wall, but never let them be the first.

### 4.2 The gate is now four layers — write it down

```
TenantHeaderFilter        →  resolve X-Tenant-Id to a schema, set TenantContext
TokenAuthenticationFilter →  parse the bearer token, set the principal
TenantAccessFilter        →  ★ the session may only touch its own tenant (403)
ModuleAccessFilter        →  a module this tenant did not buy answers 404
@PreAuthorize             →  role check on the controller method
```

Added to `README.md` and `CLAUDE.md`.

### 4.3 Tests

72 backend tests, with real Testcontainers integration coverage on the pharmacy — genuinely good. The gap
is **security tests**: there was no test asserting that one tenant cannot read another's data, which is
why it was never noticed. `TenantAccessFilterTest` starts that file. Add an integration test that logs in
as tenant A and asserts 403 against tenant B, so this can never regress.

The `sevacare-e2e-test/` suite is dead except `api.spec.ts` (the UI specs target a frontend that no longer
exists). Either delete it or point it at the Flutter web build — a suite nobody can run is worse than none,
because it tells you tests exist.

### 4.4 Documentation

`README.md` is rewritten (was a stale "3 steps to start" script index; now: what SevaCare *is*, the module
model, the security chain, the conventions, and the deploy traps). `CLAUDE.md` remains the deeper
architecture record.

---

## Part 5 — Architectural principles the codebase was missing

You asked directly what principles are still missing. Ranked:

1. **Never trust the client for identity.** The whole breach in §1.1 is this one line. The tenant, the
   role and the subject must all come from the *signed token*, never from a header or a path the caller
   chose. The path/header may be *checked* against the token; it may never *be* the answer.

2. **Authority must expire, and must be revocable.** §1.2 and §2.2. A system that cannot cut off a user or
   a customer has no answer to a breach. Both revocation levers — token expiry and tenant suspension — were
   missing, and each was individually silent.

3. **Defence in depth, at the right altitude.** The 100 controller checks were depth without a foundation.
   Put the invariant in the chokepoint; keep the local checks as backup.

4. **Fail closed.** `OtpService` catches a DB error and *returns the default OTP* — an unreachable override
   table degrades into "everyone's OTP is `0000`". The comment says "must never lock everyone out", and the
   instinct (availability) is understandable, but for an **authentication** decision the correct failure is
   **closed**. Availability is not a reason to authenticate someone you cannot verify.

5. **Auditability.** You already believe in this — the stock ledger is append-only and enforced by
   triggers, and it is the best thing in the codebase. Extend that same conviction from *inventory* to
   *patient records*. Money is already treated as more sacred than PHI; in a healthcare product that is
   backwards.

6. **Idempotency.** Booking and counter-sale POSTs have no idempotency key. On a flaky Indian mobile
   network, a retried request is a **double booking** or a **double dispense** — and the ledger will
   faithfully record both. Accept a client-generated `Idempotency-Key` and dedupe on it.

7. **Observability as a feature.** See §3.5.

---

## Recommended order

| # | Work | Why now |
|---|---|---|
| **1** | ~~Cross-tenant isolation~~ | ✅ **done** |
| **2** | ~~Tenant revocation~~ | ✅ **done** |
| **3** | ~~APK 65.6 → 22.8MB~~ | ✅ **done** |
| **4** | ~~Self-set passcodes + rate limiting~~ (§2.1, §2.4) | ✅ **done** — BCrypt `user_passcode`, 5-attempt/15-min lockout, fail-closed, 30/min/IP; no SMS provider, no per-message cost |
| **5** | ~~JWT with expiry + refresh~~ (§2.2) | ✅ **done** — 60-min JWTs, rotating refresh tokens, `/auth/refresh` + `/auth/logout`, jti revocation, Flutter silent refresh |
| **6** | ~~Release signing key~~ (§2.3) | ✅ **done** — upload keystore outside the repo, `key.properties` git-ignored, cert verified on the built APK |
| **7** | ~~Pool + max-instances + min-instances~~ (§3.1, §3.2) | ✅ **done** — flags + ceiling math in DEPLOYMENT.md; applies on next deploy |
| **8** | ~~Audit log~~ (§2.5) | ✅ **done** — append-only `public.audit_log` + DB trigger, `AuditLogInterceptor` on PHI routes |
| **9** | ~~Idempotency keys~~ (§5.6) | ✅ **done** — transactional claim-and-replay on booking + counter-sale POSTs, client keys per attempt |
| **10** | ~~Security headers, pagination, PII-in-logs, e2e cleanup~~ | ✅ **done** — nginx CSP/HSTS/nosniff, health details hidden, patients list was already SQL-paginated, khata mobile masked, dead UI specs removed |

All ten are done (2026-07-13). The gate items (4–6) that blocked **real patient data** are closed;
what remains open by choice: column-level PHI encryption (§2.7) and observability dashboards (§3.5).

---

## Appendix — how the breach was proven

Kept deliberately, so it can be re-run as a regression check after any change to the filter chain.

```bash
# A legitimate admin of hospital T-1013
TOK=$(curl -s -X POST localhost:8080/api/v1/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d '{"tenantPublicId":"T-1013","role":"admin","mobileNumber":"9844221599","otp":"0000"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['token'])")

# Aimed at a DIFFERENT hospital. Must be 403. Was 200 + the full patient list.
curl -s -w '\n%{http_code}\n' -H "Authorization: Bearer $TOK" -H "X-Tenant-Id: T-1017" \
  localhost:8080/api/v1/admin/T-1017/patients
```
