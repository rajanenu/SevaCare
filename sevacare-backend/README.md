# SevaCare Backend

Spring Boot contract-first backend for the SevaCare frontend flows.

## Current Stack

- Java 21
- Spring Boot 3.4.x
- Virtual threads enabled
- Spring Web, Validation, Security, Cache, Actuator
- Flyway
- PostgreSQL

## Local Notes

- OTP is intentionally hard-coded to `0000` for local development.
- Tenant isolation is designed around one schema per tenant, for example `tenant_t_1001`.
- Public IDs follow prefixed formats: `T-1001`, `P-1001`, `D-1001`, `A-1001`.

## Main Files

- `pom.xml`
- `src/main/resources/application.yml`
- `src/main/resources/db/migration/V1__core_bootstrap.sql`
- `docs/domain-contracts.md`

## Next Backend Steps

- Replace in-memory contract data with repositories backed by PostgreSQL.
- Add JWT or session-based auth after local OTP flow is validated.
- Add outbox and async messaging where tenant workflows need decoupling.
- Add Micrometer tracing and structured audit events before production rollout.