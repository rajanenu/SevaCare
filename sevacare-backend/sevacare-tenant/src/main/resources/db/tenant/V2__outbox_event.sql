-- =============================================================
-- V2: Transactional outbox + in-process event bus.
--
-- The first migration that gets to assume the V1 baseline shape, so it is an
-- ordinary forward migration: no IF NOT EXISTS archaeology, no to_regclass
-- guards. (CREATE TABLE is still written IF NOT EXISTS only because a schema
-- may be re-migrated during development, not because drift is expected.)
--
-- Lives in the tenant schema, not public: a business transaction writes its
-- aggregate and its event row in the same transaction against the same schema,
-- which is what makes the dual-write problem impossible. See blueprint §9.
-- =============================================================

CREATE TABLE IF NOT EXISTS ${tenantSchema}.outbox_event (
    event_id         UUID          PRIMARY KEY,
    event_type       VARCHAR(80)   NOT NULL,
    schema_version   SMALLINT      NOT NULL DEFAULT 1,
    tenant_public_id VARCHAR(24)   NOT NULL,
    location_id      VARCHAR(32),
    aggregate_type   VARCHAR(48)   NOT NULL,
    aggregate_id     VARCHAR(64)   NOT NULL,
    -- `sequence` is a SQL keyword; the envelope field of that name maps here.
    sequence_no      BIGINT,
    actor            VARCHAR(48),
    occurred_at      TIMESTAMP     NOT NULL,
    recorded_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payload          JSONB         NOT NULL DEFAULT '{}'::jsonb,

    -- PENDING -> DISPATCHING -> PUBLISHED, or -> DEAD once attempts run out.
    status           VARCHAR(16)   NOT NULL DEFAULT 'PENDING',
    attempts         SMALLINT      NOT NULL DEFAULT 0,
    next_attempt_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_error       VARCHAR(500),
    published_at     TIMESTAMP
);

-- The dispatcher's only hot query: due rows, oldest first. Partial, because
-- PUBLISHED rows accumulate forever and must not bloat the index.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_outbox_event_due
    ON ${tenantSchema}.outbox_event (next_attempt_at)
    WHERE status IN ('PENDING', 'DISPATCHING');

-- Replay/debugging: "what happened to this sale?"
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_outbox_event_aggregate
    ON ${tenantSchema}.outbox_event (aggregate_type, aggregate_id);

-- ---------------------------------------------------------------
-- Per-consumer idempotency.
--
-- Delivery is at-least-once: a handler that succeeds and then loses its
-- connection before the event is marked PUBLISHED will see the event again.
-- One row per (event, consumer) is what makes the second delivery a no-op, and
-- it is per-consumer rather than per-event because one event may fan out to
-- several subscribers and only some of them may have failed.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ${tenantSchema}.outbox_event_consumption (
    event_id      UUID         NOT NULL,
    consumer_name VARCHAR(80)  NOT NULL,
    consumed_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id, consumer_name)
);

-- ---------------------------------------------------------------
-- Dead letters.
--
-- A poison event must never wedge the queue behind it, and must never be
-- silently dropped either: it is copied here with the error that killed it, and
-- an operator can requeue it after the bug is fixed. The source row stays as
-- DEAD so the aggregate's event history has no hole in it.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ${tenantSchema}.outbox_event_dead_letter (
    event_id         UUID          PRIMARY KEY,
    event_type       VARCHAR(80)   NOT NULL,
    tenant_public_id VARCHAR(24)   NOT NULL,
    aggregate_type   VARCHAR(48)   NOT NULL,
    aggregate_id     VARCHAR(64)   NOT NULL,
    payload          JSONB         NOT NULL DEFAULT '{}'::jsonb,
    attempts         SMALLINT      NOT NULL,
    last_error       VARCHAR(500),
    occurred_at      TIMESTAMP     NOT NULL,
    dead_lettered_at TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);
