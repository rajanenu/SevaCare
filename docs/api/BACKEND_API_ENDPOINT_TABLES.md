# SevaCare Backend - Complete API Endpoint Reference Tables

## 1️⃣ Authentication APIs

| # | Method | Endpoint | Auth | Request Body | Response | Purpose |
|---|--------|----------|------|--------------|----------|---------|
| 1 | `POST` | `/api/v1/auth/otp/request` | ❌ | `{tenantPublicId, role, mobileNumber}` | `{tenantPublicId, role, mobileNumber, otpHint}` | Request OTP for login |
| 2 | `POST` | `/api/v1/auth/otp/verify` | ❌ | `{tenantPublicId, role, mobileNumber, otp}` | `{tenantPublicId, role, subjectPublicId, token}` | Verify OTP & get token |

---

## 2️⃣ Public Discovery APIs

| # | Method | Endpoint | Auth | Query Params | Response | Purpose |
|---|--------|----------|------|--------------|----------|---------|
| 3 | `GET` | `/api/v1/public/tenants` | ❌ | - | `{tenants: [{tenantPublicId, hospitalName, city, specialty, themeKey}]}` | List all hospitals |
| 4 | `GET` | `/api/v1/public/tenants/{tenantId}/doctors` | ❌ | - | `{tenantPublicId, doctors: [{doctorPublicId, name, specialty, availability, fee}]}` | Search doctors by hospital |
| 5 | `GET` | `/api/v1/public/lookups` | ❌ | - | `{specializations: [...], cities: [...]}` | Get reference data |
| 6 | `POST` | `/api/v1/public/onboarding/request` | ❌ | - | `{hospitalName, licenseNumber, state, city, address, country, contactName, contactMobile, contactEmail, supportingDocs, facilityType}` | `{requestPublicId, status, message, documents}` | Hospital onboarding (JSON) |
| 7 | `POST` | `/api/v1/public/onboarding/request-multipart` | ❌ | - | `payload=JSON&files=[]` | `{requestPublicId, status, message, documents}` | Hospital onboarding (with files) |
| 8 | `GET` | `/api/v1/public/onboarding/request/{requestId}/documents` | ❌ | - | - | `[{documentPublicId, fileName, contentType, fileSize}]` | List onboarding documents |
| 9 | `GET` | `/api/v1/public/onboarding/request/{requestId}/documents/{docId}/download` | ❌ | - | - | `File(binary)` | Download document |
| 10 | `POST` | `/api/v1/public/tenants/{tenantId}/doctors/register` | ❌ | - | `{fullName, specialization, mobileNumber, age, gender, licenseNumber, experienceYears, address, city, state, appointmentIntervalMinutes, lunchBreakStartTime, lunchBreakEndTime, maxAppointmentsPerDay, workingDays}` | `{doctorPublicId, tenantPublicId, status, message}` | Doctor self-onboarding |

---

## 3️⃣ Patient APIs

### Patient Home/Dashboard
| # | Method | Endpoint | Auth | Role | Request | Response | Purpose |
|---|--------|----------|------|------|---------|----------|---------|
| 11 | `GET` | `/api/v1/patients/{tenantId}/{patientId}/home` | ✅ | P,D,A | - | - | `{patientPublicId, tenantPublicId, appointments: [...], prescriptions: [...]}` | Patient dashboard |
| 12 | `GET` | `/api/v1/patients/{tenantId}/{patientId}/booking/setup` | ✅ | P,D,A | - | - | `{tenantPublicId, slotIntervalMinutes, specialties}` | Get booking form data |

### Patient Management (CRUD)
| # | Method | Endpoint | Auth | Role | Request | Response | Purpose |
|---|--------|----------|------|------|---------|----------|---------|
| 13 | `GET` | `/api/v1/patients/{tenantId}/records` | ✅ | D,A | - | - | `{tenantPublicId, patients: [{...}]}` | List all patients |
| 14 | `GET` | `/api/v1/patients/{tenantId}/records/{patientId}` | ✅ | P,D,A | - | - | `{patientPublicId, tenantPublicId, fullName, mobileNumber, status}` | Get patient details |
| 15 | `PUT` | `/api/v1/patients/{tenantId}/records/{patientId}` | ✅ | D,A | `{fullName, mobileNumber, status}` | `{...PatientView}` | Create/update patient |
| 16 | `DELETE` | `/api/v1/patients/{tenantId}/records/{patientId}` | ✅ | D,A | - | `"deleted"` | Delete patient |

### Appointments
| # | Method | Endpoint | Auth | Role | Request | Response | Purpose |
|---|--------|----------|------|------|---------|----------|---------|
| 17 | `POST` | `/api/v1/patients/{tenantId}/{patientId}/appointments` | ✅ | P,D,A | `{tenantPublicId, patientPublicId, patientName, gender, age, mobileNumber, address, specialty, doctorPublicId, slot}` | `{appointmentPublicId, tenantPublicId, doctorPublicId, patientPublicId, slot, status}` | Book appointment |
| 18 | `GET` | `/api/v1/patients/{tenantId}/appointments` | ✅ | D,A | - | - | `{tenantPublicId, appointments: [{...}]}` | List appointments |
| 19 | `GET` | `/api/v1/patients/{tenantId}/appointments/{appointmentId}` | ✅ | P,D,A | - | - | `{appointmentPublicId, patientPublicId, doctorPublicId, slot, status, note}` | Get appointment |
| 20 | `PUT` | `/api/v1/patients/{tenantId}/appointments/{appointmentId}` | ✅ | D,A | `{patientPublicId, doctorPublicId, slot, status, note}` | `{...AppointmentEntityView}` | Update appointment |
| 21 | `DELETE` | `/api/v1/patients/{tenantId}/appointments/{appointmentId}` | ✅ | D,A | - | `"deleted"` | Cancel appointment |

**Legend**: P = PATIENT, D = DOCTOR, A = ADMIN

---

## 4️⃣ Doctor APIs

### Doctor Dashboard
| # | Method | Endpoint | Auth | Role | Request | Response | Purpose |
|---|--------|----------|------|------|---------|----------|---------|
| 22 | `GET` | `/api/v1/doctors/{tenantId}/{doctorId}/dashboard` | ✅ | D,A | - | - | `{doctorPublicId, tenantPublicId, totalAppointments, pendingNotes, nextPatientPublicId, nextPatientName}` | Doctor dashboard |
| 23 | `POST` | `/api/v1/doctors/{tenantId}/{doctorId}/patients/{patientId}/disable` | ✅ | D,A | `{reason?}` | `{tenantPublicId, patientPublicId, status, reason}` | Disable patient access |

### Doctor Management (CRUD)
| # | Method | Endpoint | Auth | Role | Request | Response | Purpose |
|---|--------|----------|------|------|---------|----------|---------|
| 24 | `GET` | `/api/v1/doctors/{tenantId}/records` | ✅ | D,A | - | - | `{tenantPublicId, doctors: [{...}]}` | List all doctors |
| 25 | `GET` | `/api/v1/doctors/{tenantId}/records/{doctorId}` | ✅ | D,A | - | - | `{doctorPublicId, tenantPublicId, fullName, specialty, availability, fee, active}` | Get doctor profile |
| 26 | `PUT` | `/api/v1/doctors/{tenantId}/records/{doctorId}` | ✅ | D,A | `{fullName, specialty, availability, fee, active}` | `{...DoctorView}` | Update doctor profile |
| 27 | `DELETE` | `/api/v1/doctors/{tenantId}/records/{doctorId}` | ✅ | D,A | - | `"deleted"` | Deactivate doctor |

---

## 5️⃣ Admin APIs

| # | Method | Endpoint | Auth | Role | Request | Response | Purpose |
|---|--------|----------|------|------|---------|----------|---------|
| 28 | `GET` | `/api/v1/admin/{tenantId}/overview` | ✅ | A | - | - | `{tenantPublicId, metrics: [{label, value, trend}]}` | Admin dashboard |
| 29 | `POST` | `/api/v1/admin/doctors` | ✅ | A | `{tenantPublicId, name, specialtyOrAgeBand}` | `{publicId, tenantPublicId, name, action: "created"}` | Create doctor |
| 30 | `DELETE` | `/api/v1/admin/{tenantId}/doctors/{doctorId}` | ✅ | A | - | `{publicId, tenantPublicId, action: "deleted"}` | Delete doctor |
| 31 | `POST` | `/api/v1/admin/patients` | ✅ | A | `{tenantPublicId, name, specialtyOrAgeBand}` | `{publicId, tenantPublicId, name, action: "created"}` | Create patient |
| 32 | `DELETE` | `/api/v1/admin/{tenantId}/patients/{patientId}` | ✅ | A | - | `{publicId, tenantPublicId, action: "deleted"}` | Delete patient |

---

## 6️⃣ Health Check APIs

| # | Method | Endpoint | Auth | Response | Purpose |
|---|--------|----------|------|----------|---------|
| 33 | `GET` | `/actuator/health` | ❌ | `{status: "UP|DOWN", components: {...}}` | Health status |
| 34 | `GET` | `/actuator/info` | ❌ | `{app: "sevacare-api", version: "..."}` | Application info |
| 35 | `GET` | `/actuator/metrics` | ❌ | `{names: [...]}` | Available metrics |
| 36 | `GET` | `/actuator/prometheus` | ❌ | `text/plain` | Prometheus metrics |

---

## 📊 Endpoint Statistics

```
Total Endpoints: 36

Breakdown:
- Public (No Auth): 10 endpoints
  └── Discovery: 8
  └── Auth: 2

- Protected (Auth Required): 26 endpoints
  └── Patient: 11
  └── Doctor: 6
  └── Admin: 5
  └── Health: 4

Access by Role:
- Patient: 11 endpoints
- Doctor: 17 endpoints (Doctor + shared Patient)
- Admin: 26 endpoints (All protected + Patient/Doctor records)
```

---

## 🗺️ API Request Path Patterns

```
/api/v1/public/**                          # Public APIs
├── /tenants                                # List tenants
├── /tenants/{tenantId}/doctors            # Search doctors
├── /lookups                                # Reference data
├── /onboarding/request                    # Hospital onboarding
├── /onboarding/request-multipart          # With file upload
├── /onboarding/request/{id}/documents     # List/Download
└── /tenants/{tenantId}/doctors/register   # Doctor registration

/api/v1/auth/**                            # Authentication (Public)
├── /otp/request                           # Request OTP
└── /otp/verify                            # Verify OTP

/api/v1/patients                           # Patient APIs (Protected)
├── /{tenantId}/{patientId}/home           # Dashboard
├── /{tenantId}/{patientId}/booking/setup  # Booking form data
├── /{tenantId}/{patientId}/appointments   # Book appointment
├── /{tenantId}/records                    # Patient CRUD
├── /{tenantId}/records/{patientId}        # Patient detail
└── /{tenantId}/appointments               # Appointment CRUD

/api/v1/doctors                            # Doctor APIs (Protected)
├── /{tenantId}/{doctorId}/dashboard       # Dashboard
├── /{tenantId}/{doctorId}/patients/{id}/disable
├── /{tenantId}/records                    # Doctor CRUD
└── /{tenantId}/records/{doctorId}         # Doctor detail

/api/v1/admin                              # Admin APIs (Protected, ADMIN role)
├── /{tenantId}/overview                   # Admin dashboard
├── /doctors                                # Create/Delete doctors
├── /patients                               # Create/Delete patients
└── /{tenantId}/doctors|patients/{id}      # Individual actions

/actuator/**                               # Health & Monitoring (Public)
├── /health
├── /info
├── /metrics
└── /prometheus
```

---

## 🔐 Authentication Headers Reference

### Required Headers (Protected Endpoints)

```http
Authorization: Bearer {token}
X-Tenant-Id: {tenantPublicId}
Content-Type: application/json
```

### Example Token
```
Header: Authorization: Bearer VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nPqRsT...

Token Components:
- Part 1 (Base64 Payload): VDEtMDAxfHBhdGllbnR8UC0xMjM0
  └─ Decoded: T-1001|patient|P-1234

- Part 2 (HMAC-SHA256 Signature): oFhsH8qL2kM9nPqRsT...
  └─ Secret: "dev-sevacare-secret"
```

### Optional Headers

```http
Accept: application/json
Accept-Language: en-US
```

---

## 📋 Response Wrapper Format

All successful responses wrapped in `ContractResponse`:

```json
{
  "data": {
    // Actual response payload varies by endpoint
  },
  "generatedAt": "2024-03-21T10:30:45.123456Z"
}
```

### Error Response Format

```json
{
  "timestamp": "2024-03-21T10:30:45.123456Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Invalid OTP",
  "path": "/api/v1/auth/otp/verify"
}
```

---

## 🎯 Common Query Patterns

### Get Patient Home (Dashboard)
```bash
GET /api/v1/patients/T-1001/P-1234/home
Header: Authorization: Bearer {token}
Header: X-Tenant-Id: T-1001
```

### Search Doctors in Tenant
```bash
GET /api/v1/public/tenants/T-1001/doctors
# No authentication needed
```

### Book Appointment
```bash
POST /api/v1/patients/T-1001/P-1234/appointments
Header: Authorization: Bearer {token}
Header: X-Tenant-Id: T-1001
Body: {
  "specialty": "Cardiology",
  "doctorPublicId": "DR-1001",
  "slot": "2024-03-22 10:30",
  ...
}
```

### Get Doctor Dashboard
```bash
GET /api/v1/doctors/T-1001/DR-1001/dashboard
Header: Authorization: Bearer {token}
Header: X-Tenant-Id: T-1001
```

### Get Admin Overview
```bash
GET /api/v1/admin/T-1001/overview
Header: Authorization: Bearer {token}
Header: X-Tenant-Id: T-1001
```

---

## ✅ Validation Rules by Endpoint

| Endpoint | Field | Validation |
|----------|-------|-----------|
| OTP Request | `mobileNumber` | Exactly 10 digits |
| OTP Request | `role` | "patient", "doctor", or "admin" |
| OTP Verify | `otp` | Must match "0000" (dev) |
| Appointment Booking | `doctorPublicId` | Must exist in tenant schema |
| Appointment Booking | `patientPublicId` | Must match path parameter |
| Appointment Booking | `age` | >= 0 |
| Doctor Onboarding | `mobileNumber` | Exactly 10 digits |
| Doctor Onboarding | `age` | >= 18 |
| Doctor Onboarding | `experienceYears` | >= 0 |
| Doctor Onboarding | `appointmentInterval` | >= 10 minutes |
| Doctor Onboarding | `timeFormat` | HH:mm (24-hour) |
| Onboarding Request | `facilityType` | "hospital" or "clinic" |
| Onboarding Request | `contactEmail` | Valid email format |

---

## 🚦 HTTP Status Codes

| Status | Meaning | Common Cause |
|--------|---------|------------|
| `200 OK` | Request succeeded | Successful GET/PUT |
| `201 Created` | Resource created | Successful POST |
| `204 No Content` | Success, no content | Successful DELETE |
| `400 Bad Request` | Invalid input | Validation error, missing field |
| `401 Unauthorized` | Authentication required | Missing/invalid token |
| `403 Forbidden` | Insufficient permissions | Wrong role for endpoint |
| `404 Not Found` | Resource not found | ID doesn't exist |
| `409 Conflict` | Duplicate resource | Duplicate tenant/user |
| `500 Internal Server Error` | Server error | Unexpected error |

---

## 🔄 API Call Flow Examples

### Complete Login & Dashboard Flow
```
1. POST /api/v1/auth/otp/request
   ├─ Input: {tenantId: "T-1001", role: "patient", mobile: "9000000000"}
   └─ Output: {otpHint: "0000"}

2. POST /api/v1/auth/otp/verify
   ├─ Input: {tenantId: "T-1001", role: "patient", mobile: "9000000000", otp: "0000"}
   └─ Output: {token: "...", subjectPublicId: "P-1234"}

3. GET /api/v1/patients/T-1001/P-1234/home
   ├─ Headers: Bearer {token}, X-Tenant-Id: T-1001
   └─ Output: {appointments: [...], prescriptions: [...]}

4. GET /api/v1/patients/T-1001/P-1234/booking/setup
   ├─ Headers: Bearer {token}, X-Tenant-Id: T-1001
   └─ Output: {slotInterval: 30, specialties: ["Cardiology", ...]}

5. GET /api/v1/public/tenants/T-1001/doctors?specialty=Cardiology
   ├─ No auth required
   └─ Output: {doctors: [{name: "Dr. Sanjay", fee: "₹500", ...}]}

6. POST /api/v1/patients/T-1001/P-1234/appointments
   ├─ Headers: Bearer {token}, X-Tenant-Id: T-1001
   ├─ Input: {doctorId: "DR-1001", slot: "2024-03-22 10:30", ...}
   └─ Output: {appointmentId: "AP-5678", status: "confirmed"}
```

### Hospital Onboarding Flow
```
1. GET /api/v1/public/lookups
   └─ Output: {specializations: [...], cities: [...]}

2. GET /api/v1/public/tenants
   └─ Output: {tenants: [{...hospitals...}]}

3. POST /api/v1/public/onboarding/request-multipart
   ├─ Input: payload={JSON}, files=[license.pdf, ...]
   └─ Output: {requestId: "ONB-1234", documents: [{...}]}

4. GET /api/v1/public/onboarding/request/ONB-1234/documents
   └─ Output: [{fileName: "license.pdf", fileSize: 245612, ...}]

5. GET /api/v1/public/onboarding/request/ONB-1234/documents/DOC-5001/download
   └─ Output: File binary (application/pdf)

(Admin reviews & approves)

6. POST /api/v1/public/tenants/{newTenantId}/doctors/register
   ├─ Input: {fullName, specialization, mobile, ...}
   └─ Output: {doctorId: "DR-1001", status: "registered"}
```
