# SevaCare Backend - Quick Reference Guide

## 🔑 Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   AUTHENTICATION FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Client                                                   │
│     │                                                         │
│     ├──→ POST /api/v1/auth/otp/request                       │
│     │    { tenantPublicId, role, mobileNumber }             │
│     │                                                         │
│     └──← OTP Response (dev: 0000)                            │
│                                                               │
│  2. Client                                                   │
│     │                                                         │
│     ├──→ POST /api/v1/auth/otp/verify                        │
│     │    { tenantPublicId, role, mobileNumber, otp }        │
│     │                                                         │
│     └──← AuthenticatedSession                               │
│          { token, subjectPublicId, role }                   │
│                                                               │
│  3. Client (Subsequent Requests)                            │
│     │                                                         │
│     ├──→ GET /api/v1/patients/.../home                      │
│     │    Headers:                                            │
│     │      Authorization: Bearer {token}                    │
│     │      X-Tenant-Id: T-1001                              │
│     │                                                         │
│     └──← PatientHomeView { appointments, prescriptions }     │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏥 Multi-Tenancy Architecture

```
┌──────────────────────────────────────────────────────────────┐
│               PostgreSQL Database Structure                   │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────────────────────────────┐                │
│  │  PUBLIC SCHEMA (Shared Across Tenants)  │                │
│  ├─────────────────────────────────────────┤                │
│  │  • tenant_registry                      │                │
│  │    - tenantPublicId (T-1001)           │                │
│  │    - tenantName (Hospital Name)        │                │
│  │    - tenantSchemaName (tenant_t_1001)  │                │
│  │    - tenantThemeKey (sunrise)          │                │
│  │    - tenantStatus (active)             │                │
│  └─────────────────────────────────────────┘                │
│                         │                                     │
│         ┌───────────────┼───────────────┐                   │
│         │               │               │                   │
│         ▼               ▼               ▼                   │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐  │
│  │TENANT_T_1001   │ │TENANT_T_1002   │ │TENANT_T_XXXX   │  │
│  ├────────────────┤ ├────────────────┤ ├────────────────┤  │
│  │• patient       │ │• patient       │ │• patient       │  │
│  │• doctor        │ │• doctor        │ │• doctor        │  │
│  │• appointment   │ │• appointment   │ │• appointment   │  │
│  │• admin_user    │ │• admin_user    │ │• admin_user    │  │
│  │• prescription  │ │• prescription  │ │• prescription  │  │
│  └────────────────┘ └────────────────┘ └────────────────┘  │
│   Sunrise Care      City Medical      Other Hospitals     │
│   (Hyderabad)       (Bangalore)                            │
│                                                                │
└──────────────────────────────────────────────────────────────┘

Request Flow:
  1. Extract X-Tenant-Id header (e.g., "T-1001")
  2. Look up schema name in public.tenant_registry
  3. Set TenantContext.tenantSchema = "tenant_t_1001"
  4. All JPA queries use tenant_t_1001 schema
  5. Data isolation guaranteed
```

---

## 👥 Role-Based Access Control (RBAC)

```
┌─────────────────────────────────────────────────────────────┐
│              ROLES & PERMISSIONS MATRIX                      │
├──────────────────┬──────────┬──────────┬────────────────────┤
│   ENDPOINT       │ PATIENT  │  DOCTOR  │  ADMIN             │
├──────────────────┼──────────┼──────────┼────────────────────┤
│ /patients/.../home    │    ✅    │    ✅    │    ✅             │
│ /patients/records     │    ❌    │    ✅    │    ✅            │
│ /patients/records/{id}│    ✅    │    ✅    │    ✅            │
│ /appointments          │    ❌    │    ✅    │    ✅            │
│ /doctors/dashboard    │    ❌    │    ✅    │    ✅            │
│ /doctors/records      │    ❌    │    ✅    │    ✅            │
│ /admin/overview       │    ❌    │    ❌    │    ✅            │
│ /admin/doctors (POST) │    ❌    │    ❌    │    ✅            │
│ /admin/patients (POST)│    ❌    │    ❌    │    ✅            │
├──────────────────┴──────────┴──────────┴────────────────────┤
│ PUBLIC APIs (No Authentication Required)                     │
├──────────────────────────────────────────────────────────────┤
│ /public/tenants                                              │
│ /public/tenants/{id}/doctors                                 │
│ /public/lookups (specializations, cities)                   │
│ /public/onboarding/request                                   │
│ /auth/otp/request & /auth/otp/verify                        │
└──────────────────────────────────────────────────────────────┘
```

---

## 📊 Core Data Models

```
┌──────────────────────────────────────────────────────────────┐
│                   ENTITY RELATIONSHIPS                        │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│                    ┌─────────────────┐                       │
│                    │ TenantRegistry  │                       │
│                    ├─────────────────┤                       │
│                    │ tenantPublicId  │ ◄─┐                  │
│                    │ tenantName      │   │                  │
│                    │ tenantSchemaName│   │                  │
│                    │ tenantThemeKey  │   │                  │
│                    │ tenantStatus    │   │                  │
│                    └─────────────────┘   │                  │
│                          ▲                │                  │
│                          │ 1:N            │                  │
│          ┌───────────────┼─┬──────────────┼─────────────┐   │
│          │               │ │              │             │   │
│          ▼               ▼ ▼              ▼             ▼   │
│    ┌──────────┐    ┌──────────┐   ┌──────────┐    ┌─────── │
│    │ Patient  │    │ Doctor   │   │ AdminUser│    │ Prescr  │
│    ├──────────┤    ├──────────┤   ├──────────┤    ├──────   │
│    │ patientId│    │ doctorId │   │ adminId  │    │prescId  │
│    │ fullName │    │ fullName │   │ fullName │    │ patId   │
│    │ mobile   │    │specialty │   │ active   │    │ docId   │
│    │ status   │    │ fee      │   └──────────┘    │ issued  │
│    └────▲─────┘    │ active   │                   │ lines   │
│         │          └────┬─────┘                   └─────────┤
│         │               │                                    │
│         │ 1:N           │ N:1                               │
│         └───────┬───────┴────────────────────────────────┐  │
│                 │                                         │  │
│                 ▼                                         │  │
│          ┌──────────────┐                                │  │
│          │ Appointment │                                │  │
│          ├──────────────┤                                │  │
│          │ appointmentId│                                │  │
│          │ patientId    │◄─────────────────────────────┘  │
│          │ doctorId     │                                 │
│          │ slot         │                                 │
│          │ status       │                                 │
│          │ notes        │                                 │
│          └──────────────┘                                 │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 API Endpoint Categories

### 🔓 Public Discovery APIs (No Auth)
```
GET  /api/v1/public/tenants
     └─→ List all active hospitals

GET  /api/v1/public/tenants/{tenantId}/doctors
     └─→ Search doctors by hospital

GET  /api/v1/public/lookups
     └─→ Reference data (specializations, cities)

POST /api/v1/public/onboarding/request
     └─→ Hospital onboarding request (JSON)

POST /api/v1/public/onboarding/request-multipart
     └─→ Hospital onboarding with file uploads

GET  /api/v1/public/onboarding/request/{id}/documents
     └─→ List uploaded documents

GET  /api/v1/public/onboarding/request/{id}/documents/{docId}/download
     └─→ Download document

POST /api/v1/public/tenants/{tenantId}/doctors/register
     └─→ Doctor self-onboarding
```

### 🔑 Authentication APIs (No Auth)
```
POST /api/v1/auth/otp/request
     └─→ Request OTP (SMS in prod)

POST /api/v1/auth/otp/verify
     └─→ Verify OTP & get token
```

### 👨‍⚕️ Patient APIs (Auth Required)
```
GET  /api/v1/patients/{tenantId}/{patientId}/home
     └─→ Patient dashboard (appointments + prescriptions)

GET  /api/v1/patients/{tenantId}/{patientId}/booking/setup
     └─→ Get booking form data (specialties, slot interval)

POST /api/v1/patients/{tenantId}/{patientId}/appointments
     └─→ Book new appointment

GET  /api/v1/patients/{tenantId}/records
     └─→ List all patients (ADMIN/DOCTOR only)

GET  /api/v1/patients/{tenantId}/records/{patientId}
     └─→ Get patient details

PUT  /api/v1/patients/{tenantId}/records/{patientId}
     └─→ Create/update patient info

DELETE /api/v1/patients/{tenantId}/records/{patientId}
     └─→ Delete patient record

GET  /api/v1/patients/{tenantId}/appointments
     └─→ List appointments (ADMIN/DOCTOR only)

GET  /api/v1/patients/{tenantId}/appointments/{appointmentId}
     └─→ Get appointment details

PUT  /api/v1/patients/{tenantId}/appointments/{appointmentId}
     └─→ Update appointment

DELETE /api/v1/patients/{tenantId}/appointments/{appointmentId}
     └─→ Cancel appointment
```

### 👨‍⚕️ Doctor APIs (Auth Required)
```
GET  /api/v1/doctors/{tenantId}/{doctorId}/dashboard
     └─→ Doctor dashboard (appointments count, pending tasks)

POST /api/v1/doctors/{tenantId}/{doctorId}/patients/{patientId}/disable
     └─→ Disable patient access (e.g., unpaid)

GET  /api/v1/doctors/{tenantId}/records
     └─→ List all doctors

GET  /api/v1/doctors/{tenantId}/records/{doctorId}
     └─→ Get doctor profile

PUT  /api/v1/doctors/{tenantId}/records/{doctorId}
     └─→ Update doctor profile

DELETE /api/v1/doctors/{tenantId}/records/{doctorId}
     └─→ Deactivate doctor
```

### 🛡️ Admin APIs (Auth Required - ADMIN Only)
```
GET  /api/v1/admin/{tenantId}/overview
     └─→ Admin dashboard (metrics)

POST /api/v1/admin/doctors
     └─→ Create doctor account

DELETE /api/v1/admin/{tenantId}/doctors/{doctorId}
     └─→ Delete doctor

POST /api/v1/admin/patients
     └─→ Create patient account

DELETE /api/v1/admin/{tenantId}/patients/{patientId}
     └─→ Delete patient
```

### 🏥 Health Checks
```
GET  /actuator/health          # Health status
GET  /actuator/info            # App info
GET  /actuator/metrics         # Metrics list
GET  /actuator/prometheus      # Prometheus metrics
```

---

## 📡 Request/Response Examples

### Example 1: Login Flow
```bash
# Step 1: Request OTP
curl -X POST http://localhost:8081/api/v1/auth/otp/request \
  -H "Content-Type: application/json" \
  -d '{
    "tenantPublicId": "T-1001",
    "role": "patient",
    "mobileNumber": "9000000000"
  }'

Response:
{
  "data": {
    "tenantPublicId": "T-1001",
    "role": "patient",
    "mobileNumber": "9000000000",
    "otpHint": "0000"
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}

# Step 2: Verify OTP
curl -X POST http://localhost:8081/api/v1/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{
    "tenantPublicId": "T-1001",
    "role": "patient",
    "mobileNumber": "9000000000",
    "otp": "0000"
  }'

Response:
{
  "data": {
    "tenantPublicId": "T-1001",
    "role": "patient",
    "subjectPublicId": "P-1234",
    "token": "VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nP..."
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

### Example 2: Patient Home/Dashboard
```bash
curl -X GET http://localhost:8081/api/v1/patients/T-1001/P-1234/home \
  -H "Authorization: Bearer VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nP..." \
  -H "X-Tenant-Id: T-1001"

Response:
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
      }
    ],
    "prescriptions": [
      {
        "prescriptionPublicId": "RX-1001",
        "doctorPublicId": "DR-1001",
        "doctorName": "Dr. Sanjay Kumar",
        "issuedOn": "2024-03-20",
        "lines": ["Medication A - 500mg daily"]
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

### Example 3: Book Appointment
```bash
curl -X POST http://localhost:8081/api/v1/patients/T-1001/P-1234/appointments \
  -H "Authorization: Bearer {token}" \
  -H "X-Tenant-Id: T-1001" \
  -H "Content-Type: application/json" \
  -d '{
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
  }'

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

### Example 4: Doctor Search
```bash
curl -X GET http://localhost:8081/api/v1/public/tenants/T-1001/doctors

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
      },
      {
        "doctorPublicId": "DR-1002",
        "name": "Dr. Priya Sharma",
        "specialty": "Dermatology",
        "availability": "Tue-Thu 10AM-2PM",
        "fee": "₹400"
      }
    ]
  },
  "generatedAt": "2024-03-21T10:30:00Z"
}
```

---

## 🔐 Security Implementation

### Token Structure
```
Token = {base64_encoded_payload}.{hmac_sha256_signature}

Example:
  VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nPqRsT...
  ▲                                    ▲
  Payload (Base64)                     Signature (Base64)

Payload (decoded): T-1001|patient|P-1234
  └─→ tenantPublicId|role|subjectPublicId
```

### Header Requirements
```http
Authorization: Bearer {token}
X-Tenant-Id: {tenantPublicId}

Example:
Authorization: Bearer VDEtMDAxfHBhdGllbnR8UC0xMjM0.oFhsH8qL2kM9nPqRsT...
X-Tenant-Id: T-1001
```

### Security Validation Flow
```
Request Received
    │
    ├──→ TenantHeaderFilter
    │     │
    │     ├─ Extract X-Tenant-Id header
    │     ├─ Look up schema in tenant_registry
    │     ├─ Set TenantContext (ThreadLocal)
    │     └─ Continue chain
    │
    ├──→ TokenAuthenticationFilter
    │     │
    │     ├─ Extract Bearer token
    │     ├─ Parse token & verify signature
    │     ├─ Extract TokenClaims
    │     ├─ Create Spring Security context
    │     └─ Set Granted Authorities (ROLE_PATIENT, etc)
    │
    ├──→ Controller
    │     │
    │     ├─ @PreAuthorize annotation checked
    │     ├─ Tenant validation (tenantId mismatch check)
    │     ├─ Execute business logic
    │     └─ Return response
    │
    └──→ Response sent, TenantContext cleared
```

---

## 📝 Common Validation Rules

| Field | Rule | Example |
|-------|------|---------|
| `mobileNumber` | Exactly 10 digits | `9876543210` |
| `tenantPublicId` | Max 16 chars | `T-1001` |
| `doctorPublicId` | Max 16 chars | `DR-1001` |
| `patientPublicId` | Max 16 chars | `P-1234` |
| `licenseNumber` | Non-blank | `LIC-ORD-2024-001` |
| `age` | >= 18 (for doctors), >= 0 (for patients) | `35` |
| `specialization` | Non-blank | `Cardiology` |
| `email` | Valid email format | `anil@example.com` |
| `facilityType` | "hospital" or "clinic" | `hospital` |
| `appointmentInterval` | >= 10 minutes | `30` |
| `timeFormat` | HH:mm (24-hour) | `14:30` |

---

## 🗄️ Database Multi-Tenancy

### Data Isolation Strategy
```
PostgreSQL Schema Per Tenant:
- Each tenant has dedicated schema
- Complete data isolation
- Same connection string for all tenants
- Schema resolution via TenantRegistry

Public Schema (Shared):
  public.tenant_registry
    └─ Maps T-1001 → tenant_t_1001
    └─ Maps T-1002 → tenant_t_1002

Tenant Schemas (Isolated):
  tenant_t_1001.patient
  tenant_t_1001.doctor
  tenant_t_1001.appointment
  tenant_t_1001.admin_user
  tenant_t_1001.prescription

  tenant_t_1002.patient
  tenant_t_2002.doctor
  ...
```

### On-Boarding NEW Tenant:
```
1. Client: POST /api/v1/public/onboarding/request
2. Server:
   - Create entry in public.tenant_registry
   - Create new PostgreSQL schema (tenant_t_XXXX)
   - Execute migration scripts in new schema
   - Return onboarding confirmation
```

---

## 🚀 Environment Setup

### Required Environment Variables
```bash
# Database
export SEVACARE_DB_URL=jdbc:postgresql://localhost:5432/sevacare
export SEVACARE_DB_USERNAME=postgres
export SEVACARE_DB_PASSWORD=postgres

# Auth Secret
export SEVACARE_AUTH_SECRET=your-128-bit-secret-key

# Storage
export SEVACARE_ONBOARDING_STORAGE_DIR=/data/sevacare/onboarding

# Server
export PORT=8081
```

### Default Values
```
Database:     jdbc:postgresql://localhost:5432/seva_care
Username:     postgres
Password:     postgres
Auth Secret:  dev-sevacare-secret
API Port:     8080
```

---

## 📚 File Locations (Key Files)

**Controllers**:
- `sevacare-api/src/main/java/com/sevacare/api/controller/AuthController.java`
- `sevacare-api/src/main/java/com/sevacare/api/controller/PatientController.java`
- `sevacare-api/src/main/java/com/sevacare/api/controller/DoctorController.java`
- `sevacare-api/src/main/java/com/sevacare/api/controller/AdminController.java`
- `sevacare-api/src/main/java/com/sevacare/api/controller/DiscoveryController.java`

**DTOs**:
- `sevacare-shared/src/main/java/com/sevacare/shared/dto/AuthDtos.java`
- `sevacare-shared/src/main/java/com/sevacare/shared/dto/PatientDtos.java`
- `sevacare-shared/src/main/java/com/sevacare/shared/dto/DoctorDtos.java`
- `sevacare-shared/src/main/java/com/sevacare/shared/dto/AdminDtos.java`
- `sevacare-shared/src/main/java/com/sevacare/shared/dto/DiscoveryDtos.java`

**Entities**:
- `sevacare-patient/src/main/java/com/sevacare/patient/entity/Patient.java`
- `sevacare-patient/src/main/java/com/sevacare/patient/entity/Appointment.java`
- `sevacare-doctor/src/main/java/com/sevacare/doctor/entity/Doctor.java`
- `sevacare-admin/src/main/java/com/sevacare/admin/entity/AdminUser.java`
- `sevacare-tenant/src/main/java/com/sevacare/tenant/entity/TenantRegistry.java`

**Security**:
- `sevacare-api/src/main/java/com/sevacare/api/security/TokenService.java`
- `sevacare-api/src/main/java/com/sevacare/api/security/TokenAuthenticationFilter.java`
- `sevacare-api/src/main/java/com/sevacare/api/config/SecurityConfiguration.java`
- `sevacare-api/src/main/java/com/sevacare/api/config/TenantHeaderFilter.java`

**Configuration**:
- `sevacare-api/src/main/resources/application.yml`

---

## ✅ Testing Checklist

- [ ] All public endpoints accessible without token
- [ ] OTP request returns correct hint (dev: 0000)
- [ ] OTP verification issues valid token
- [ ] Token verification fails for invalid signatures
- [ ] X-Tenant-Id header required for protected endpoints
- [ ] Tenant mismatch returns 400 error
- [ ] Role-based access control enforced
- [ ] Patients see only their own data
- [ ] Doctors cannot access admin endpoints
- [ ] Admins can manage all resources
- [ ] Appointments created only for valid doctor/patient
- [ ] Multiple tenants have isolated data
- [ ] Health check endpoints accessible

---

## 🐛 Debugging Tips

**Enable SQL Logging**:
```yaml
spring:
  jpa:
    properties:
      hibernate:
        format_sql: true
logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

**Check Tenant Context**:
```java
System.out.println("Tenant ID: " + TenantContext.tenantPublicId());
System.out.println("Schema: " + TenantContext.tenantSchema());
```

**Test Token Manually**:
```bash
# Decode token (first part is base64)
echo "VDEtMDAxfHBhdGllbnR8UC0xMjM0" | base64 -d
# Output: T-1001|patient|P-1234
```

**Common Issues**:
- ❌ 401 Unauthorized → Check Bearer token format and signature
- ❌ 403 Forbidden → Check role via token claims
- ❌ 400 Tenant mismatch → Ensure X-Tenant-Id matches token
- ❌ NullPointerException → Check TenantContext setup in filter chain
- ❌ No results → Verify queries use correct tenant schema
