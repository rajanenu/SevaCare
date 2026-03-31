# Phase 3: Prescriptions Feature - Implementation Plan

**Date**: March 21, 2026  
**Status**: Planning  
**Scope**: Prescription upload, viewing, download, and medical history

---

## Feature Overview

### 1. Prescription Upload (Doctor)

**User Story**: Doctor can upload prescriptions after appointment

**API Endpoint** (To be implemented):
```
POST /doctors/{tenantId}/{doctorId}/prescriptions
Authorization: Bearer {token}
X-Tenant-Id: {tenantId}

Request Body:
{
  "patientPublicId": "P-1234",
  "appointmentPublicId": "AP-5678",  // Optional: link to appointment
  "medicines": [
    {
      "name": "Paracetamol",
      "strength": "500mg",
      "frequency": "Twice daily",
      "duration": "7 days",
      "instructions": "Take with food"
    }
  ],
  "notes": "Continue previous medication",
  "file": <PDF file>  // Optional
}

Response:
{
  "prescriptionPublicId": "RX-1001",
  "status": "issued",
  "issuedAt": "2026-03-21T10:30:00Z"
}
```

### 2. Prescription Viewing (Patient)

**User Story**: Patient can view all prescribed medicines

**API Endpoint** (Existing in PatientHomeView):
```
GET /patients/{tenantId}/{patientId}/prescriptions
Authorization: Bearer {token}

Response:
{
  "prescriptions": [
    {
      "prescriptionPublicId": "RX-1001",
      "doctorPublicId": "DR-1001",
      "doctorName": "Dr. Sanjay Kumar",
      "issuedOn": "2026-03-21",
      "medicines": [
        {
          "name": "Paracetamol",
          "strength": "500mg",
          "frequency": "Twice daily",
          "duration": "7 days"
        }
      ],
      "notes": "Continue previous medication",
      "fileUrl": "/download/RX-1001"
    }
  ]
}
```

### 3. Prescription Download (Patient)

**API Endpoint** (To be implemented):
```
GET /prescriptions/{prescriptionId}/download
Authorization: Bearer {token}

Response: PDF file
```

### 4. Medical History (Patient)

**User Story**: Patient can view all medical records

**API Endpoint** (To be defined):
```
GET /patients/{tenantId}/{patientId}/medical-history
Authorization: Bearer {token}

Response:
{
  "appointments": [...],
  "prescriptions": [...],
  "allergies": ["Penicillin", "Nuts"],
  "conditions": ["Hypertension", "Diabetes"],
  "lastCheckup": "2026-02-15",
  "followUpRequired": true
}
```

---

## Frontend Implementation

### 1. Prescription Screen Components

#### PrescriptionListScreen
```typescript
interface PrescriptionListScreenProps {
  tenantId: string;
  patientId: string;
  onSelectPrescription: (prescriptionId: string) => void;
  onDownload: (prescriptionId: string) => void;
}

// Features:
// - List all prescriptions with dates
// - Filter by date range
// - Search by doctor name
// - Sort by date (newest first)
// - Download button for each
```

#### PrescriptionDetailScreen
```typescript
interface PrescriptionDetailScreenProps {
  prescriptionId: string;
  tenantId: string;
  patientId: string;
  onClose: () => void;
  onDownload: () => void;
}

// Features:
// - Show full prescription details
// - Display medicines in table format
// - Show doctor notes
// - Download option
// - Share option
// - Print option
```

#### MedicineUploadScreen (Doctor)
```typescript
interface MedicineUploadScreenProps {
  tenantId: string;
  doctorId: string;
  patientId: string;
  appointmentId?: string;
  onSuccess: (prescriptionId: string) => void;
}

// Features:
// - Add multiple medicines
// - Input: name, strength, frequency, duration, instructions
// - Add notes
// - Upload PDF (optional)
// - Preview before submission
```

### 2. React Hooks for Prescriptions

```typescript
// usePatientPrescriptions.ts
export function usePatientPrescriptions(
  tenantId: string,
  patientId: string,
  token: string
): {
  prescriptions: PrescriptionView[];
  loading: boolean;
  error: ApiError | null;
  refresh: () => Promise<void>;
}

// usePrescriptionUpload.ts
export function usePrescriptionUpload(
  tenantId: string,
  doctorId: string,
  token: string
): {
  upload: (data: PrescriptionUploadData) => Promise<void>;
  uploading: boolean;
  error: ApiError | null;
}

// usePrescriptionDownload.ts
export function usePrescriptionDownload(
  prescriptionId: string,
  token: string
): {
  download: () => Promise<Blob>;
  downloading: boolean;
  error: ApiError | null;
}
```

### 3. Network & Caching

```typescript
// With React Query for caching
const prescriptionsQuery = useQuery(
  ['prescriptions', patientId],
  () => sevacareApi.getPatientPrescriptions(tenantId, patientId, token),
  {
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 30 * 60 * 1000, // 30 minutes
  }
);

// For offline support (Phase 4)
// Store prescriptions in SQLite cache
```

---

## Backend Implementation

### Database Schema

```sql
-- Prescription table
CREATE TABLE dt_prescription (
  id SERIAL PRIMARY KEY,
  prescription_public_id VARCHAR(20) UNIQUE NOT NULL,
  appointment_id INTEGER REFERENCES dt_appointment,
  doctor_id INTEGER REFERENCES dt_doctor NOT NULL,
  patient_id INTEGER REFERENCES dt_patient NOT NULL,
  issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  issued_on DATE DEFAULT CURRENT_DATE,
  notes TEXT,
  file_url VARCHAR,
  status VARCHAR(20) DEFAULT 'active', -- active, cancelled, expired
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Medicine details (as JSON or separate table)
CREATE TABLE dt_prescription_medicine (
  id SERIAL PRIMARY KEY,
  prescription_id INTEGER REFERENCES dt_prescription,
  medicine_name VARCHAR(255) NOT NULL,
  strength VARCHAR(100),
  frequency VARCHAR(255) NOT NULL,
  duration VARCHAR(100),
  instructions TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Medical history tracking
CREATE TABLE dt_medical_history (
  id SERIAL PRIMARY KEY,
  patient_id INTEGER REFERENCES dt_patient,
  record_type VARCHAR(50), -- 'allergy', 'condition', 'surgery', etc.
  record_value VARCHAR(255) NOT NULL,
  notes TEXT,
  record_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### API Controllers

```java
// PrescriptionController.java
@RestController
@RequestMapping("/api/v1/prescriptions")
public class PrescriptionController {
  
  // Upload prescription (Doctor)
  @PostMapping("/{tenantId}/{doctorId}/upload")
  public ResponseEntity<PrescriptionDto> uploadPrescription(
    @PathVariable String tenantId,
    @PathVariable String doctorId,
    @RequestBody PrescriptionUploadRequest request,
    @RequestHeader("Authorization") String token
  );
  
  // Get patient prescriptions (Patient)
  @GetMapping("/{tenantId}/{patientId}")
  public ResponseEntity<PrescriptionCollectionDto> getPatientPrescriptions(
    @PathVariable String tenantId,
    @PathVariable String patientId,
    @RequestHeader("Authorization") String token
  );
  
  // Get prescription detail (Patient/Doctor)
  @GetMapping("/{tenantId}/{prescriptionId}/detail")
  public ResponseEntity<PrescriptionDetailDto> getPrescriptionDetail(
    @PathVariable String tenantId,
    @PathVariable String prescriptionId,
    @RequestHeader("Authorization") String token
  );
  
  // Download prescription PDF
  @GetMapping("/{tenantId}/{prescriptionId}/download")
  public ResponseEntity<Resource> downloadPrescription(
    @PathVariable String tenantId,
    @PathVariable String prescriptionId,
    @RequestHeader("Authorization") String token
  );
}
```

### DTOs

```java
// PrescriptionUploadRequest.java
public class PrescriptionUploadRequest {
  public String patientPublicId;
  public String appointmentPublicId;
  public List<MedicineInput> medicines;
  public String notes;
  public MultipartFile file;
}

// MedicineInput.java
public class MedicineInput {
  public String name;
  public String strength;
  public String frequency;
  public String duration;
  public String instructions;
}

// PrescriptionView.java
public class PrescriptionView {
  public String prescriptionPublicId;
  public String doctorName;
  public String issuedOn;
  public List<MedicineView> medicines;
  public String notes;
  public String fileUrl;
}
```

---

## UI/UX Design

### 1. Prescription List Screen

```
┌─────────────────────────────────┐
│ Prescriptions                   │
├─────────────────────────────────┤
│ [Filter by date] [Search...]    │
├─────────────────────────────────┤
│ Prescription ID: RX-1001        │
│ Doctor: Dr. Sanjay Kumar        │
│ Date: March 21, 2026            │
│ Medicines: 3                    │
│ [Download] [View]               │
├─────────────────────────────────┤
│ Prescription ID: RX-1000        │
│ Doctor: Dr. Ramya Singh         │
│ Date: March 15, 2026            │
│ Medicines: 2                    │
│ [Download] [View]               │
└─────────────────────────────────┘
```

### 2. Prescription Detail Screen

```
┌─────────────────────────────────┐
│ Prescription Details            │
├─────────────────────────────────┤
│ ID: RX-1001                     │
│ Doctor: Dr. Sanjay Kumar        │
│ Date Issued: March 21, 2026     │
│ Valid Until: April 21, 2026     │
│                                 │
│ MEDICINES:                      │
│ ┌─────────────────────────────┐ │
│ │ ▪ Paracetamol 500mg         │ │
│ │   Twice daily for 7 days    │ │
│ │   Take with food            │ │
│ ├─────────────────────────────┤ │
│ │ ▪ Amoxicillin 250mg         │ │
│ │   Thrice daily for 5 days   │ │
│ └─────────────────────────────┘ │
│                                 │
│ Notes: Continue previous...     │
│ [Download] [Share] [Print]      │
└─────────────────────────────────┘
```

### 3. Prescription Upload Screen (Doctor)

```
┌─────────────────────────────────┐
│ Issue Prescription              │
├─────────────────────────────────┤
│ Patient: John Doe               │
│ Appointment: Mar 21, 10:30 AM   │
│                                 │
│ ADD MEDICINES:                  │
│ +────────────────────────────+  │
│ | Medicine Name: [_______]  |  │
│ | Strength: [100mg____]     |  │
│ | Frequency: [Twice daily]  |  │
│ | Duration: [7 days___]     |  │
│ | Notes: [______________]   |  │
│ | [+ Add Medicine]          |  │
│ +────────────────────────────+  │
│                                 │
│ Prescription Notes:             │
│ [____________________]          │
│                                 │
│ Upload PDF (optional):          │
│ [Choose File]                   │
│ [Cancel] [Preview] [Submit]     │
└─────────────────────────────────┘
```

---

## Testing Strategy

### Unit Tests
```typescript
// prescriptionService.spec.ts
- uploadPrescription: valid data → creates record
- uploadPrescription: missing field → throws error
- getPrescriptions: patient role → returns data
- getPrescriptions: doctor role → restricted
- downloadPrescription: valid ID → returns PDF
```

### Integration Tests
```typescript
// prescription-integration.spec.ts
- Doctor uploads prescription
- Patient receives prescription
- Patient downloads PDF
- Prescription appears in history
- Medical history updates
```

### E2E Tests
```typescript
// prescription.spec.ts
- Complete prescription flow:
  1. Doctor-patient appointment
  2. Doctor uploads prescription
  3. Patient views prescription
  4. Patient downloads PDF
  5. Prescription in medical history
```

---

## Implementation Timeline

| Week | Tasks | Owner |
|------|-------|-------|
| Week 1 | Backend APIs: Upload, Get, Download | Backend |
| Week 1 | Database schema + migrations | DevOps |
| Week 2 | Frontend screens + hooks | Frontend |
| Week 2 | Form validation + error handling | Frontend |
| Week 3 | PDF generation/handling | Frontend |
| Week 3 | E2E tests + integration tests | QA |
| Week 4 | Polish + performance optimization | Team |

---

## Success Criteria

- [ ] Doctor can upload prescriptions with 2+ medicines
- [ ] Patient can view all prescriptions with full details
- [ ] Patient can download prescription as PDF
- [ ] Medical history tracks allergies and conditions
- [ ] All prescription APIs tested >95% coverage
- [ ] E2E tests pass for complete flow
- [ ] Performance: Prescription list loads <2 seconds
- [ ] Offline support: View cached prescriptions

---

## Risk & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| PDF generation delays | User experience | Use async processing, cache |
| Large prescription files | Storage limits | Implement compression, cleanup |
| Privacy concerns | Data breach | Encrypt stored files, audit logs |
| Complex medicines data | Data inconsistency | Use structured schema, validation |

---

## Acceptance Criteria

```gherkin
Feature: Patient can view and download prescriptions

Scenario: Doctor issues prescription
  Given Doctor is on patient consultation screen
  When Doctor fills prescription form with medicines
  And Doctor submits prescription
  Then Prescription is created with status "issued"
  And Patient receives notification

Scenario: Patient views prescriptions
  Given Patient is logged in
  When Patient navigates to Prescriptions
  Then All prescriptions are displayed with dates
  And Each prescription shows medicine list

Scenario: Patient downloads prescription
  Given Patient is viewing prescription detail
  When Patient clicks Download
  Then PDF file is generated
  And File is downloaded to device
  And File contains all prescription details
```

---

## Next Steps

1. ✅ Phase 2B: Complete integration testing
2. 📋 Phase 3.1: Backend API implementation
3. 📋 Phase 3.2: Frontend UI implementation
4. 📋 Phase 3.3: E2E testing
5. 📋 Phase 3.4: Medical history tracking

---

**Phase 3 Status**: Planning Complete - Ready for Sprint Development
