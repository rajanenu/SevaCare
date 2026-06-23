#!/usr/bin/env bash
# Reset local database to exactly one active tenant for clean end-to-end testing
# Usage: ./scripts/reset-single-tenant.sh

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

TARGET_TENANT_ID="T-2001"
TARGET_TENANT_NAME="SevaCare Local Hospital"
TARGET_SCHEMA="tenant_t_2001"
TARGET_THEME="premium"

print_info "Resetting local data to a single tenant: $TARGET_TENANT_ID ($TARGET_TENANT_NAME)"

if ! command -v psql >/dev/null 2>&1; then
  print_error "psql not found. Install PostgreSQL client tools."
  exit 1
fi

PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" <<SQL
BEGIN;

DO \$\$
DECLARE rec RECORD;
BEGIN
  FOR rec IN SELECT tenant_schema_name FROM public.tenant_registry WHERE tenant_public_id <> '${TARGET_TENANT_ID}'
  LOOP
    EXECUTE format('DROP SCHEMA IF EXISTS %I CASCADE', rec.tenant_schema_name);
  END LOOP;
END\$\$;

DELETE FROM public.tenant_onboarding_document;
DELETE FROM public.tenant_onboarding_request;

INSERT INTO public.tenant_registry (tenant_public_id, tenant_name, tenant_theme_key, tenant_schema_name, tenant_status)
VALUES ('${TARGET_TENANT_ID}', '${TARGET_TENANT_NAME}', '${TARGET_THEME}', '${TARGET_SCHEMA}', 'active')
ON CONFLICT (tenant_public_id) DO UPDATE
SET tenant_name = EXCLUDED.tenant_name,
    tenant_theme_key = EXCLUDED.tenant_theme_key,
    tenant_schema_name = EXCLUDED.tenant_schema_name,
    tenant_status = 'active';

DELETE FROM public.tenant_registry WHERE tenant_public_id <> '${TARGET_TENANT_ID}';

COMMIT;

CREATE SCHEMA IF NOT EXISTS ${TARGET_SCHEMA};

CREATE TABLE IF NOT EXISTS ${TARGET_SCHEMA}.patient (
  patient_public_id VARCHAR(16) PRIMARY KEY,
  tenant_public_id VARCHAR(16) NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  mobile_number VARCHAR(24) NOT NULL,
  status VARCHAR(24) NOT NULL
);

CREATE TABLE IF NOT EXISTS ${TARGET_SCHEMA}.doctor (
  doctor_public_id VARCHAR(16) PRIMARY KEY,
  tenant_public_id VARCHAR(16) NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  specialty VARCHAR(120) NOT NULL,
  availability VARCHAR(120) NOT NULL,
  fee VARCHAR(32) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS ${TARGET_SCHEMA}.admin_user (
  admin_public_id VARCHAR(16) PRIMARY KEY,
  tenant_public_id VARCHAR(16) NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true
);

ALTER TABLE ${TARGET_SCHEMA}.admin_user ADD COLUMN IF NOT EXISTS mobile_number VARCHAR(24);
ALTER TABLE ${TARGET_SCHEMA}.admin_user ADD COLUMN IF NOT EXISTS email VARCHAR(160);
ALTER TABLE ${TARGET_SCHEMA}.admin_user ADD COLUMN IF NOT EXISTS name VARCHAR(160);

INSERT INTO ${TARGET_SCHEMA}.patient (patient_public_id, tenant_public_id, full_name, mobile_number, status)
VALUES ('P-2001', '${TARGET_TENANT_ID}', 'Test Patient', '9000000001', 'active')
ON CONFLICT (patient_public_id) DO NOTHING;

INSERT INTO ${TARGET_SCHEMA}.doctor (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
VALUES ('D-2001', '${TARGET_TENANT_ID}', 'Dr. Test', 'General Physician', 'Today · 6 slots left', '₹500', true)
ON CONFLICT (doctor_public_id) DO NOTHING;

INSERT INTO ${TARGET_SCHEMA}.admin_user (admin_public_id, tenant_public_id, full_name, active, mobile_number, email, name)
VALUES ('A-2001', '${TARGET_TENANT_ID}', 'Admin Test', true, '9000000003', 'admin@sevacare.local', 'Admin Test')
ON CONFLICT (admin_public_id) DO NOTHING;
SQL

print_success "Local tenant reset complete"
print_info "Single tenant: ${TARGET_TENANT_ID}"
print_info "Patient login mobile: 9000000001 (OTP 0000)"
print_info "Doctor login mobile: any value (OTP 0000)"
print_info "Admin login mobile: 9000000003 (OTP 0000)"
print_info "Platform admin mobile: 9844221599 (OTP 1599)"
