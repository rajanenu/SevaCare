# SevaCare Backend - Focus APIs Summary

This document focuses on the 5 key API areas you requested:
1. Patient home/dashboard
2. Doctor search and filtering
3. Appointment booking
4. Authentication (OTP, token)
5. Hospital/tenant data

---

## 🔐 Authentication APIs (OTP & Token)

### 1. Request OTP
```
POST /api/v1/auth/otp/request

Request:
{
  "tenantPublicId": "T-1001",
  "role": "patient|doctor|admin",
  "mobileNumber": "9000000000"
}

Response (200 OK):
{
  "data": {
    "tenantPublicId": "T-1001",
    "role": "patient",
    "mobileNumber": "9000000000",
    "otpHint": "0000"  # In production: SMS sent to mobile
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

Error Cases:
- 400: Invalid tenantPublicId (tenant doesn't exist or inactive)
- 400: Invalid role (must be patient, doctor, or admin)
- 400: Invalid mobileNumber format
```

**Key Details**:
- **Public endpoint**: No authentication required
- **Rate limiting**: Currently unlimited (should add in production)
- **OTP in dev**: Always "0000" (hardcoded for testing)
- **OTP in production**: Would be sent via SMS
- **OTP expiry**: No expiry currently (could add 5-10 min expiry)
- **Retries**: No limit currently

---

### 2. Verify OTP & Get Token
```
POST /api/v1/auth/otp/verify

Request:
{
  "tenantPublicId": "T-1001",
  "role": "patient",
  "mobileNumber": "9000000000",
  "otp": "0000"
}

Response (200 OK):
{
  "data": {
    "tenantPublicId": "T-1001",
    "role": "patient",
    "subjectPublicId": "P-1234",  # Patient, Doctor, or Admin ID
    "token": "VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nPqRsT..."
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

Error Cases:
- 400: Invalid OTP (doesn't match "0000")
- 400: Invalid tenantPublicId
- 400: Tenant not active
- 400: No user of given role found in tenant
  └─ Falls back to: findFirstPatientForTenant() → creates if missing?
```

**Token Structure**:
```
Token Format: {base64_payload}.{hmac_sha256_signature}

Payload (Base64 encoded):
  T-1001 | patient | P-1234
  └─────────────────────────
  tenantPublicId | role | subjectPublicId

Signature:
  HMAC-SHA256(payload, secret="dev-sevacare-secret")

Example Token:
  VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nPqRsT...
  ▲                                  ▲
  Payload                            Signature
```

**Token Validation Flow**:
1. Extract "Bearer {token}" from Authorization header
2. Split token by "." (payload | signature)
3. Verify signature: HMAC-SHA256(payload, secret) == signature
4. Decode payload: Base64 → "T-1001|patient|P-1234"
5. Extract claims: TenantPublicId, Role, SubjectPublicId
6. Create Spring Security context with ROLE_PATIENT authority

**Key Details**:
- **Algorithm**: HMAC-SHA256
- **Secret**: `${SEVACARE_AUTH_SECRET:dev-sevacare-secret}` (environment variable)
- **Expiry**: No expiry currently (tokens are long-lived)
- **Rotation**: Not implemented
- **Revocation**: Not implemented
- **Multi-device**: Same user can have multiple tokens

---

## 🏥 Hospital/Tenant Data APIs

### 1. List All Hospitals (Tenant Directory)
```
GET /api/v1/public/tenants

Request: (No body)

Response (200 OK):
{
  "data": {
    "tenants": [
      {
        "tenantPublicId": "T-1001",
        "hospitalName": "Sunrise Care Hospital",
        "city": "Hyderabad",
        "specialty": "Multi-specialty",  // Can be filtered in UI
        "themeKey": "sunrise"            // For UI theming
      },
      {
        "tenantPublicId": "T-1002",
        "hospitalName": "City Medical Center",
        "city": "Bangalore",
        "specialty": "Multi-specialty",
        "themeKey": "city"
      },
      {
        "tenantPublicId": "T-1003",
        "hospitalName": "Apollo Clinics",
        "city": "Mumbai",
        "specialty": "Primary Care",
        "themeKey": "apollo"
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

Filtering:
- Client-side filtering by city/specialty recommended
- No server-side filtering parameters currently
```

**Data Comes From**:
- Table: `public.tenant_registry`
- Fields: `tenant_public_id`, `tenant_name`, `tenant_theme_key`
- Filter: Only active tenants (`tenant_status = 'active'`)

**Use Cases**:
- Hospital selection screen in signup
- Search hospitals by location
- Display hospital list with branding

---

### 2. Get Hospital/Tenant Details
```
GET /api/v1/public/tenants/{tenantPublicId}/doctors

Example:
GET /api/v1/public/tenants/T-1001/doctors

Response (200 OK):
{
  "data": {
    "tenantPublicId": "T-1001",
    "doctors": [
      {
        "doctorPublicId": "DR-1001",
        "name": "Dr. Sanjay Kumar",
        "specialty": "Cardiology",
        "availability": "Mon-Fri 9AM-5PM",
        "fee": "₹500"
      },
      {
        "doctorPublicId": "DR-1002",
        "name": "Dr. Priya Sharma",
        "specialty": "Dermatology",
        "availability": "Tue-Thu 10AM-2PM, Sat 3PM-6PM",
        "fee": "₹400"
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

Error Cases:
- 404: Invalid tenantPublicId
- (No 404 actual, throws IllegalArgumentException → 400)
```

**Key Details**:
- **No authentication required**: Public endpoint
- **Listing all doctors**: No filtering/pagination
- **Availability format**: Free text (e.g., "Mon-Fri 9AM-5PM")
- **Fee format**: String with currency (e.g., "₹500")
- **Active filter**: Only shows active doctors (active = true)

---

### 3. Get Reference Data (Specializations & Cities)
```
GET /api/v1/public/lookups

Request: (No body)

Response (200 OK):
{
  "data": {
    "specializations": [
      "Cardiology",
      "Dermatology",
      "Orthopedics",
      "Pediatrics",
      "Psychiatry",
      "Neurology",
      "General Medicine"
    ],
    "cities": [
      "Hyderabad",
      "Bangalore",
      "Mumbai",
      "Delhi",
      "Chennai",
      "Pune",
      "Kolkata"
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

**Data Source**:
- Configured in: `sevacare-tenant/src/main/java/com/sevacare/tenant/service/ReferenceDataService.java`
- Hardcoded lists (could be moved to database)

**Use Cases**:
- Populate specialty dropdowns
- Populate city search filters
- Form validation

---

## 🔍 Doctor Search & Filtering APIs

### 1. Search Doctors by Hospital
```
GET /api/v1/public/tenants/{tenantPublicId}/doctors

Example:
GET /api/v1/public/tenants/T-1001/doctors

Response (200 OK):
{
  "data": {
    "tenantPublicId": "T-1001",
    "doctors": [
      {
        "doctorPublicId": "DR-1001",
        "name": "Dr. Sanjay Kumar",
        "specialty": "Cardiology",
        "availability": "Mon-Fri 9AM-5PM",
        "fee": "₹500"
      },
      {
        "doctorPublicId": "DR-1002",
        "name": "Dr. Priya Sharma",
        "specialty": "Dermatology",
        "availability": "Tue-Thu 10AM-2PM, Sat 3PM-6PM",
        "fee": "₹400"
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

**Limitations**:
- ❌ No server-side filtering by specialty
- ❌ No server-side filtering by fees
- ❌ No pagination (all doctors returned)
- ❌ No sorting options
- ✅ Client-side filtering recommended

**Filtering Logic** (To implement in UI):
```javascript
// Filter doctors by specialty
const cardiologists = doctors.filter(d => d.specialty === "Cardiology");

// Filter by fee range
const affordableDoctors = doctors.filter(d => 
  parseInt(d.fee.replace("₹", "")) <= 500
);

// Filter by availability
const weekdayDoctors = doctors.filter(d => 
  d.availability.includes("Mon-Fri")
);

// Combined filter
const filteredDoctors = doctors.filter(d =>
  d.specialty === "Cardiology" &&
  parseInt(d.fee.replace("₹", "")) <= 500 &&
  d.availability.includes("Mon")
);
```

---

### 2. List Doctors (Authenticated)
```
GET /api/v1/doctors/{tenantPublicId}/records

Requires:
- Authorization: Bearer {token}
- X-Tenant-Id: {tenantPublicId}
- Role: DOCTOR or ADMIN

Response (200 OK):
{
  "data": {
    "tenantPublicId": "T-1001",
    "doctors": [
      {
        "doctorPublicId": "DR-1001",
        "tenantPublicId": "T-1001",
        "fullName": "Dr. Sanjay Kumar",
        "specialty": "Cardiology",
        "availability": "Mon-Fri 9AM-5PM",
        "fee": "₹500",
        "active": true
      },
      {
        "doctorPublicId": "DR-1002",
        "tenantPublicId": "T-1001",
        "fullName": "Dr. Priya Sharma",
        "specialty": "Dermatology",
        "availability": "Tue-Thu 10AM-2PM, Sat 3PM-6PM",
        "fee": "₹400",
        "active": true
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

Error Cases:
- 401: Missing or invalid token
- 403: Insufficient role (must be DOCTOR or ADMIN)
- 400: Missing X-Tenant-Id header
- 400: Tenant mismatch
```

**Differences from Public API**:
- ✅ Requires authentication
- ✅ Includes `active` field
- ✅ Includes `tenantPublicId` in each doctor
- ✅ More detailed response for admin/doctor panels

---

## 👨‍⚕️ Patient Home/Dashboard APIs

### 1. Get Patient Dashboard
```
GET /api/v1/patients/{tenantPublicId}/{patientPublicId}/home

Requires:
- Authorization: Bearer {token}
- X-Tenant-Id: {tenantPublicId}
- Role: PATIENT, DOCTOR, or ADMIN
- Path validation: patientPublicId must belong to tenant

Example:
GET /api/v1/patients/T-1001/P-1234/home
Authorization: Bearer VDEtMDAxfHBhdGllbnR8UC0xMjM0...
X-Tenant-Id: T-1001

Response (200 OK):
{
  "data": {
    "patientPublicId": "P-1234",
    "tenantPublicId": "T-1001",
    "appointments": [
      {
        "appointmentPublicId": "AP-5678",
        "doctorPublicId": "DR-1001",
        "doctorName": "Dr. Sanjay Kumar",
        "slot": "2024-03-22 10:30",
        "status": "confirmed",
        "note": "Regular checkup"
      },
      {
        "appointmentPublicId": "AP-5679",
        "doctorPublicId": "DR-1002",
        "doctorName": "Dr. Priya Sharma",
        "slot": "2024-03-25 14:00",
        "status": "completed",
        "note": "Follow-up"
      }
    ],
    "prescriptions": [
      {
        "prescriptionPublicId": "RX-1001",
        "doctorPublicId": "DR-1001",
        "doctorName": "Dr. Sanjay Kumar",
        "issuedOn": "2024-03-20",
        "lines": [
          "Aspirin 500mg - Once daily",
          "Metoprolol 25mg - Twice daily",
          "Lisinopril 10mg - Once daily"
        ]
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

Error Cases:
- 401: Missing or invalid token
- 403: Insufficient role
- 400: Missing X-Tenant-Id header
- 400: Tenant mismatch (X-Tenant-Id != token tenantId)
- 400: Patient not found in tenant
```

**Dashboard Components**:
1. **Appointments** - Upcoming and past appointments
   - Status: confirmed, cancelled, completed
   - Sortable by date
   - Filterable by status

2. **Prescriptions** - Issued by doctors
   - Lines: Medication name + dosage
   - Doctor who issued
   - Date issued

**Typical UI Layout**:
```
┌─────────────────────────────────────────┐
│         PATIENT DASHBOARD                │
├─────────────────────────────────────────┤
│                                          │
│  Welcome, John Doe (P-1234)             │
│                                          │
│  ┌─ UPCOMING APPOINTMENTS ────────┐    │
│  │ • Dr. Sanjay - Mar 22 10:30    │    │
│  │   Cardiology - Regular checkup │    │
│  │                                │    │
│  │ [BOOK NEW APPOINTMENT]         │    │
│  └────────────────────────────────┘    │
│                                          │
│  ┌─ MY PRESCRIPTIONS ─────────────┐    │
│  │ • Dr. Sanjay (Mar 20)          │    │
│  │   - Aspirin 500mg once daily   │    │
│  │   - Metoprolol 25mg twice daily│    │
│  │   - Lisinopril 10mg once daily │    │
│  └────────────────────────────────┘    │
│                                          │
│  ┌─ COMPLETED APPOINTMENTS ───────┐    │
│  │ • Dr. Priya - Mar 15 (Completed)│   │
│  │   Dermatology - Follow-up      │    │
│  └────────────────────────────────┘    │
│                                          │
└─────────────────────────────────────────┘
```

---

### 2. Get Booking Setup Data (Form Pre-Population)
```
GET /api/v1/patients/{tenantPublicId}/{patientPublicId}/booking/setup

Requires:
- Authorization: Bearer {token}
- X-Tenant-Id: {tenantPublicId}
- Role: PATIENT, DOCTOR, or ADMIN

Example:
GET /api/v1/patients/T-1001/P-1234/booking/setup
Authorization: Bearer VDEtMDAxfHBhdGllbnR8UC0xMjM0...
X-Tenant-Id: T-1001

Response (200 OK):
{
  "data": {
    "tenantPublicId": "T-1001",
    "slotIntervalMinutes": 30,
    "specialties": [
      "Cardiology",
      "Dermatology",
      "Orthopedics",
      "Pediatrics",
      "General Medicine"
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

**Use Cases**:
1. **Populate specialty dropdown** → `specialties` array
2. **Slot interval display** → Show 30-min slots (e.g., 9:00, 9:30, 10:00)
3. **Form initialization** → Pre-load specialties for search

**Booking Form Flow**:
```
1. GET /booking/setup → Get slotIntervalMinutes (30 min)
2. Show form:
   - Specialty dropdown (from response)
   - Date picker
   - Time picker (intervals of 30 min)
3. User selects specialty
4. System filters doctors with that specialty
5. User books with slot
```

---

## 📅 Appointment Booking APIs

### 1. Book New Appointment
```
POST /api/v1/patients/{tenantPublicId}/{patientPublicId}/appointments

Requires:
- Authorization: Bearer {token}
- X-Tenant-Id: {tenantPublicId}
- Role: PATIENT, DOCTOR, or ADMIN

Request:
{
  "tenantPublicId": "T-1001",
  "patientPublicId": "P-1234",
  "patientName": "John Doe",
  "gender": "M",
  "age": 35,
  "mobileNumber": "9000000000",
  "address": "123 Main Street, Hyderabad",
  "specialty": "Cardiology",
  "doctorPublicId": "DR-1001",
  "slot": "2024-03-22 10:30"
}

Response (200 OK):
{
  "data": {
    "appointmentPublicId": "AP-5678",
    "tenantPublicId": "T-1001",
    "doctorPublicId": "DR-1001",
    "patientPublicId": "P-1234",
    "slot": "2024-03-22 10:30",
    "status": "confirmed"
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

Error Cases:
- 401: Missing or invalid token
- 403: Insufficient role
- 400: Missing X-Tenant-Id header
- 400: Invalid input (validation errors)
  └─ age must be >= 0
  └─ mobileNumber must be 10 digits
  └─ specialty must be non-blank
- 400: Invalid doctor (doesn't exist in tenant)
- 400: Slot already booked
- 400: Slot outside doctor's working hours
- 400: Tenant mismatch
```

**Validation Rules**:
```javascript
{
  "tenantPublicId": "Required, max 16 chars",
  "patientPublicId": "Required, must match path parameter",
  "patientName": "Required, non-blank",
  "gender": "Required, non-blank (M/F/Other)",
  "age": "Required, >= 0",
  "mobileNumber": "Required, exactly 10 digits, pattern: ^[0-9]{10}$",
  "address": "Required, non-blank",
  "specialty": "Required, non-blank",
  "doctorPublicId": "Required, must exist in tenant",
  "slot": "Required, format: YYYY-MM-DD HH:mm"
}
```

**Appointment Status Values**:
- `confirmed` - Appointment confirmed
- `cancelled` - Appointment cancelled
- `completed` - Appointment completed
- `no-show` - Patient didn't show up
- `rescheduled` - Moved to different slot

---

### 2. List Appointments (Authenticated)
```
GET /api/v1/patients/{tenantPublicId}/appointments

Requires:
- Authorization: Bearer {token}
- X-Tenant-Id: {tenantPublicId}
- Role: DOCTOR or ADMIN

Example:
GET /api/v1/patients/T-1001/appointments
Authorization: Bearer VDEtMDAxfHBhdGllbnR8UC0xMjM0...
X-Tenant-Id: T-1001

Response (200 OK):
{
  "data": {
    "tenantPublicId": "T-1001",
    "appointments": [
      {
        "appointmentPublicId": "AP-5678",
        "patientPublicId": "P-1234",
        "doctorPublicId": "DR-1001",
        "slot": "2024-03-22 10:30",
        "status": "confirmed",
        "note": "Regular checkup"
      },
      {
        "appointmentPublicId": "AP-5679",
        "patientPublicId": "P-1235",
        "doctorPublicId": "DR-1001",
        "slot": "2024-03-22 11:00",
        "status": "confirmed",
        "note": ""
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

### 3. Update Appointment
```
PUT /api/v1/patients/{tenantPublicId}/appointments/{appointmentPublicId}

Requires:
- Authorization: Bearer {token}
- X-Tenant-Id: {tenantPublicId}
- Role: DOCTOR or ADMIN

Request:
{
  "patientPublicId": "P-1234",
  "doctorPublicId": "DR-1001",
  "slot": "2024-03-22 14:00",  # Change time
  "status": "confirmed|cancelled|completed",
  "note": "Patient called to reschedule"
}

Response (200 OK):
{
  "data": {
    "appointmentPublicId": "AP-5678",
    "patientPublicId": "P-1234",
    "doctorPublicId": "DR-1001",
    "slot": "2024-03-22 14:00",
    "status": "confirmed",
    "note": "Patient called to reschedule"
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

### 4. Cancel Appointment
```
DELETE /api/v1/patients/{tenantPublicId}/appointments/{appointmentPublicId}

Requires:
- Authorization: Bearer {token}
- X-Tenant-Id: {tenantPublicId}
- Role: DOCTOR or ADMIN

Example:
DELETE /api/v1/patients/T-1001/appointments/AP-5678
Authorization: Bearer VDEtMDAxfHBhdGllbnR8UC0xMjM0...
X-Tenant-Id: T-1001

Response (200 OK):
{
  "data": "deleted",
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

## 🔗 API Call Sequence: Complete Booking Flow

```
User: Patient wants to book appointment with Dr. Sanjay (Cardiology)

1. AUTHENTICATE
   └─ POST /api/v1/auth/otp/request
   └─ POST /api/v1/auth/otp/verify
   └─ GET token: "VDEtMDAxfHBhdGllbnR8UC0xMjM0..."

2. DISCOVER HOSPITAL
   └─ GET /api/v1/public/tenants
   └─ User selects "Sunrise Care Hospital" (T-1001)

3. GET BOOKING FORM DATA
   └─ GET /api/v1/patients/T-1001/P-1234/booking/setup
   └─ Response: slotIntervalMinutes = 30, specialties = [...]

4. SEARCH DOCTORS
   └─ GET /api/v1/public/tenants/T-1001/doctors
   └─ Client-side filter by specialty = "Cardiology"
   └─ Shows: Dr. Sanjay, Dr. Priya, etc.

5. BOOK APPOINTMENT
   └─ POST /api/v1/patients/T-1001/P-1234/appointments
   └─ Input: {specialty: "Cardiology", doctorPublicId: "DR-1001", slot: "2024-03-22 10:30"}
   └─ Response: appointmentPublicId = "AP-5678"

6. VIEW DASHBOARD
   └─ GET /api/v1/patients/T-1001/P-1234/home
   └─ Shows: New appointment in list, status = "confirmed"
```

---

## 📊 Data Flow Diagram

```
                     LOGIN
                       │
         ┌─────────────┴─────────────┐
         │                           │
      REQUEST OTP             VERIFY OTP
   /auth/otp/request      /auth/otp/verify
    (9000000000)       (otp: "0000") → TOKEN
         │                           │
         └─────────────┬─────────────┘
                       │
                   AUTH TOKEN
         ┌───────────────────────────────┐
         │   (Bearer: VDEtMDAxf...)       │
         │   (X-Tenant-Id: T-1001)        │
         │                               │
    ┌────▼─────────────────┐             │
    │ PATIENT DASHBOARD    │             │
    │ /patients/.../home   │             │
    └─────────────────────┘             │
         ├─ Appointments                 │
         └─ Prescriptions                │
                                         │
         ┌─────────────────────────────┐ │
         │ BOOK APPOINTMENT            │ │
         │ /patients/.../appointments  │ │
         └─────────────────────────────┘ │
         ├─ Requires: tenantId,patient  │
         │ ├─ specialty                 │
         │ ├─ doctorPublicId            │
         │ ├─ slot                      │
         │ └─ patient details           │
         │                               │
         └───────────────────────────────┘
                       │
                  CONFIRM
         ┌──────────────────────┐
         │ Appointment Created  │
         │ (AP-5678, confirmed) │
         └──────────────────────┘
```

---

## 📋 Quick API Reference for Focus Areas

| Focus Area | Key Endpoint | Method | Auth | Purpose |
|-----------|-----------|--------|------|---------|
| **Auth** | `/auth/otp/request` | POST | ❌ | Get OTP |
| **Auth** | `/auth/otp/verify` | POST | ❌ | Verify OTP → Get token |
| **Hospital/Tenant** | `/public/tenants` | GET | ❌ | List all hospitals |
| **Hospital/Tenant** | `/public/lookups` | GET | ❌ | Get specializations + cities |
| **Doctor Search** | `/public/tenants/{id}/doctors` | GET | ❌ | List doctors in hospital |
| **Doctor Search** | `/doctors/{tenantId}/records` | GET | ✅ | List doctors (admin view) |
| **Patient Dashboard** | `/patients/{id}/{id}/home` | GET | ✅ | Patient dashboard |
| **Patient Dashboard** | `/patients/{id}/{id}/booking/setup` | GET | ✅ | Get form data |
| **Appointment Booking** | `/patients/{id}/{id}/appointments` | POST | ✅ | Book appointment |
| **Appointment Booking** | `/patients/{id}/appointments` | GET | ✅ | List appointments |
