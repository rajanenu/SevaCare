# SevaCare Backend API Documentation

**Project**: SevaCare Multi-Tenant Healthcare Platform  
**Framework**: Spring Boot 3.4.3 with Java 21  
**Database**: PostgreSQL with Flyway migrations  
**Architecture**: Multi-module Maven project with Multi-Tenancy support

---

## Table of Contents
1. [REST API Controllers & Endpoints](#rest-api-controllers--endpoints)
2. [Key Data Models/Entities](#key-data-modelsentities)
3. [DTOs (Request/Response)](#dtos-requestresponse)
4. [Authentication & Authorization](#authentication--authorization)
5. [Error Handling](#error-handling)
6. [Multi-Tenancy Architecture](#multi-tenancy-architecture)
7. [Configuration](#configuration)

---

## REST API Controllers & Endpoints

### 1. Authentication Controller
**File**: `sevacare-api/src/main/java/com/sevacare/api/controller/AuthController.java`  
**Base Path**: `/api/v1/auth`  
**Authentication**: ❌ Public endpoints

| HTTP Method | Endpoint | Purpose | Request DTO | Response DTO | Role Required |
|------------|----------|---------|------------|-------------|---------------|
| POST | `/otp/request` | Request OTP for login | `AuthDtos.OtpRequest` | `AuthDtos.OtpRequestAccepted` | PUBLIC |
| POST | `/otp/verify` | Verify OTP and get token | `AuthDtos.OtpVerifyRequest` | `AuthDtos.AuthenticatedSession` | PUBLIC |

**Endpoints Details**:
```
POST /api/v1/auth/otp/request
Content-Type: application/json
{
  "tenantPublicId": "T-1001",
  "role": "patient|doctor|admin",
  "mobileNumber": "9000000000"
}

Response:
{
  "data": {
    "tenantPublicId": "T-1001",
    "role": "patient",
    "mobileNumber": "9000000000",
    "otpHint": "0000"  # Dev: hardcoded "0000"
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

POST /api/v1/auth/otp/verify
Content-Type: application/json
{
  "tenantPublicId": "T-1001",
  "role": "patient",
  "mobileNumber": "9000000000",
  "otp": "0000"
}

Response:
{
  "data": {
    "tenantPublicId": "T-1001",
    "role": "patient",
    "subjectPublicId": "P-1234",  # Patient/Doctor/Admin ID
    "token": "eyJ0eXAi..."  # HMAC-SHA256 signed token
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

### 2. Patient Controller
**File**: `sevacare-api/src/main/java/com/sevacare/api/controller/PatientController.java`  
**Base Path**: `/api/v1/patients`  
**Authentication**: ✅ Bearer Token Required (except public endpoints)

| HTTP Method | Endpoint | Purpose | Request DTO | Response DTO | Roles Required |
|------------|----------|---------|------------|-------------|--------------|
| GET | `/{tenantPublicId}/{patientPublicId}/home` | Get patient dashboard | - | `PatientDtos.PatientHomeView` | PATIENT, DOCTOR, ADMIN |
| GET | `/{tenantPublicId}/{patientPublicId}/booking/setup` | Get booking setup data | - | `PatientDtos.BookingSetupView` | PATIENT, DOCTOR, ADMIN |
| POST | `/{tenantPublicId}/{patientPublicId}/appointments` | Book appointment | `PatientDtos.AppointmentBookingRequest` | `PatientDtos.AppointmentBookingResult` | PATIENT, DOCTOR, ADMIN |
| GET | `/{tenantPublicId}/records` | List all patients | - | `PatientDtos.PatientCollection` | ADMIN, DOCTOR |
| GET | `/{tenantPublicId}/records/{patientPublicId}` | Get single patient | - | `PatientDtos.PatientView` | ADMIN, DOCTOR, PATIENT |
| PUT | `/{tenantPublicId}/records/{patientPublicId}` | Create/Update patient | `PatientDtos.PatientUpsertRequest` | `PatientDtos.PatientView` | ADMIN, DOCTOR |
| DELETE | `/{tenantPublicId}/records/{patientPublicId}` | Delete patient | - | `String` ("deleted") | ADMIN, DOCTOR |
| GET | `/{tenantPublicId}/appointments` | List appointments | - | `PatientDtos.AppointmentCollection` | ADMIN, DOCTOR |
| GET | `/{tenantPublicId}/appointments/{appointmentPublicId}` | Get single appointment | - | `PatientDtos.AppointmentEntityView` | ADMIN, DOCTOR, PATIENT |
| PUT | `/{tenantPublicId}/appointments/{appointmentPublicId}` | Update appointment | `PatientDtos.AppointmentUpsertRequest` | `PatientDtos.AppointmentEntityView` | ADMIN, DOCTOR |
| DELETE | `/{tenantPublicId}/appointments/{appointmentPublicId}` | Delete appointment | - | `String` ("deleted") | ADMIN, DOCTOR |

**Key Endpoint Examples**:
```
GET /api/v1/patients/T-1001/P-1234/home
Authorization: Bearer {token}
X-Tenant-Id: T-1001

Response:
{
  "data": {
    "patientPublicId": "P-1234",
    "tenantPublicId": "T-1001",
    "appointments": [
      {
        "appointmentPublicId": "AP-5678",
        "doctorPublicId": "DR-1001",
        "doctorName": "Dr. Sanjay",
        "slot": "2024-03-22 10:30",
        "status": "confirmed",
        "note": "Regular checkup"
      }
    ],
    "prescriptions": [
      {
        "prescriptionPublicId": "RX-1001",
        "doctorPublicId": "DR-1001",
        "doctorName": "Dr. Sanjay",
        "issuedOn": "2024-03-20",
        "lines": ["Medication A - 500mg daily", "Medication B - 250mg twice"]
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

POST /api/v1/patients/T-1001/P-1234/appointments
Authorization: Bearer {token}
X-Tenant-Id: T-1001
Content-Type: application/json

{
  "tenantPublicId": "T-1001",
  "patientPublicId": "P-1234",
  "patientName": "John Doe",
  "gender": "M",
  "age": 35,
  "mobileNumber": "9000000000",
  "address": "123 Main St",
  "specialty": "Cardiology",
  "doctorPublicId": "DR-1001",
  "slot": "2024-03-22 10:30"
}

Response:
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
```

---

### 3. Doctor Controller
**File**: `sevacare-api/src/main/java/com/sevacare/api/controller/DoctorController.java`  
**Base Path**: `/api/v1/doctors`  
**Authentication**: ✅ Bearer Token Required

| HTTP Method | Endpoint | Purpose | Request DTO | Response DTO | Roles Required |
|------------|----------|---------|------------|-------------|--------------|
| GET | `/{tenantPublicId}/{doctorPublicId}/dashboard` | Get doctor dashboard | - | `DoctorDtos.DoctorDashboardView` | DOCTOR, ADMIN |
| POST | `/{tenantPublicId}/{doctorPublicId}/patients/{patientPublicId}/disable` | Disable patient access | `DoctorDtos.DisablePatientRequest` | `DoctorDtos.DisablePatientResult` | DOCTOR, ADMIN |
| GET | `/{tenantPublicId}/records` | List all doctors | - | `DoctorDtos.DoctorCollection` | ADMIN, DOCTOR |
| GET | `/{tenantPublicId}/records/{doctorPublicId}` | Get single doctor | - | `DoctorDtos.DoctorView` | ADMIN, DOCTOR |
| PUT | `/{tenantPublicId}/records/{doctorPublicId}` | Create/Update doctor | `DoctorDtos.DoctorUpsertRequest` | `DoctorDtos.DoctorView` | ADMIN, DOCTOR |
| DELETE | `/{tenantPublicId}/records/{doctorPublicId}` | Delete doctor | - | `String` ("deleted") | ADMIN, DOCTOR |

**Key Endpoint Examples**:
```
GET /api/v1/doctors/T-1001/DR-1001/dashboard
Authorization: Bearer {token}
X-Tenant-Id: T-1001

Response:
{
  "data": {
    "doctorPublicId": "DR-1001",
    "tenantPublicId": "T-1001",
    "totalAppointments": 42,
    "pendingNotes": 3,
    "nextPatientPublicId": "P-1234",
    "nextPatientName": "John Doe"
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

PUT /api/v1/doctors/T-1001/DR-1001/records/DR-1001
Authorization: Bearer {token}
X-Tenant-Id: T-1001
Content-Type: application/json

{
  "fullName": "Dr. Sanjay Kumar",
  "specialty": "Cardiology",
  "availability": "Mon-Fri 9AM-5PM",
  "fee": "₹500",
  "active": true
}

Response:
{
  "data": {
    "doctorPublicId": "DR-1001",
    "tenantPublicId": "T-1001",
    "fullName": "Dr. Sanjay Kumar",
    "specialty": "Cardiology",
    "availability": "Mon-Fri 9AM-5PM",
    "fee": "₹500",
    "active": true
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

### 4. Admin Controller
**File**: `sevacare-api/src/main/java/com/sevacare/api/controller/AdminController.java`  
**Base Path**: `/api/v1/admin`  
**Authentication**: ✅ Bearer Token Required (ADMIN only)

| HTTP Method | Endpoint | Purpose | Request DTO | Response DTO | Roles Required |
|------------|----------|---------|------------|-------------|--------------|
| GET | `/{tenantPublicId}/overview` | Get admin overview | - | `AdminDtos.AdminOverview` | ADMIN |
| POST | `/doctors` | Create doctor | `AdminDtos.CreateActorRequest` | `AdminDtos.ManagedActor` | ADMIN |
| DELETE | `/{tenantPublicId}/doctors/{doctorPublicId}` | Delete doctor | - | `AdminDtos.DeleteActorResult` | ADMIN |
| POST | `/patients` | Create patient | `AdminDtos.CreateActorRequest` | `AdminDtos.ManagedActor` | ADMIN |
| DELETE | `/{tenantPublicId}/patients/{patientPublicId}` | Delete patient | - | `AdminDtos.DeleteActorResult` | ADMIN |

**Key Endpoint Examples**:
```
GET /api/v1/admin/T-1001/overview
Authorization: Bearer {token}
X-Tenant-Id: T-1001

Response:
{
  "data": {
    "tenantPublicId": "T-1001",
    "metrics": [
      {
        "label": "Total Patients",
        "value": "245",
        "trend": "+12%"
      },
      {
        "label": "Total Doctors",
        "value": "18",
        "trend": "+2"
      },
      {
        "label": "Appointments Today",
        "value": "34",
        "trend": "+8%"
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

POST /api/v1/admin/doctors
Authorization: Bearer {token}
X-Tenant-Id: T-1001
Content-Type: application/json

{
  "tenantPublicId": "T-1001",
  "name": "Dr. Sanjay Kumar",
  "specialtyOrAgeBand": "Cardiology"
}

Response:
{
  "data": {
    "publicId": "DR-1001",
    "tenantPublicId": "T-1001",
    "name": "Dr. Sanjay Kumar",
    "action": "created"
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

### 5. Discovery Controller (Public APIs)
**File**: `sevacare-api/src/main/java/com/sevacare/api/controller/DiscoveryController.java`  
**Base Path**: `/api/v1/public`  
**Authentication**: ❌ Public endpoints (no authentication required)

| HTTP Method | Endpoint | Purpose | Request DTO | Response DTO |
|------------|----------|---------|------------|-------------|
| GET | `/tenants` | List all tenant hospitals | - | `DiscoveryDtos.TenantDirectory` |
| GET | `/tenants/{tenantPublicId}/doctors` | Search doctors by tenant | - | `DiscoveryDtos.DoctorDirectory` |
| GET | `/lookups` | Get reference data (specializations, cities) | - | `DiscoveryDtos.ReferenceLookups` |
| POST | `/onboarding/request` | Submit hospital onboarding request | `DiscoveryDtos.TenantOnboardingRequest` | `DiscoveryDtos.TenantOnboardingAccepted` |
| POST | `/onboarding/request-multipart` | Submit onboarding with file uploads | Multi-part form | `DiscoveryDtos.TenantOnboardingAccepted` |
| GET | `/onboarding/request/{requestPublicId}/documents` | List onboarding documents | - | `List<DiscoveryDtos.OnboardingDocumentView>` |
| GET | `/onboarding/request/{requestPublicId}/documents/{documentPublicId}/download` | Download onboarding document | - | File (Resource) |
| POST | `/tenants/{tenantPublicId}/doctors/register` | Register doctor (self-onboarding) | `DoctorDtos.DoctorOnboardingRequest` | `DoctorDtos.DoctorOnboardingResult` |

**Key Endpoint Examples**:
```
GET /api/v1/public/tenants

Response:
{
  "data": {
    "tenants": [
      {
        "tenantPublicId": "T-1001",
        "hospitalName": "Sunrise Care Hospital",
        "city": "Hyderabad",
        "specialty": "Multi-specialty",
        "themeKey": "sunrise"
      },
      {
        "tenantPublicId": "T-1002",
        "hospitalName": "City Medical Center",
        "city": "Bangalore",
        "specialty": "Multi-specialty",
        "themeKey": "city"
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

GET /api/v1/public/tenants/T-1001/doctors

Response:
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
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

GET /api/v1/public/lookups

Response:
{
  "data": {
    "specializations": [
      "Cardiology",
      "Dermatology",
      "Orthopedics",
      "Pediatrics",
      "Psychiatry"
    ],
    "cities": [
      "Hyderabad",
      "Bangalore",
      "Mumbai",
      "Delhi",
      "Chennai"
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

POST /api/v1/public/onboarding/request
Content-Type: application/json

{
  "hospitalName": "Sunrise Care",
  "licenseNumber": "LIC-9981",
  "state": "Telangana",
  "city": "Hyderabad",
  "address": "Road 1, Banjara Hills",
  "country": "India",
  "contactName": "Anil Kumar",
  "contactMobile": "9000000099",
  "contactEmail": "anil@example.com",
  "supportingDocs": "license.pdf",
  "facilityType": "hospital"
}

Response:
{
  "data": {
    "requestPublicId": "ONB-1234",
    "status": "submitted",
    "message": "Onboarding request submitted",
    "documents": []
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

POST /api/v1/public/onboarding/request-multipart
Content-Type: multipart/form-data

payload: {"hospitalName":"Sunrise Care","licenseNumber":"LIC-9981",...}
files: [file1.pdf, file2.docx]

Response:
{
  "data": {
    "requestPublicId": "ONB-1234",
    "status": "submitted",
    "message": "Onboarding request submitted",
    "documents": [
      {
        "documentPublicId": "DOC-5001",
        "fileName": "file1.pdf",
        "contentType": "application/pdf",
        "fileSize": 245612
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

---

POST /api/v1/public/tenants/T-1001/doctors/register
Content-Type: application/json

{
  "fullName": "Dr. Rajesh Sharma",
  "specialization": "Orthopedics",
  "mobileNumber": "9876543210",
  "age": 38,
  "gender": "M",
  "licenseNumber": "LIC-ORD-2024-001",
  "experienceYears": 12,
  "address": "Medical Plaza, xyz St",
  "city": "Hyderabad",
  "state": "Telangana",
  "appointmentIntervalMinutes": 30,
  "lunchBreakStartTime": "13:00",
  "lunchBreakEndTime": "14:00",
  "maxAppointmentsPerDay": 20,
  "workingDays": "Mon,Tue,Wed,Thu,Fri"
}

Response:
{
  "data": {
    "doctorPublicId": "DR-2001",
    "tenantPublicId": "T-1001",
    "status": "registered",
    "message": "Doctor registered successfully"
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

## Key Data Models/Entities

### Patient Entity
**File**: `sevacare-patient/src/main/java/com/sevacare/patient/entity/Patient.java`  
**Table**: `{tenant_schema}.patient`

```java
public class Patient {
    @Id
    private String patientPublicId;           // 16 chars, Primary Key
    private String tenantPublicId;             // 16 chars, Tenant reference
    private String fullName;                   // 120 chars, Patient's full name
    private String mobileNumber;               // 24 chars, Contact number
    private String status;                     // 24 chars, active/inactive
}
```

**Database Columns**:
- `patient_public_id` (VARCHAR(16)) - Unique patient identifier
- `tenant_public_id` (VARCHAR(16)) - Multi-tenant reference
- `full_name` (VARCHAR(120)) - Patient name
- `mobile_number` (VARCHAR(24)) - Contact number
- `status` (VARCHAR(24)) - Status (e.g., "active", "inactive")

---

### Appointment Entity
**File**: `sevacare-patient/src/main/java/com/sevacare/patient/entity/Appointment.java`  
**Table**: `{tenant_schema}.appointment`

```java
public class Appointment {
    @Id
    private String appointmentPublicId;       // 16 chars, Primary Key
    private String patientPublicId;           // 16 chars, Patient reference
    private String doctorPublicId;            // 16 chars, Doctor reference
    private String appointmentSlot;           // 80 chars, Date/time slot
    private String appointmentStatus;         // 24 chars, Status (confirmed/cancelled/completed)
    private String notes;                     // 300 chars, Appointment notes
}
```

**Database Columns**:
- `appointment_public_id` (VARCHAR(16)) - Unique appointment ID
- `patient_public_id` (VARCHAR(16)) - Patient reference
- `doctor_public_id` (VARCHAR(16)) - Doctor reference
- `appointment_slot` (VARCHAR(80)) - Date and time slot
- `appointment_status` (VARCHAR(24)) - Status
- `notes` (VARCHAR(300)) - Notes or description

---

### Doctor Entity
**File**: `sevacare-doctor/src/main/java/com/sevacare/doctor/entity/Doctor.java`  
**Table**: `{tenant_schema}.doctor`

```java
public class Doctor {
    @Id
    private String doctorPublicId;            // 16 chars, Primary Key
    private String tenantPublicId;            // 16 chars, Tenant reference
    private String fullName;                  // 120 chars, Doctor's full name
    private String specialty;                 // 120 chars, Medical specialty
    private String availability;              // 120 chars, Working hours
    private String fee;                       // 32 chars, Consultation fee
    private boolean active;                   // Boolean, Active status
}
```

**Database Columns**:
- `doctor_public_id` (VARCHAR(16)) - Unique doctor identifier
- `tenant_public_id` (VARCHAR(16)) - Multi-tenant reference
- `full_name` (VARCHAR(120)) - Doctor's name
- `specialty` (VARCHAR(120)) - Specialty (e.g., "Cardiology", "Orthopedics")
- `availability` (VARCHAR(120)) - Availability hours
- `fee` (VARCHAR(32)) - Consultation fee
- `active` (BOOLEAN) - Active/Inactive status

---

### AdminUser Entity
**File**: `sevacare-admin/src/main/java/com/sevacare/admin/entity/AdminUser.java`  
**Table**: `{tenant_schema}.admin_user`

```java
public class AdminUser {
    @Id
    private String adminPublicId;             // 16 chars, Primary Key
    private String tenantPublicId;            // 16 chars, Tenant reference
    private String fullName;                  // 120 chars, Admin's full name
    private boolean active;                   // Boolean, Active status
}
```

---

### TenantRegistry Entity (Multi-Tenancy)
**File**: `sevacare-tenant/src/main/java/com/sevacare/tenant/entity/TenantRegistry.java`  
**Table**: `public.tenant_registry` (Shared schema)

```java
public class TenantRegistry {
    @Id
    private String tenantPublicId;            // 16 chars, Primary Key
    private String tenantName;                // 120 chars, Hospital/Org name
    private String tenantThemeKey;            // 32 chars, UI theme
    private String tenantSchemaName;          // 63 chars, PostgreSQL schema name
    private String tenantStatus;              // 24 chars, active/inactive
}
```

**Database Columns**:
- `tenant_public_id` (VARCHAR(16)) - Unique tenant ID
- `tenant_name` (VARCHAR(120)) - Hospital/Organization name
- `tenant_theme_key` (VARCHAR(32)) - UI Theme (e.g., "sunrise", "city")
- `tenant_schema_name` (VARCHAR(63)) - PostgreSQL schema for data isolation
- `tenant_status` (VARCHAR(24)) - Status (active/inactive)

---

### Prescription Entity
**File**: `sevacare-patient/src/main/java/com/sevacare/patient/entity/Prescription.java`  
**Table**: `{tenant_schema}.prescription`

```java
public class Prescription {
    @Id
    private String prescriptionPublicId;
    private String patientPublicId;
    private String doctorPublicId;
    private String issuedDate;
    // Additional fields for medications
}
```

---

## DTOs (Request/Response)

### Authentication DTOs
**File**: `sevacare-shared/src/main/java/com/sevacare/shared/dto/AuthDtos.java`

```java
public record OtpRequest(
    @NotBlank String tenantPublicId,
    @NotBlank String role,                    // "patient", "doctor", "admin"
    @NotBlank String mobileNumber
) { }

public record OtpRequestAccepted(
    String tenantPublicId,
    String role,
    String mobileNumber,
    String otpHint                             // In dev: "0000"
) { }

public record OtpVerifyRequest(
    @NotBlank String tenantPublicId,
    @NotBlank String role,
    @NotBlank String mobileNumber,
    @NotBlank String otp
) { }

public record AuthenticatedSession(
    String tenantPublicId,
    String role,
    String subjectPublicId,                    // Patient/Doctor/Admin ID
    String token                               // HMAC-SHA256 signed token
) { }
```

---

### Patient DTOs
**File**: `sevacare-shared/src/main/java/com/sevacare/shared/dto/PatientDtos.java`

```java
// Home/Dashboard view
public record PatientHomeView(
    String patientPublicId,
    String tenantPublicId,
    List<AppointmentView> appointments,
    List<PrescriptionView> prescriptions
) { }

public record AppointmentView(
    String appointmentPublicId,
    String doctorPublicId,
    String doctorName,
    String slot,
    String status,
    String note
) { }

public record PrescriptionView(
    String prescriptionPublicId,
    String doctorPublicId,
    String doctorName,
    String issuedOn,
    List<String> lines
) { }

// Booking setup
public record BookingSetupView(
    String tenantPublicId,
    int slotIntervalMinutes,
    List<String> specialties
) { }

// Appointment booking request
public record AppointmentBookingRequest(
    @NotBlank String tenantPublicId,
    @NotBlank String patientPublicId,
    @NotBlank String patientName,
    @NotBlank String gender,
    @Min(0) int age,
    @NotBlank String mobileNumber,
    @NotBlank String address,
    @NotBlank String specialty,
    @NotBlank String doctorPublicId,
    @NotBlank String slot
) { }

public record AppointmentBookingResult(
    String appointmentPublicId,
    String tenantPublicId,
    String doctorPublicId,
    String patientPublicId,
    String slot,
    String status
) { }

// Patient CRUD
public record PatientView(
    String patientPublicId,
    String tenantPublicId,
    String fullName,
    String mobileNumber,
    String status
) { }

public record PatientUpsertRequest(
    @NotBlank String fullName,
    @NotBlank String mobileNumber,
    @NotBlank String status
) { }

public record PatientCollection(
    String tenantPublicId,
    List<PatientView> patients
) { }

// Appointment CRUD
public record AppointmentEntityView(
    String appointmentPublicId,
    String patientPublicId,
    String doctorPublicId,
    String slot,
    String status,
    String note
) { }

public record AppointmentUpsertRequest(
    @NotBlank String patientPublicId,
    @NotBlank String doctorPublicId,
    @NotBlank String slot,
    @NotBlank String status,
    @NotBlank String note
) { }

public record AppointmentCollection(
    String tenantPublicId,
    List<AppointmentEntityView> appointments
) { }
```

---

### Doctor DTOs
**File**: `sevacare-shared/src/main/java/com/sevacare/shared/dto/DoctorDtos.java`

```java
// Dashboard
public record DoctorDashboardView(
    String doctorPublicId,
    String tenantPublicId,
    int totalAppointments,
    int pendingNotes,
    String nextPatientPublicId,
    String nextPatientName
) { }

// Patient management
public record DisablePatientRequest(
    String reason
) { }

public record DisablePatientResult(
    String tenantPublicId,
    String patientPublicId,
    String status,
    String reason
) { }

// Doctor onboarding
public record DoctorOnboardingRequest(
    @NotBlank String fullName,
    @NotBlank String specialization,
    @Pattern(regexp = "^[0-9]{10}$") String mobileNumber,
    @Min(18) int age,
    @NotBlank String gender,
    @NotBlank String licenseNumber,
    @Min(0) int experienceYears,
    @NotBlank String address,
    @NotBlank String city,
    @NotBlank String state,
    @Min(10) int appointmentIntervalMinutes,
    @Pattern(regexp = "^\\d{2}:\\d{2}$") String lunchBreakStartTime,
    @Pattern(regexp = "^\\d{2}:\\d{2}$") String lunchBreakEndTime,
    @Min(1) int maxAppointmentsPerDay,
    @NotEmpty String workingDays
) { }

public record DoctorOnboardingResult(
    String doctorPublicId,
    String tenantPublicId,
    String status,
    String message
) { }

// Doctor CRUD
public record DoctorView(
    String doctorPublicId,
    String tenantPublicId,
    String fullName,
    String specialty,
    String availability,
    String fee,
    boolean active
) { }

public record DoctorUpsertRequest(
    @NotBlank String fullName,
    @NotBlank String specialty,
    @NotBlank String availability,
    @NotBlank String fee,
    boolean active
) { }

public record DoctorCollection(
    String tenantPublicId,
    List<DoctorView> doctors
) { }
```

---

### Discovery DTOs
**File**: `sevacare-shared/src/main/java/com/sevacare/shared/dto/DiscoveryDtos.java`

```java
// Public tenant directory
public record TenantSummary(
    String tenantPublicId,
    String hospitalName,
    String city,
    String specialty,
    String themeKey
) { }

public record TenantDirectory(
    List<TenantSummary> tenants
) { }

// Doctor search
public record DoctorSummary(
    String doctorPublicId,
    String name,
    String specialty,
    String availability,
    String fee
) { }

public record DoctorDirectory(
    String tenantPublicId,
    List<DoctorSummary> doctors
) { }

// Reference lookups
public record ReferenceLookups(
    List<String> specializations,
    List<String> cities
) { }

// Onboarding
public record TenantOnboardingRequest(
    @NotBlank String hospitalName,
    @NotBlank String licenseNumber,
    @NotBlank String state,
    @NotBlank String city,
    @NotBlank String address,
    @NotBlank String country,
    @NotBlank String contactName,
    @NotBlank String contactMobile,
    @NotBlank @Email String contactEmail,
    String supportingDocs,
    @NotBlank @Pattern(regexp = "hospital|clinic") String facilityType
) { }

public record TenantOnboardingAccepted(
    String requestPublicId,
    String status,
    String message,
    List<OnboardingDocumentView> documents
) { }

public record OnboardingDocumentView(
    String documentPublicId,
    String fileName,
    String contentType,
    long fileSize
) { }
```

---

### Admin DTOs
**File**: `sevacare-shared/src/main/java/com/sevacare/shared/dto/AdminDtos.java`

```java
public record AdminOverview(
    String tenantPublicId,
    List<Metric> metrics
) { }

public record Metric(
    String label,
    String value,
    String trend
) { }

public record CreateActorRequest(
    @NotBlank String tenantPublicId,
    @NotBlank String name,
    @NotBlank String specialtyOrAgeBand
) { }

public record ManagedActor(
    String publicId,
    String tenantPublicId,
    String name,
    String action
) { }

public record DeleteActorResult(
    String publicId,
    String tenantPublicId,
    String action
) { }
```

---

### Standard Response Wrapper
**File**: `sevacare-shared/src/main/java/com/sevacare/shared/dto/ContractResponse.java`

```java
public record ContractResponse<T>(
    T data,
    Instant generatedAt
) {
    public static <T> ContractResponse<T> of(T data) {
        return new ContractResponse<>(data, Instant.now());
    }
}
```

All API responses are wrapped in `ContractResponse` with timestamp.

---

## Authentication & Authorization

### Token-Based Authentication

**Token Format**: Base64-encoded payload + HMAC-SHA256 signature
```
{base64(payload)}.{signature}
Payload: {tenantPublicId}|{role}|{subjectPublicId}
Example: VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nP...
```

**Algorithm**: HMAC-SHA256  
**Secret Key**: `${SEVACARE_AUTH_SECRET:dev-sevacare-secret}` (from environment or application.yml)  
**Expiration**: No expiration currently implemented (tokens are long-lived)

#### Flow:
```
1. Client: POST /api/v1/auth/otp/request
   - Provides: tenantPublicId, role, mobileNumber

2. Server: Returns OTP hint (in dev: "0000")

3. Client: POST /api/v1/auth/otp/verify
   - Provides: tenantPublicId, role, mobileNumber, otp

4. Server: 
   - Validates OTP
   - Looks up first user of given role in tenant
   - Issues JWT-like token
   - Returns: token in AuthenticatedSession

5. Client: Includes token in Authorization header
   Authorization: Bearer {token}

6. Server: TokenAuthenticationFilter validates and extracts claims
   - Sets Spring Security context with role-based authorities
   - Allows @PreAuthorize("hasRole('PATIENT')") checks
```

### Authorization Patterns

#### Role-Based Access Control (@PreAuthorize)
```java
@PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")  // Any authenticated role
@PreAuthorize("hasRole('ADMIN')")                         // Admin only
@PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")            // Admin or Doctor
```

#### Tenant Validation
All authenticated endpoints validate tenant match:
```java
if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
    throw new IllegalArgumentException("Tenant mismatch");
}
```

### Security Components

**File**: `sevacare-api/src/main/java/com/sevacare/api/security/TokenService.java`
- Issues tokens with HMAC-SHA256 signature
- Parses and validates token signatures
- Extracts TokenClaims from token

**File**: `sevacare-api/src/main/java/com/sevacare/api/security/TokenAuthenticationFilter.java`
- Intercepts requests and extracts Bearer token
- Validates signature via TokenService
- Creates Spring Security authentication context
- Enables @PreAuthorize annotations

**File**: `sevacare-api/src/main/java/com/sevacare/api/config/SecurityConfiguration.java`
- Enables CORS for `http://localhost:8087` (frontend)
- Disables CSRF (stateless API)
- Permits public paths: `/api/v1/public/**`, `/api/v1/auth/**`, `/actuator/**`
- Requires authentication for all other paths
- Configures filter chain order

---

## Error Handling

### Exception Patterns

**File**: Controllers throw `IllegalArgumentException` for business logic errors

Common exceptions:
```java
// Invalid OTP
throw new IllegalArgumentException("Invalid OTP");

// Tenant mismatch
throw new IllegalArgumentException("Tenant mismatch");

// Invalid token
throw new IllegalArgumentException("Invalid token");

// Invalid token signature
throw new IllegalArgumentException("Invalid token signature");

// Unsupported role
throw new IllegalArgumentException("Unsupported role");

// Document not found
throw new IllegalArgumentException("Document not found: " + documentId);

// Stale data validation
throw new IllegalArgumentException("Invalid state for operation");
```

### Error Response Format
Spring Boot returns standard HTTP error responses:
```json
{
  "timestamp": "2024-03-21T10:30:00.000Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Invalid OTP",
  "path": "/api/v1/auth/otp/verify"
}
```

### HTTP Status Codes
- `200 OK` - Successful request
- `201 Created` - Resource created
- `204 No Content` - Successful deletion
- `400 Bad Request` - Invalid input or business logic error
- `401 Unauthorized` - Missing or invalid token
- `403 Forbidden` - Insufficient permissions (role-based)
- `404 Not Found` - Resource not found
- `409 Conflict` - Duplicate tenant/user
- `500 Internal Server Error` - Unexpected server error

### Validation
- Uses Jakarta Validation annotations (`@NotBlank`, `@Min`, `@Pattern`, `@Email`)
- Request body validation happens before controller method execution
- Invalid requests return 400 with validation error messages

---

## Multi-Tenancy Architecture

### Tenant Isolation Strategy

**Type**: Schema-per-tenant (PostgreSQL)

Each tenant has:
- Unique `tenantPublicId` (e.g., "T-1001")
- Dedicated PostgreSQL schema (e.g., "tenant_t_1001")
- Isolated data for patients, doctors, appointments, etc.

**Master/Shared Schema**: `public`
- Contains: `tenant_registry` table
- Stores tenant metadata and schema mappings

**Tenant-Specific Schemas**: `tenant_*`
- Contains: `patient`, `doctor`, `appointment`, `admin_user`, `prescription` tables
- Data isolations per tenant

### TenantContext (ThreadLocal)
**File**: `sevacare-shared/src/main/java/com/sevacare/shared/tenant/TenantContext.java`

ThreadLocal storage for request-scoped tenant information:
```java
public static void set(String tenantPublicId, String schema) {
    TENANT_PUBLIC_ID.set(tenantPublicId);
    TENANT_SCHEMA.set(schema);
}

public static String tenantPublicId() { }
public static String tenantSchema() { }
public static void clear() { }
```

### Tenant Resolution Flow

1. **TenantHeaderFilter** (first filter)
   - Extracts `X-Tenant-Id` header
   - Calls `TenantRegistryService.resolveTenantSchema(tenantPublicId)`
   - Sets TenantContext with tenant ID and schema name
   - Clears context after request

2. **TokenAuthenticationFilter** (after tenant filter)
   - Validates Bearer token
   - Sets Spring Security context

3. **Controller/Service**
   - Uses `TenantContext.tenantSchema()` for JPA queries
   - Validates tenant matches request parameters
   - All data queries scoped to tenant schema

### TenantRegistry Service
**File**: `sevacare-tenant/src/main/java/com/sevacare/tenant/service/TenantRegistryService.java`

Methods:
- `listTenantSummaries()` - Get all active tenants
- `mustFindActiveTenant(tenantPublicId)` - Validate tenant exists and is active
- `resolveTenantSchema(tenantPublicId)` - Get schema name for tenant
- `submitOnboardingRequest(...)` - Process new hospital onboarding

---

## Configuration

### Application Properties
**File**: `sevacare-api/src/main/resources/application.yml`

```yaml
spring:
  application:
    name: sevacare-api
  threads:                          # Virtual threads support (Java 21)
    virtual:
      enabled: true
  datasource:
    url: jdbc:postgresql://localhost:5432/seva_care
    username: postgres
    password: postgres
  jpa:
    hibernate:
      ddl-auto: none                # Let Flyway manage schema
    open-in-view: false             # Prevent lazy loading issues
    properties:
      hibernate:
        format_sql: true            # Pretty-print SQL logs
  flyway:
    enabled: true
    locations: classpath:db/migration
  servlet:
    multipart:
      max-file-size: 20MB
      max-request-size: 25MB

sevacare:
  auth:
    secret: dev-sevacare-secret     # HMAC-SHA256 secret for tokens
  storage:
    onboarding-dir: ${HOME}/sevacare-storage/onboarding

server:
  port: 8080                        # Default port (can override via PORT env var)

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: always          # Show detailed health info
```

### Environment Variables
```bash
SEVACARE_DB_URL=jdbc:postgresql://host:5432/sevacare
SEVACARE_DB_USERNAME=postgres
SEVACARE_DB_PASSWORD=postgres
SEVACARE_AUTH_SECRET=your-secret-key
SEVACARE_ONBOARDING_STORAGE_DIR=/path/to/storage
PORT=8081                          # Custom port
```

### Database Configuration
- **Type**: PostgreSQL
- **URL**: `jdbc:postgresql://localhost:5432/seva_care`
- **Credentials**: `postgres:postgres`
- **Migrations**: Managed by Flyway (in `classpath:db/migration`)
- **DDL**: Disabled (`ddl-auto: none`) - migrations only

### CORS Configuration
```java
Allowed Origins: http://localhost:8087
Allowed Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Allowed Headers: *
Exposed Headers: Authorization
```

### Health Check
```
GET /actuator/health
GET /actuator/info
GET /actuator/metrics
GET /actuator/prometheus
```

---

## Modules Overview

| Module | Purpose | Key Classes |
|--------|---------|------------|
| **sevacare-api** | Main Spring Boot application | SevaCareApiApplication, SecurityConfiguration, Controllers |
| **sevacare-shared** | DTos, security, common entities | DTOs, TokenClaims, TenantContext, ContractResponse |
| **sevacare-tenant** | Multi-tenant registry & reference data | TenantRegistry, TenantRegistryService, ReferenceDataService |
| **sevacare-patient** | Patient & appointment management | Patient, Appointment, Prescription entities |
| **sevacare-doctor** | Doctor management & dashboard | Doctor entity, DoctorDomainService |
| **sevacare-admin** | Admin functions & user management | AdminUser entity, AdminDomainService |

---

## File Structure Summary

```
sevacare-backend/
├── sevacare-api/
│   ├── src/main/java/com/sevacare/api/
│   │   ├── controller/
│   │   │   ├── AuthController.java          ⭐ Auth endpoints
│   │   │   ├── PatientController.java       ⭐ Patient endpoints
│   │   │   ├── DoctorController.java        ⭐ Doctor endpoints
│   │   │   ├── AdminController.java         ⭐ Admin endpoints
│   │   │   └── DiscoveryController.java     ⭐ Public discovery endpoints
│   │   ├── config/
│   │   │   ├── SecurityConfiguration.java   ⭐ Security & CORS config
│   │   │   ├── TenantHeaderFilter.java      ⭐ Tenant extraction
│   │   │   └── HibernateMultiTenantConfig.java
│   │   ├── security/
│   │   │   ├── TokenService.java            ⭐ Token issuance & validation
│   │   │   └── TokenAuthenticationFilter.java ⭐ Bearer token processing
│   │   └── service/
│   │       └── OnboardingDocumentService.java ⭐ Document storage
│   └── src/main/resources/
│       └── application.yml                  ⭐ Configuration
├── sevacare-shared/
│   └── src/main/java/com/sevacare/shared/
│       ├── dto/ ⭐ All DTOs
│       │   ├── AuthDtos.java
│       │   ├── PatientDtos.java
│       │   ├── DoctorDtos.java
│       │   ├── AdminDtos.java
│       │   ├── DiscoveryDtos.java
│       │   └── ContractResponse.java
│       ├── security/ ⭐ Security models
│       │   └── TokenClaims.java
│       └── tenant/ ⭐ Multi-tenancy
│           └── TenantContext.java
├── sevacare-tenant/
│   └── src/main/java/com/sevacare/tenant/
│       ├── entity/
│       │   └── TenantRegistry.java          ⭐ Tenant metadata
│       └── service/
│           ├── TenantRegistryService.java   ⭐ Tenant lookup & onboarding
│           └── ReferenceDataService.java
├── sevacare-patient/
│   └── src/main/java/com/sevacare/patient/
│       ├── entity/
│       │   ├── Patient.java                 ⭐ Patient entity
│       │   ├── Appointment.java             ⭐ Appointment entity
│       │   └── Prescription.java
│       ├── repository/
│       │   ├── PatientRepository.java
│       │   ├── AppointmentRepository.java
│       │   └── PrescriptionRepository.java
│       └── service/
│           └── PatientDomainService.java    ⭐ Patient business logic
├── sevacare-doctor/
│   └── src/main/java/com/sevacare/doctor/
│       ├── entity/
│       │   └── Doctor.java                  ⭐ Doctor entity
│       ├── repository/
│       │   └── DoctorRepository.java
│       └── service/
│           └── DoctorDomainService.java     ⭐ Doctor business logic
└── sevacare-admin/
    └── src/main/java/com/sevacare/admin/
        ├── entity/
        │   └── AdminUser.java               ⭐ Admin entity
        ├── repository/
        │   └── AdminUserRepository.java
        └── service/
            └── AdminDomainService.java      ⭐ Admin business logic
```

---

## Quick Reference: API Endpoint Summary

### Public APIs (No Auth Required)
```
GET  /api/v1/public/tenants
GET  /api/v1/public/tenants/{tenantId}/doctors
GET  /api/v1/public/lookups
POST /api/v1/public/onboarding/request
POST /api/v1/public/onboarding/request-multipart
GET  /api/v1/public/onboarding/request/{id}/documents
GET  /api/v1/public/onboarding/request/{id}/documents/{docId}/download
POST /api/v1/public/tenants/{tenantId}/doctors/register
```

### Auth APIs (No Auth Required)
```
POST /api/v1/auth/otp/request
POST /api/v1/auth/otp/verify
```

### Patient APIs (Auth Required, Role: PATIENT/DOCTOR/ADMIN)
```
GET  /api/v1/patients/{tenantId}/{patientId}/home
GET  /api/v1/patients/{tenantId}/{patientId}/booking/setup
POST /api/v1/patients/{tenantId}/{patientId}/appointments
GET  /api/v1/patients/{tenantId}/records
GET  /api/v1/patients/{tenantId}/records/{patientId}
PUT  /api/v1/patients/{tenantId}/records/{patientId}
DELETE /api/v1/patients/{tenantId}/records/{patientId}
GET  /api/v1/patients/{tenantId}/appointments
GET  /api/v1/patients/{tenantId}/appointments/{appointmentId}
PUT  /api/v1/patients/{tenantId}/appointments/{appointmentId}
DELETE /api/v1/patients/{tenantId}/appointments/{appointmentId}
```

### Doctor APIs (Auth Required, Role: DOCTOR/ADMIN)
```
GET  /api/v1/doctors/{tenantId}/{doctorId}/dashboard
POST /api/v1/doctors/{tenantId}/{doctorId}/patients/{patientId}/disable
GET  /api/v1/doctors/{tenantId}/records
GET  /api/v1/doctors/{tenantId}/records/{doctorId}
PUT  /api/v1/doctors/{tenantId}/records/{doctorId}
DELETE /api/v1/doctors/{tenantId}/records/{doctorId}
```

### Admin APIs (Auth Required, Role: ADMIN)
```
GET  /api/v1/admin/{tenantId}/overview
POST /api/v1/admin/doctors
DELETE /api/v1/admin/{tenantId}/doctors/{doctorId}
POST /api/v1/admin/patients
DELETE /api/v1/admin/{tenantId}/patients/{patientId}
```

### Health Checks
```
GET /actuator/health
GET /actuator/info
GET /actuator/metrics
GET /actuator/prometheus
```

---

## Key Technical Highlights

✅ **Multi-Tenancy**: Schema-per-tenant PostgreSQL isolation  
✅ **Security**: HMAC-SHA256 tokens with role-based access control  
✅ **Validation**: Jakarta Bean Validation on all inputs  
✅ **Error Handling**: Consistent error responses with HTTP status codes  
✅ **CORS**: Properly configured for frontend at `http://localhost:8087`  
✅ **Documentation**: Full endpoint specification with DTOs  
✅ **Observability**: Actuator endpoints for health and metrics  
✅ **Database**: PostgreSQL with Flyway migrations  
✅ **Java 21**: Virtual threads support enabled for better concurrency
