# WhatsApp notifications

Paper prescriptions still print. This adds a parallel digital copy on the channel
patients already have open, plus the reminders that used to depend on somebody at the
hospital remembering to call.

## What gets sent

| Message | Triggered by | When it goes out |
|---|---|---|
| `APPOINTMENT_CONFIRMED` | Any booking — patient app, IP-Staff, QR portal, chatbot | Immediately |
| `PRESCRIPTION` | Doctor completes a consultation with the WhatsApp checkbox on | Immediately |
| `FOLLOW_UP_REMINDER` | The same consult, when a follow-up interval was chosen | 9:00 AM IST on the follow-up date |

All four booking channels funnel through `PatientDomainService.bookAppointment`, so the
confirmation is enqueued in exactly one place and no channel can be forgotten.

## How it works

Messages are written to `public.whatsapp_outbox` **inside the transaction that produced
them**. A booking that rolls back cannot leave a queued message behind, and a WhatsApp
outage cannot fail a consult — `WhatsAppService.enqueue` swallows its own errors by
design.

`drainOutbox()` runs every 60 seconds. It claims a batch with `FOR UPDATE SKIP LOCKED`
and an atomic `PENDING → SENDING` flip, so several Cloud Run instances can drain the same
outbox without double-sending, and no transaction is held open across the provider HTTP
call. Failures back off in growing 5-minute steps and give up after 5 attempts. A crashed
instance's rows are re-queued after 15 minutes in `SENDING`.

Because a row carries its own `scheduled_at`, a follow-up reminder is queued weeks in
advance at consult time rather than needing a nightly job that rescans medical history.

Uniqueness on `(tenant_public_id, message_type, reference_id)` means a retried upload or a
re-run sweep can never send the same message twice.

## Configuration

Delivery uses the Meta WhatsApp Cloud API. Set both of these on the Cloud Run service to
turn sending on:

```
SEVACARE_WHATSAPP_PHONE_NUMBER_ID=<Cloud API phone number id>
SEVACARE_WHATSAPP_ACCESS_TOKEN=<permanent system-user token>
```

Optional: `SEVACARE_WHATSAPP_ENABLED` (default `true` — controls queuing),
`SEVACARE_WHATSAPP_API_BASE` (default `https://graph.facebook.com/v20.0`),
`SEVACARE_WHATSAPP_COUNTRY_CODE` (default `91`, prepended to bare 10-digit numbers),
`SEVACARE_WHATSAPP_DRAIN_INTERVAL_MS` (default `60000`).

**Until the credentials are set, nothing is sent.** Due rows are parked as `NO_PROVIDER`
rather than retried forever, and each keeps a ready-to-use `wa.me` deep link in `wa_link`.
A hospital can adopt WhatsApp later and still see (or replay) the whole backlog.

Note that the Cloud API only permits free-form `text` messages inside a 24-hour customer
service window. For messages sent outside that window — a follow-up reminder weeks later
is the obvious case — Meta requires a pre-approved message template. Registering
templates and switching `send()` from `type: text` to `type: template` is the next step
whenever real credentials are wired up.

## Doctor control

The consultation screen carries a **"Send prescription on WhatsApp"** checkbox, enabled by
default. It is opt-out rather than opt-in: paper is now the exception, so the doctor only
touches the control when a patient asks them to. The choice rides along on the prescription
upload as `sendWhatsapp` and governs both the prescription message and its follow-up
reminder. Appointment confirmations are not gated by it — those belong to the booking, not
the consult.

## Operating it

```sql
-- What's stuck, and why
SELECT status, count(*), max(last_error) FROM public.whatsapp_outbox GROUP BY status;

-- Replay everything that was parked before credentials existed
UPDATE public.whatsapp_outbox SET status = 'PENDING', attempts = 0 WHERE status = 'NO_PROVIDER';
```
