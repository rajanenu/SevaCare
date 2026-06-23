# SevaCare Production Features - Implementation Guide

> **Status**: Ready for Development  
> **Last Updated**: April 13, 2026

---

## Overview

This document outlines the implementation of 5 major production features for SevaCare:

1. **Hospital Admin Enrollment** - Restrict admin login to specific mobile numbers
2. **Doctor Enrollment** - Hospital admin adds/manages doctors; restrict doctor login to enrolled doctors
3. **QR Code Generation** - Each hospital gets a unique QR code
4. **QR Code Appointment Flow** - Patients scan QR → pre-filled form → doctor books appointmentI5. **Appointment Request Management** - Doctors review requests, assign slots, confirm appointments

---

## Database Changes

### New Tables Created (Flyway Migration V15)

#### 1. `hospital_admin_enrollment`
Stores authorized hospital admin mobile numbers.

```sql
-- Platform Admin specifies which mobile numbers can be hospital admins
CREATE TABLE public.hospital_admin_enrollment (
    admin_enrollment_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL UNIQUE,
    hospital_admin_mobile VARCHAR(24) NOT NULL UNIQUE,
    hospital_admin_name VARCHAR(160),
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT true
);
```

**Usage:**
- Platform Admin enrolls hospital admin: `INSERT INTO hospital_admin_enrollment VALUES (...)`
- During login: Validate doctor's/patient's mobile against this table
- Prevent unauthorized admin access

---

#### 2. `doctor_hospital_enrollment`
Stores doctors onboarded by hospital admin.

```sql
CREATE TABLE public.doctor_hospital_enrollment (
    doctor_enrollment_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    doctor_mobile VARCHAR(24) NOT NULL,
    doctor_name VARCHAR(160) NOT NULL,
    specialty VARCHAR(120) NOT NULL,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT true,
    UNIQUE(tenant_public_id, doctor_mobile)
);
```

**Usage:**
- Hospital Admin adds doctor: `POST /api/v1/admin/{tenant}/doctors/enroll`
- During doctor login: Fetch from this table, validate mobile + tenant match
- Only mobile numbers in this table can log in as doctors for a specific hospital

---

#### 3. `hospital_qrcode`
Stores QR code for each hospital.

```sql
CREATE TABLE public.hospital_qrcode (
    qrcode_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    qrcode_uuid VARCHAR(36) NOT NULL UNIQUE,
    qrcode_url VARCHAR(1024),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Usage:**
- Generate once per hospital: `POST /api/v1/admin/{tenant}/qrcode/generate`
- QR code encodes: `{BASE_URL}/qrcode/{qrcode_uuid}/appointment-form`
- Each hospital has only 1 active QR code

---

#### 4. `appointment_request`
Stores patient appointment requests (QR-based flow). Status progresses: `pending` → `confirmed`.

```sql
CREATE TABLE public.appointment_request (
    request_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    patient_mobile VARCHAR(24) NOT NULL,
    patient_name VARCHAR(160) NOT NULL,
    patient_age INT NOT NULL,
    symptoms VARCHAR(500) NOT NULL,
    doctor_public_id VARCHAR(16) NOT NULL,
    specialty VARCHAR(120) NOT NULL,
    preferred_date DATE NOT NULL,
    request_status VARCHAR(24) DEFAULT 'pending',   -- pending, confirmed
    assigned_slot VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Workflow:**
1. Patient scans QR → `POST /public/qrcode/{uuid}/appointment-request` → creates request with status = `pending`
2. Doctor sees request → reviews patient details
3. Doctor assigns slot + notes → `PUT /doctors/{tenant}/{doctor}/requests/{requestId}/confirm` → status = `confirmed`, appointment created

---

## Backend APIs

### 1. Hospital Admin Enrollment

**POST** `/api/v1/admin/{tenantPublicId}/hospital-admins/enroll`
- **Auth**: Platform Admin or Hospital Admin
- **Request**:
  ```json
  {
    "hospitalAdminMobile": "9844221599",
    "hospitalAdminName": "Admin Name",
    "active": true
  }
  ```
- **Response**:
  ```json
  {
    "adminEnrollmentPublicId": "HA-...",
    "tenantPublicId": "T-2001",
    "hospitalAdminMobile": "9844221599",
    "hospitalAdminName": "Admin Name",
    "active": true,
    "enrolledAt": "2024-04-13T10:30:00"
  }
  ```

**GET** `/api/v1/admin/{tenantPublicId}/hospital-admins`
- **Auth**: Platform Admin or Hospital Admin
- **Response**: `{ tenantPublicId, admins: [...] }`

---

### 2. Doctor Enrollment

**POST** `/api/v1/admin/{tenantPublicId}/doctors/enroll`
- **Auth**: Hospital Admin
- **Request**:
  ```json
  {
    "doctorMobile": "9000000001",
    "doctorName": "Dr. Smith",
    "specialty": "Cardiology",
    "active": true
  }
  ```
- **Response**:
  ```json
  {
    "doctor EnrollmentPublicId": "DE-...",
    "tenantPublicId": "T-2001",
    "doctorMobile": "9000000001",
    "doctorName": "Dr. Smith",
    "specialty": "Cardiology",
    "active": true,
    "enrolledAt": "2024-04-13T10:30:00"
  }
  ```

**GET** `/api/v1/admin/{tenantPublicId}/doctors`
- **Auth**: Hospital Admin
- **Response**: `{ tenantPublicId, doctors: [...] }`

---

### 3. QR Code Management

**POST** `/api/v1/admin/{tenantPublicId}/qrcode/generate`
- **Auth**: Hospital Admin
- **Response**:
  ```json
  {
    "qrcodePublicId": "QR-...",
    "tenantPublicId": "T-2001",
    "qrcodeUuid": "550e8400-e29b-41d4-a716-446655440000"
  }
  ```
- **Note**: Call once per hospital; subsequent calls return existing QR code

**GET** `/api/v1/public/qrcode/{qrcodeUuid}/form-data`
- **Auth**: Public (no auth)
- **Response**:
  ```json
  {
    "tenantPublicId": "T-2001",
    "tenantName": "SevaCare Local Hospital",
    "availableDoctors": [
      {
        "doctorPublicId": "D-1001",
        "doctorName": "Dr. Smith",
        "specialty": "Cardiology"
      }
    ]
  }
  ```

---

### 4. Appointment Request Workflow

**POST** `/api/v1/public/qrcode/{qrcodeUuid}/appointment-request`
- **Auth**: Public (patient)
- **Request**:
  ```json
  {
    "patientName": "John Doe",
    "patientAge": 35,
    "symptoms": "Chest pain and shortness of breath",
    "doctorPublicId": "D-1001",
    "specialty": "Cardiology",
    "preferredDate": "2024-04-20"
  }
  ```
- **Response**:
  ```json
  {
    "requestPublicId": "APTREQ-...",
    "patientMobile": "john",     // placeholder - improve in production
    "patientName": "John Doe",
    "patientAge": 35,
    "symptoms": "Chest pain and shortness of breath",
    "doctorPublicId": "D-1001",
    "specialty": "Cardiology",
    "preferredDate": "2024-04-20",
    "requestStatus": "pending",
    "assignedSlot": null,
    "notes": null,
    "createdAt": "2024-04-13T10:30:00",
    "updatedAt": "2024-04-13T10:30:00"
  }
  ```

**GET** `/api/v1/doctors/{tenantPublicId}/{doctorPublicId}/appointment-requests`
- **Auth**: Doctor
- **Response**:
  ```json
  {
    "tenantPublicId": "T-2001",
    "doctorPublicId": "D-1001",
    "requests": [
      {
        "requestPublicId": "APTREQ-...",
        "patientName": "John Doe",
        "patientAge": 35,
        "symptoms": "Chest pain...",
        "requestStatus": "pending",
        "preferredDate": "2024-04-20",
        "createdAt": "2024-04-13T10:30:00"
      }
    ]
  }
  ```

**POST** `/api/v1/doctors/{tenantPublicId}/{doctorPublicId}/appointment-requests/{requestPublicId}/confirm`
- **Auth**: Doctor
- **Request**:
  ```json
  {
    "assignedSlot": "2024-04-20 14:30",
    "notes": "Patient to arrive 10 minutes early"
  }
  ```
- **Response**:
  ```json
  {
    "requestPublicId": "APTREQ-...",
    "appointmentPublicId": "APT-...",
    "requestStatus": "confirmed",
    "assignedSlot": "2024-04-20 14:30",
    "updatedAt": "2024-04-13T10:30:00"
  }
  ```

---

## Frontend Screens

### New Screens to Implement

#### 1. QR Code Appointment Form Screen
**File**: `sevacare-frontend/src/screens/qrcode-appointment-screen.tsx`

**Flow**:
1. Patient scans hospital QR → extracted UUID
2. Fetch hospital + doctors from `/public/qrcode/{uuid}/form-data`
3. Patient fills:
   - Name
   - Age
   - Symptoms/Reason
   - Select Doctor (dropdown)
   - Select Specialization (auto-filled from doctor)
   - Choose Preferred Date (date picker)
4. Submit → `POST /public/qrcode/{uuid}/appointment-request`
5. Show success → navigate to home or new appointment confirmation

**Component Props**:
```typescript
{
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  qrcodeUuid: string;
  onSubmitSuccess: () => void;
}
```

---

#### 2. Doctor Appointment Requests Screen
**File**: `sevacare-frontend/src/screens/doctor-appointment-requests-screen.tsx`

**Flow**:
1. Doctor logs in → new nav tab "Requests"
2. Show list of appointment requests:
   - **Pending** (highlighted): Patient name, symptoms preview, preferred date
   - **Confirmed** (grayed out): Same info + assigned slot
3. Doctor taps request → detail view:
   - Patient full info
   - Complete symptoms
   - Preferred date
   - (if pending) Form to assign slot + notes
   - (if confirmed) Show confirmed slot + notes
4. Doctor assigns slot → `POST /confirm` → mark as confirmed
5. On confirmation, create actual appointment record

**Component Props**:
```typescript
{
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  tenantPublicId: string;
  doctorPublicId: string;
}
```

---

### Update Existing Screens

#### 1. Update QR Scanner (`tenant-entry-screens.tsx`)
```typescript
//  Current: placeholder ScannerScreen
// New: Actual camera implementation
// On scan: extract UUID → redirect to QR appointment form

export function ScannerScreen({...}) {
  // Use Expo Camera to capture QR code
  // On detection: extract UUID
  // Navigate to 'qr-appointment-form' with UUID
}
```

#### 2. Update Doctor Dashboard (`doctor-screens.tsx`)
```typescript
// Add "Requests" tab in doctor bottom nav
// Route: 'appointment-requests' → DoctorAppointmentRequestsScreen
```

#### 3. Update Hospital Admin Dashboard (`admin-screens.tsx`)
```typescript
// Add "Doctors" section to manage enrolled doctors
// Add "QR Code" section to display/download hospital QR code
```

---

## Integration Checklist

### Backend (Java)

- [ ] **Flyway Migration V15** - Run `mvn clean package` to apply schema
- [ ] **DTOs** - Verify `HospitalManagementDtos.java` compiles
- [ ] **Services**:
  - [ ] `HospitalManagementService.java` - Compile & inject into controllers
  - [ ] `AppointmentRequestService.java` - Compile & inject into controllers
- [ ] **Controllers** - `HospitalManagementController.java` wired correctly
- [ ] **Dependencies** - No Lombok errors; use plain Java beans
- [ ] **Build** - `mvn -f sevacare-backend/pom.xml clean package -DskipTests`

### Frontend (React Native Web)

- [ ] **New Screens**:
  - [ ] `qrcode-appointment-screen.tsx` - imports, props, API calls
  - [ ] `doctor-appointment-requests-screen.tsx` - imports, props, API calls
- [ ] **App Router** - Add routes:
  - `'qr-appointment-form'` → `QRCodeAppointmentFormScreen`
  - `'appointment-requests'` → `DoctorAppointmentRequestsScreen`
- [ ] **Doctor Screens** - Update nav to include "Requests" tab
- [ ] **Admin Screens** - Add "Doctors" + "QR Code" sections
- [ ] **Types** - Update `AppScreen` type if needed
- [ ] **Compile** - `cd sevacare-frontend && npx tsc --noEmit`
- [ ] **Build** - `npx expo export --platform web`

### Database

- [ ] Seed test data:
  ```sql
  -- Already seeded in V15:
  INSERT INTO hospital_admin_enrollment (...) VALUES ('HA-T2001-001', 'T-2001', '9000000003', ...);
  INSERT INTO hospital_qrcode (...) VALUES ('QR-T2001-001', 'T-2001', '550e8400-e29b-41d4-a716-446655440000', ...);
  ```
- [ ] Add test doctors:
  ```sql
  INSERT INTO doctor_hospital_enrollment (...) VALUES 
    ('DE-T2001-001', 'T-2001', '9000000001', 'Dr. Smith', 'Cardiology', true),
    ('DE-T2001-002', 'T-2001', '9000000002', 'Dr. Jane', 'Neurology', true);
  ```

---

## Testing Flow

### Manual QA

**1. Login Restrictions**
- [ ] Try doctor login with `9000000001` → must be enrolled in hospital admin's doctor list
- [ ] Try doctor login with random mobile → should FAIL (not in `doctor_hospital_enrollment`)
- [ ] Try hospital admin login with `9000000003` → must be in `hospital_admin_enrollment`
- [ ] Try hospital admin login with random mobile → should FAIL

**2. QR Code Generation**
- [ ] Hospital Admin: `POST /admin/T-2001/qrcode/generate` → get UUID
- [ ] Try same call again → returns same UUID (idempotent)

**3. QR Code Appointment Flow (Happy Path)**
- [ ] Render QR code in admin dashboard (using UUID)
- [ ] Patient scans → extracts UUID
- [ ] Frontend: `GET /public/qrcode/{uuid}/form-data` → hospital + doctors loaded
- [ ] Patient fills form → `POST /public/qrcode/{uuid}/appointment-request` → success
- [ ] Request stored in `appointment_request` table with status = `pending`

**4. Doctor Reviews Requests**
- [ ] Doctor logs in
- [ ] Navigate to "Appointment Requests" → see pending requests
- [ ] Tap request → detail view shows patient info + symptoms
- [ ] Doctor fills "Assign Slot" (e.g., "2024-04-20 14:30") + notes
- [ ] Doctor submits → `POST .../confirm` → status = `confirmed`
- [ ] Actual appointment created in tenant schema
- [ ] List view updates: request now grayed out with "confirmed" badge

**5. Edge Cases**
- [ ] Invalid UUID → error message
- [ ] Doctor from Hospital A tries to confirm request for Hospital B → auth error
- [ ] Confirm already-confirmed request → validation error

---

## Configuration for GCP Deployment

**Cloud Build Secrets** (set in Secret Manager):
- `SEVACARE_DB_URL` = `jdbc:postgresql://db.example.com:5432/seva_care`
- `SEVACARE_DB_USERNAME` = `sevacare_app`
- `SEVACARE_DB_PASSWORD` = `<strong-password>`
- `SEVACARE_AUTH_SECRET` = `<long-random-secret>`

**Cloud Run Environment (Frontend)**:
- `EXPO_PUBLIC_API_BASE_URL` = `https://sevacare-backend.run.app/api/v1`

**Cloud Run Environment (Backend)**:
- `SPRING_PROFILES_ACTIVE` = `production`
- `SEVACARE_DB_URL`, `SEVACARE_DB_USERNAME`, `SEVACARE_DB_PASSWORD`, `SEVACARE_AUTH_SECRET` from Secret Manager

---

## Summary

| Component | Status | Location |
|---|---|---|
| Database Migration V15 | ✅ Ready | `sevacare-backend/sevacare-api/src/main/resources/db/migration/V15__*.sql` |
| Backend Services | ✅ Ready | `sevacare-backend/sevacare-tenant/src/main/java/.../HospitalManagementService.java` |
| Backend DTOs | ✅ Ready | `sevacare-backend/sevacare-shared/src/main/java/.../HospitalManagementDtos.java` |
| Backend APIs | ✅ Ready | `sevacare-backend/sevacare-api/src/main/java/.../HospitalManagementController.java` |
| Frontend Screens | ✅ Ready | `sevacare-frontend/src/screens/qrcode-appointment-screen.tsx` + `doctor-appointment-requests-screen.tsx` |
| App Router Integration | ⏳ TODO | Wire new screens into `app-router.tsx` |
| Doctor Nav Update | ⏳ TODO | Add "Requests" tab to doctor bottom navigation |
| Admin Dashboard | ⏳ TODO | Add "Doctors" + "QR Code" sections |
| E2E Tests | ⏳ TODO | Create Playwright tests for QR flow |

---

## Next Steps

1. **Build & Deploy Backend**
   - Run Flyway migrations
   - Build JAR: `mvn clean package`
   - Test APIs with curl / Postman

2. **Wire Frontend Screens**
   - Import new screens in `app-router.tsx`
   - Update doctor nav to show "Requests" tab
   - Add routes for `'qr-appointment-form'` and `'appointment-requests'`

3. **E2E Testing**
   - Create Playwright test for full QR → appointment → doctor confirm flow
   - Test login restrictions (only enrolled doctors/admins)

4. **Production Deployment**
   - Deploy to GCP Cloud Run using `cloudbuild.yaml`
   - Set secrets in Secret Manager
   - Monitor logs and metrics

---

**Questions?** Refer to API responses, database schema, or frontend component PropTypes for details.
