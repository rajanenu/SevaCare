import { execFileSync } from 'child_process';
import { expect, test } from '@playwright/test';

const API = 'http://localhost:8081/api/v1';
const QR_UUID = '550e8400-e29b-41d4-a716-446655440000';

// Local Postgres runs natively; set DB_CONTAINER to route psql through
// `docker exec` when the database lives in a container instead.
const DB_CONTAINER = process.env.DB_CONTAINER;
const DB_USER = process.env.DB_USER ?? 'postgres';
const DB_NAME = process.env.DB_NAME ?? 'seva_care';

function runSql(query: string): string {
  const psqlArgs = ['-U', DB_USER, '-d', DB_NAME, '-t', '-A', '-c', query];
  return DB_CONTAINER
    ? execFileSync('docker', ['exec', DB_CONTAINER, 'psql', ...psqlArgs], { encoding: 'utf8' }).trim()
    : execFileSync('psql', psqlArgs, { encoding: 'utf8' }).trim();
}

test.describe('QR appointment request flow with DB assertion', () => {
  test('submits QR appointment request and persists to public.appointment_request', async ({ request }) => {
    const runId = Date.now();
    const doctorPublicId = `D-QR${String(runId).slice(-6)}`;

    // The QR form lists the tenant's REAL doctors (its schema's doctor table),
    // not public.doctor_hospital_enrollment — enrollment ids never matched a
    // logged-in doctor, so QR bookings could not reach a doctor's inbox.
    runSql(`
      INSERT INTO tenant_t_2001.doctor
      (doctor_public_id, tenant_public_id, full_name, mobile_number, specialty, active)
      VALUES ('${doctorPublicId}', 'T-2001', 'Dr. QR ${runId}', '91${String(runId).slice(-8)}', 'Cardiologist', true)
      ON CONFLICT (doctor_public_id) DO NOTHING;
    `);

    const beforeCount = Number.parseInt(
      runSql("SELECT COUNT(*) FROM public.appointment_request WHERE tenant_public_id = 'T-2001';"),
      10,
    );

    const formDataResponse = await request.get(`${API}/public/qrcode/${QR_UUID}/form-data`);
    expect(formDataResponse.ok()).toBe(true);
    const formDataBody = await formDataResponse.json();
    const doctors = formDataBody?.data?.availableDoctors as Array<{ doctorPublicId: string }>;
    expect(Array.isArray(doctors)).toBe(true);
    expect(doctors.length).toBeGreaterThan(0);

    const selectedDoctorId = doctorPublicId;
    const preferredDate = new Date().toISOString().slice(0, 10);
    const patientName = `QR Patient ${runId}`;

    const submitResponse = await request.post(`${API}/public/qrcode/${QR_UUID}/appointment-request`, {
      data: {
        patientName,
        // QR requests create a real patient record now, so a mobile is mandatory.
        patientMobile: `9${String(runId).slice(-9)}`,
        patientAge: 32,
        symptoms: 'Fever and headache',
        doctorPublicId: selectedDoctorId,
        specialty: 'Cardiologist',
        preferredDate,
      },
    });

    if (!submitResponse.ok()) {
      const failureBody = await submitResponse.text();
      throw new Error(`QR submit failed with HTTP ${submitResponse.status()}: ${failureBody}`);
    }
    const submitBody = await submitResponse.json();
    const requestPublicId = submitBody?.data?.requestPublicId as string;
    expect(requestPublicId).toBeTruthy();

    const afterCount = Number.parseInt(
      runSql("SELECT COUNT(*) FROM public.appointment_request WHERE tenant_public_id = 'T-2001';"),
      10,
    );
    expect(afterCount).toBe(beforeCount + 1);

    const persisted = runSql(
      `SELECT COUNT(*) FROM public.appointment_request WHERE request_public_id = '${requestPublicId}' AND tenant_public_id = 'T-2001' AND request_status = 'pending';`,
    );
    expect(Number.parseInt(persisted, 10)).toBe(1);

    const persistedPatient = runSql(
      `SELECT patient_name FROM public.appointment_request WHERE request_public_id = '${requestPublicId}';`,
    );
    expect(persistedPatient).toBe(patientName);
  });
});
