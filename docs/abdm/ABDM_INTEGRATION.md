# ABDM / ABHA Integration

Status: **foundation built, inert until registered.** The code ships dark — without
ABDM credentials every `/api/v1/abdm/**` endpoint answers 404 (the same pattern as
`/internal/jobs`), `tenant_registry.abdm_hip_id` stays NULL, and nothing changes for
any user.

## What is built

| Piece | Where | What it does |
|---|---|---|
| Scan & Share webhook | `POST /api/v1/abdm/share` (alias `/api/v1/abdm/v0.5/patients/profile/share`), `AbdmController` | Receives the gateway's profile-share callback, maps `metadata.hipId` → tenant via `tenant_registry.abdm_hip_id`, and funnels the patient into the existing `submitAppointmentRequest` pipeline with booking source `ABDM` — same auto-token intake as the QR portal. Acks with the request id. |
| Facility mapping | public migration `V44__tenant_abdm_hip_id.sql` | `tenant_registry.abdm_hip_id` (unique when set): the Health Facility Registry id ABDM knows this facility by. |
| Patient ABHA fields | tenant migration `V16__patient_abha.sql`, `Patient` entity | `patient.abha_number` (14-digit, hyphenated) and `patient.abha_address` (`name@abdm`), both optional. Ready for the M1 link/verify flows; not yet surfaced in the app's forms. |
| Booking analytics | `normalizeBookingSource` | `ABDM` is a first-class booking source — Scan & Share walk-ins show up in the admin channel analytics instead of being lumped into `PATIENT_APP`. |
| Plumbing | `TenantHeaderFilter` skip list, Security permit list, `RateLimitFilter` | The webhook is tenant-free and unauthenticated by nature, so it is rate-limited with the public-booking bucket (30/min/IP) and 404s while unconfigured. |

## Environment variables

| Variable | Meaning |
|---|---|
| `SEVACARE_ABDM_CLIENT_ID` / `SEVACARE_ABDM_CLIENT_SECRET` | Gateway credentials issued at sandbox/production registration. Both set ⇒ endpoints go live. |
| `SEVACARE_ABDM_BASE_URL` | Gateway base. Default `https://dev.abdm.gov.in/gateway` (sandbox); switch for production. |

## What only the operator can do (in order)

1. **Register on the ABDM sandbox** (https://sandbox.abdm.gov.in) as a Health
   Information Provider — this issues the client id/secret. Certification has weeks
   of lead time; start early.
2. **Enrol each facility in the Health Facility Registry** to get its HFR/HIP id,
   then record it: `UPDATE public.tenant_registry SET abdm_hip_id = '<HFR-ID>' WHERE
   tenant_public_id = 'T-xxxx';`
3. **Register the callback URL** with ABDM: `https://<api-host>/api/v1/abdm/share`.
4. Print the facility's **ABDM counter QR** (generated from the sandbox console) at
   reception. Patients scan it with any PHR app; the flow above does the rest.

## Deliberately not built yet

- **Gateway request signing/verification** — production ABDM signs callbacks; the
  verify step belongs with the certification work when real credentials exist to
  test against. Until then the endpoint's exposure equals the public QR booking
  form's (rate-limited, creates only a pending front-desk request).
- **M1 (ABHA create/verify by OTP), M2 (care-context linking), M3 (consent-based
  record sharing)** — each is its own certification milestone. The patient columns
  and the credential plumbing here are the substrate they'll build on.
- **App-side ABHA capture** — the columns exist; adding the optional field to the
  registration forms is a small follow-up once ABHA numbers actually flow.
