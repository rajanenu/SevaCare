import { execFileSync } from 'child_process';
import { expect, test } from '@playwright/test';

const API = 'http://localhost:8081/api/v1';
const QR_UUID = '550e8400-e29b-41d4-a716-446655440000';

const DB_CONTAINER = process.env.DB_CONTAINER ?? 'sevacare-db';
const DB_USER = process.env.DB_USER ?? 'postgres';
const DB_NAME = process.env.DB_NAME ?? 'seva_care';

function runSql(query: string): string {
  return execFileSync(
    'docker',
    ['exec', DB_CONTAINER, 'psql', '-U', DB_USER, '-d', DB_NAME, '-t', '-A', '-c', query],
    { encoding: 'utf8' },
  ).trim();
}

test.describe('QR appointment request flow with DB assertion', () => {
  test('submits QR appointment request and persists to public.appointment_request', async ({ request }) => {
    const runId = Date.now();
    const doctorEnrollmentId = `DQR${String(runId).slice(-8)}`;

    runSql(`
      INSERT INTO public.doctor_hospital_enrollment
      (doctor_enrollment_public_id, tenant_public_id, doctor_mobile, doctor_name, specialty, enrolled_at, active)
      VALUES ('${doctorEnrollmentId}', 'T-2001', '91${String(runId).slice(-8)}', 'Dr. QR ${runId}', 'Cardiologist', NOW(), true)
      ON CONFLICT (tenant_public_id, doctor_mobile)
      DO UPDATE SET doctor_name = EXCLUDED.doctor_name, specialty = EXCLUDED.specialty, active = true;
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

    const selectedDoctorId = doctorEnrollmentId;
    const preferredDate = new Date().toISOString().slice(0, 10);
    const patientName = `QR Patient ${runId}`;

    const submitResponse = await request.post(`${API}/public/qrcode/${QR_UUID}/appointment-request`, {
      data: {
        patientName,
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
