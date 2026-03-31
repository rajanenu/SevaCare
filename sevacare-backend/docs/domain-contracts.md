# SevaCare Domain Contracts

## Principles

- Tenant isolation is schema-first: each tenant uses its own PostgreSQL schema, for example `tenant_t_1001`.
- Public IDs are role-prefixed and at least four digits: `T-1001`, `P-1001`, `D-1001`, `A-1001`.
- Internal persistence should use UUID primary keys; public IDs are stable external references for UI and APIs.
- Admins can add or delete patients and doctors.
- Doctors can disable patients, but cannot delete patient records.

## API Surfaces

- `GET /api/v1/public/tenants`: tenant discovery for landing page.
- `GET /api/v1/public/tenants/{tenantPublicId}/doctors`: doctor listing after hospital selection.
- `POST /api/v1/auth/otp/request`: local OTP request. Current local OTP is `0000`.
- `POST /api/v1/auth/otp/verify`: authenticates a patient, doctor, or admin for local development.
- `GET /api/v1/patients/{tenantPublicId}/{patientPublicId}/home`: appointments and prescriptions.
- `GET /api/v1/doctors/{tenantPublicId}/{doctorPublicId}/dashboard`: doctor workload summary.
- `POST /api/v1/doctors/{tenantPublicId}/{doctorPublicId}/patients/{patientPublicId}/disable`: doctor-only patient disable action.
- `GET /api/v1/admin/{tenantPublicId}/overview`: admin overview metrics.
- `POST /api/v1/admin/doctors`: add doctor.
- `DELETE /api/v1/admin/{tenantPublicId}/doctors/{doctorPublicId}`: delete doctor.
- `POST /api/v1/admin/patients`: add patient.
- `DELETE /api/v1/admin/{tenantPublicId}/patients/{patientPublicId}`: delete patient.

## Data Model

- `public.tenant_registry`: master tenant lookup and schema name mapping.
- `tenant_<tenant_id>.patient`: tenant-scoped patient record.
- `tenant_<tenant_id>.doctor`: tenant-scoped doctor record.
- `tenant_<tenant_id>.admin_user`: tenant-scoped admins.
- `tenant_<tenant_id>.appointment`: appointment fact table between patient and doctor.
- `tenant_<tenant_id>.prescription`: doctor-issued prescription lines and notes.
- `tenant_<tenant_id>.patient_access_event`: audit trail for disables and future reinstatements.

## Operational Notes

- Virtual threads are enabled for request fan-out and async boundaries.
- Spring cache is enabled for discovery, doctor directory, and patient/admin summary views.
- Actuator endpoints are exposed for `health`, `info`, `metrics`, and `prometheus`.
- Spring Security is in local-development mode for now. Real authentication and authorization should move to JWT or session tokens before production.