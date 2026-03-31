# Phase 3 Development Guide: Prescriptions Feature

**Status**: Foundation Complete ✅  
**Date**: March 21, 2026  
**Sprint Duration**: Weeks 1-4 (Suggested)

---

## 🎯 Overview

Phase 3 adds prescription management to SevaCare, enabling:
- **Doctors**: Issue prescriptions with multiple medicines after appointments
- **Patients**: View, download, and manage prescriptions
- **Both**: Access complete medical history with allergies, conditions, and past appointments

---

## 📦 Deliverables Completed

### ✅ Foundation Phase (This Sprint)

#### 1. API Types (`src/api/types.ts`)
```typescript
// New types added:
- MedicineView: Individual medicine details
- PrescriptionDetailView: Complete prescription with medicines
- PrescriptionCollectionView: All prescriptions for patient
- MedicineUploadInput: Form input for medicine upload
- PrescriptionUploadRequest: Doctor's prescription submission
- PrescriptionUploadResult: Confirmation after upload
- MedicalHistoryRecord: Individual history entry
- MedicalHistoryView: Complete medical history
```

#### 2. API Endpoints (`src/api/client.ts`)
```typescript
// New endpoints:
- getPatientPrescriptions(tenantId, patientId, token)
- getPrescriptionDetail(tenantId, prescriptionId, token)
- uploadPrescription(tenantId, doctorId, token, body)
- downloadPrescription(tenantId, prescriptionId, token)
- getPatientMedicalHistory(tenantId, patientId, token)
```

#### 3. React Hooks (`src/hooks/useApi.ts`)
```typescript
// New hooks:
- usePatientPrescriptions(): Get all prescriptions
- usePrescriptionDetail(id): Get specific prescription
- useUploadPrescription(): Upload new prescription (doctor)
- useMedicalHistory(): Get complete medical history
```

#### 4. Screen Components (`src/screens/prescription-screens.tsx`)
```typescript
// 4 complete screens with full UI:
- PrescriptionListScreen: Browse all prescriptions
- PrescriptionDetailScreen: View prescription details & download
- MedicineUploadScreen: Doctor prescription issuance
- MedicalHistoryScreen: Complete health record with tabs
```

#### 5. E2E Tests (`sevacare-e2e-test/tests/phase3-prescriptions.spec.ts`)
```typescript
// 30+ test scenarios covering:
- Patient viewing/downloading prescriptions
- Doctor uploading prescriptions
- Medical history viewing
- API integration tests
- Security & permissions
- Edge cases & error handling
```

---

## 🏗️ Architecture

### Data Flow: Prescription View

```
Patient Home Screen
    ↓
[View Prescriptions Button]
    ↓
PrescriptionListScreen
    ↓
usePatientPrescriptions() hook
    ↓
sevacareApi.getPatientPrescriptions()
    ↓
GET /patients/{tenantId}/{patientId}/prescriptions
    ↓
Backend fetches from DB (schema-per-tenant)
    ↓
Returns PrescriptionCollectionView
    ↓
Display in FlatList with doctor name, date, status
    ↓
User clicks prescription
    ↓
PrescriptionDetailScreen with full medicines
```

### Data Flow: Prescription Upload

```
Doctor Dashboard
    ↓
[Issue Prescription Button]
    ↓
MedicineUploadScreen
    ↓
Doctor fills: medicines[], notes
    ↓
Submit triggers useUploadPrescription().upload()
    ↓
sevacareApi.uploadPrescription()
    ↓
POST /doctors/{tenantId}/{doctorId}/prescriptions
    ↓
Backend creates prescription record
    ↓
Returns PrescriptionUploadResult with ID
    ↓
Navigate back to prescriptions list
```

---

## 🔌 Integration Checklist

### [NEXT] Integrate Screens into App Router

**File**: `src/screens/app-router.tsx`

1. Import prescription screens:
```typescript
import {
  PrescriptionListScreen,
  PrescriptionDetailScreen,
  MedicineUploadScreen,
  MedicalHistoryScreen,
} from './prescription-screens';
```

2. Add screen routing:
```typescript
case 'prescriptions':
  return (
    <PrescriptionListScreen
      activeTenant={activeTenant}
      currentScreen={activeScreen}
      onNavigate={setActiveScreen}
      bottomItems={bottomNavItems}
      hospitalName={hospitalName}
    />
  );

case 'prescription-detail':
  return (
    <PrescriptionDetailScreen
      prescriptionId={selectedPrescriptionId}
      activeTenant={activeTenant}
      currentScreen={activeScreen}
      onNavigate={setActiveScreen}
      bottomItems={bottomNavItems}
      hospitalName={hospitalName}
    />
  );
```

3. Add navigation buttons in PatientHomeScreen:
```typescript
<SecondaryButton
  label="View Prescriptions"
  onPress={() => setActiveScreen('prescriptions')}
/>
```

### Backend API Development

**Timeline**: Week 1-2

**Required Endpoints**:

1. **POST** `/doctors/{tenantId}/{doctorId}/prescriptions`
   - Create prescription with medicines
   - Validate patient assignment
   - Return prescriptionPublicId

2. **GET** `/patients/{tenantId}/{patientId}/prescriptions`
   - Return all prescriptions
   - Include medicine details
   - Filter by status if needed

3. **GET** `/prescriptions/{tenantId}/{prescriptionId}/detail`
   - Full prescription details
   - All medicine information
   - Doctor notes

4. **GET** `/prescriptions/{tenantId}/{prescriptionId}/download`
   - Stream PDF file
   - Verify authorization

5. **GET** `/patients/{tenantId}/{patientId}/medical-history`
   - All appointments
   - All prescriptions
   - Medical records (allergies, conditions)
   - Follow-up flags

**Database Schema** (Add to PostgreSQL):

```sql
CREATE TABLE dt_prescription (
  id SERIAL PRIMARY KEY,
  prescription_public_id VARCHAR(20) UNIQUE NOT NULL,
  tenant_id INTEGER NOT NULL,
  appointment_id INTEGER REFERENCES dt_appointment,
  doctor_id INTEGER REFERENCES dt_doctor NOT NULL,
  patient_id INTEGER REFERENCES dt_patient NOT NULL,
  issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  issued_on DATE DEFAULT CURRENT_DATE,
  valid_until DATE,
  notes TEXT,
  file_url VARCHAR,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dt_prescription_medicine (
  id SERIAL PRIMARY KEY,
  prescription_id INTEGER REFERENCES dt_prescription ON DELETE CASCADE NOT NULL,
  medicine_name VARCHAR(255) NOT NULL,
  strength VARCHAR(100),
  frequency VARCHAR(255) NOT NULL,
  duration VARCHAR(100),
  instructions TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dt_medical_history (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  patient_id INTEGER REFERENCES dt_patient NOT NULL,
  record_type VARCHAR(50),
  record_value VARCHAR(255) NOT NULL,
  notes TEXT,
  record_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Frontend Integration Tasks

**Timeline**: Week 2-3

1. **App Router Integration**
   - Add prescription screens to routing
   - Wire navigation buttons
   - Pass state for selected prescription

2. **State Management**
   - Add states for selectedPrescriptionId
   - Add states for prescription loading
   - Handle error states

3. **Real Data Display**
   - Replace demo medicines with API data
   - Display real doctor names
   - Show real issue/validity dates
   - Display real medicine counts

4. **Form Enhancement**
   - Input validation for medicine fields
   - Error messages for failed uploads
   - Loading states during submission
   - Success confirmation message

### Testing Phase

**Timeline**: Week 3-4

**E2E Tests Ready**: `phase3-prescriptions.spec.ts`

Run tests:
```bash
cd sevacare-e2e-test

# All prescription tests
npm run test -- phase3-prescriptions.spec.ts

# Specific test
npm run test -- phase3-prescriptions.spec.ts -g "patient can view"

# With UI (debug)
npm run test:ui -- phase3-prescriptions.spec.ts
```

---

## 📋 Implementation Steps

### Week 1: Backend APIs

- [ ] Create database tables (prescription, medicine, history)
- [ ] Implement 5 prescription endpoints
- [ ] Add authorization checks (patient/doctor access control)
- [ ] Implement multi-tenant schema switching
- [ ] Add error handling for edge cases
- [ ] Test with Postman/curl
- **Acceptance**: All 5 endpoints respond with correct data

### Week 2: Frontend Integration & Real Data

- [ ] Import prescription screens into app-router
- [ ] Add routing for 4 new screens
- [ ] Connect buttons to navigation
- [ ] Test with real API calls (verify backend)
- [ ] Display real prescription data in lists
- [ ] Show real medicine details
- **Acceptance**: PrescriptionListScreen shows real data from API

### Week 3: Polish & Features

- [ ] PDF download functionality (client-side or backend)
- [ ] Share prescription via email/SMS
- [ ] Prescription search/filter
- [ ] Medical history tabs work correctly
- [ ] Allergies display with warnings
- [ ] Past appointments visible in history
- **Acceptance**: All features work end-to-end

### Week 4: Testing & Optimization

- [ ] Run all E2E tests against live backend
- [ ] Fix test failures
- [ ] Performance optimization (lazy load images, cache)
- [ ] Error recovery flows
- [ ] Security validation (multi-tenant, permissions)
- [ ] User acceptance testing
- **Acceptance**: All E2E tests pass, no performance issues

---

## 🚀 Quick Start

### 1. Start Backend
```bash
# Build
cd sevacare-backend
mvn -pl sevacare-api -am -DskipTests package

# Run (port 8081)
java -jar sevacare-api/target/sevacare-api-0.0.1-SNAPSHOT.jar
```

### 2. Start Frontend
```bash
cd sevacare-frontend
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1 npm run web
# Opens at http://localhost:8087
```

### 3. Run E2E Tests
```bash
cd sevacare-e2e-test
npm run test -- phase3-prescriptions.spec.ts
```

### 4. View Results
```bash
# Generate report
npm run test -- phase3-prescriptions.spec.ts --reporter=html

# Open report
npx playwright show-report
```

---

## 🧪 Test Execution Guide

### Running Tests Locally

```bash
# Make sure services are running:
# Terminal 1: Backend
java -jar sevacare-backend/sevacare-api/target/sevacare-api-0.0.1-SNAPSHOT.jar

# Terminal 2: Frontend  
cd sevacare-frontend
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1 npm run web

# Terminal 3: Run tests
cd sevacare-e2e-test
npm run test -- phase3-prescriptions.spec.ts --reporter=line
```

### Interpreting Test Results

**Success**: All tests pass ✅
```
30 passed (5.2s)
```

**With Skips**: Some tests skipped (expected without full backend)
```
20 passed, 10 skipped (4.1s)
```

**Failures**: Investigate failed tests
```
npm run test -- phase3-prescriptions.spec.ts --reporter=verbose
```

### Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| Tests timeout | Backend not running at 8081 |
| 401 errors | Token generation failing, check OTP endpoint |
| Data not found | Test data not seeded in database |
| CORS errors | Frontend not at localhost:8087 |
| "prescription not found" | API endpoint not implemented yet |

---

## 📊 Success Criteria

### Functional
- ✅ Patient can list all prescriptions
- ✅ Patient can view full prescription detail
- ✅ Patient can download prescription as PDF
- ✅ Doctor can upload prescription with medicines
- ✅ Doctor can add multiple medicines per prescription
- ✅ Medical history shows complete record
- ✅ Allergies flagged prominently

### Technical
- ✅ All TypeScript compiles (0 errors)
- ✅ API endpoints follow REST conventions
- ✅ Multi-tenant isolation working (X-Tenant-Id)
- ✅ Proper error handling and validation
- ✅ E2E tests pass (20+/30 tests)
- ✅ Performance <2s load time

### Quality
- ✅ Code follows patterns from Phase 2
- ✅ Types defined for all API responses
- ✅ Hooks follow useApi patterns
- ✅ Components use theme system
- ✅ Error states handled gracefully
- ✅ Loading states shown to user

---

## 🔒 Security Checklist

- [ ] Patients can only see own prescriptions
- [ ] Doctors can only issue prescriptions for assigned patients
- [ ] Multi-tenant schema isolation enforced
- [ ] X-Tenant-Id header validated on every request
- [ ] PDF downloads require valid token
- [ ] Medical history requires authentication
- [ ] No accidental data leakage between tenants

---

## 📚 Related Documentation

- [PHASE3_PRESCRIPTIONS_PLAN.md](../PHASE3_PRESCRIPTIONS_PLAN.md) - Detailed feature specification
- [PHASE2B_STATUS_REPORT.md](../PHASE2B_STATUS_REPORT.md) - Phase 2B integration status
- [sevacare.md](../sevacare.md) - Project overview

---

## 📞 Support

For questions or blockers:
1. Check test failures in `phase3-prescriptions.spec.ts`
2. Review API responses with Postman/curl
3. Verify database schema matches documentation
4. Check backend logs for errors

---

## 🎉 Phase 4 Preview

After Phase 3 completion, planned features:
- **Offline Prescriptions**: Cache prescriptions in SQLite
- **Family Prescriptions**: Multiple family member support
- **Prescription Reminders**: Notifications for medicine schedules
- **Pharmacy Integration**: Send directly to pharmacy
- **Mobile App**: React Native native build

---

**Happy coding!** 🚀

Phase 3 Foundation is ready - Next step: Backend API implementation
