# SevaCare Phase 2: Backend API Integration Guide

**Date**: March 21, 2026  
**Status**: Backend APIs Ready | Frontend Integration In Progress  
**Backend**: Available at `localhost:8081/api/v1`

## Overview

This guide covers integrating the SevaCare backend APIs into the React Native frontend. The backend uses OTP-based authentication with HMAC-SHA256 tokens and supports multi-tenant operations with schema-per-tenant architecture.

---

## Architecture

### Backend Stack
- **Framework**: Spring Boot 3.4.3 with Java 21
- **Database**: PostgreSQL with Flyway migrations
- **Authentication**: OTP (hardcoded `0000` in dev) → HMAC-SHA256 tokens
- **Architecture**: Multi-tenant (schema-per-tenant)

### Frontend Stack
- **Framework**: React Native + Expo
- **API Layer**: `src/api/client.ts` (comprehensive API client)
- **Services**: `src/services/authService.ts` (session management)
- **Hooks**: `src/hooks/useApi.ts` (React hooks for API calls)
- **Storage**: Expo SecureStore (with fallback for web)

---

## Authentication Flow

### 1. OTP Request
```typescript
import { sevacareApi } from '../api/client';

const response = await sevacareApi.requestOtp({
  tenantPublicId: 'T-1001',
  role: 'patient', // or 'doctor', 'admin'
  mobileNumber: '9000000000',
});

// Response: { otpHint: '0000' } // For development
```

### 2. OTP Verification
```typescript
const session = await sevacareApi.verifyOtp({
  tenantPublicId: 'T-1001',
  role: 'patient',
  mobileNumber: '9000000000',
  otp: '0000', // Dev: always '0000'
});

// Response:
// {
//   tenantPublicId: 'T-1001',
//   role: 'patient',
//   subjectPublicId: 'P-1234',
//   token: 'eyJ0eXAi...'
// }

// Save session
import { AuthService } from '../services/authService';
await AuthService.saveSession(session);
```

### 3. Making Authenticated Requests

All authenticated endpoints require:
- `Authorization: Bearer {token}` header
- `X-Tenant-Id: {tenantId}` header

```typescript
// Using API client directly
const home = await sevacareApi.getPatientHome(
  tenantId,
  patientId,
  token
);

// Or using hooks (recommended)
import { usePatientHome } from '../hooks/useApi';

export function PatientHomeScreen() {
  const { data, loading, error, retry } = usePatientHome({
    onSuccess: (data) => console.log('Home loaded:', data),
    onError: (error) => console.error('Error:', error.message),
  });

  if (loading) return <LoadingView />;
  if (error) return <ErrorView message={error.message} onRetry={retry} />;
  
  return <PatientHomeView data={data} />;
}
```

---

## Key APIs for Phase 2

### Hospital/Tenant Discovery
```typescript
// List all hospitals
const hospitals = await sevacareApi.listTenants();
// Returns: { tenants: TenantSummary[] }

// Get specialty & location lookups
const lookups = await sevacareApi.getLookups();
// Returns: { specializations: string[], cities: string[] }
```

### Doctor Search
```typescript
// Public: Search doctors by tenant
const doctorList = await sevacareApi.listDoctors('T-1001');
// Returns: { tenantPublicId, doctors: DoctorSummary[] }

// DoctorSummary fields:
// - doctorPublicId, name, specialty, availability
// - fee, experience, imageUrl, rating (from Phase 2)
```

### Patient Dashboard
```typescript
// Using hook (recommended)
import { usePatientHome } from '../hooks/useApi';

const { data } = usePatientHome();

// Manual call:
const home = await sevacareApi.getPatientHome(
  tenantId,
  patientId,
  token
);

// Response structure:
// {
//   patientPublicId, tenantPublicId,
//   appointments: AppointmentView[],
//   prescriptions: PrescriptionView[]
// }
```

### Appointment Booking

#### Step 1: Get Booking Setup (Specialties, Slot Interval)
```typescript
import { useBookingSetup } from '../hooks/useApi';

const { data: setup } = useBookingSetup({
  onSuccess: (setup) => {
    console.log('Specialties:', setup.specialties);
    console.log('Slot interval:', setup.slotIntervalMinutes);
  },
});
```

#### Step 2: Book Appointment
```typescript
import { useBookAppointment } from '../hooks/useApi';

const { book, loading, error } = useBookAppointment(
  (appointmentId) => console.log('Booked:', appointmentId),
  (error) => console.error('Error:', error)
);

await book({
  tenantPublicId: 'T-1001',
  patientPublicId: 'P-1234',
  patientName: 'John Doe',
  gender: 'M',
  age: 35,
  mobileNumber: '9000000000',
  address: '123 Main St',
  specialty: 'Cardiology',
  doctorPublicId: 'DR-1001',
  slot: '2024-03-22 10:30', // Format: YYYY-MM-DD HH:MM
});
```

---

## Profile Editing (Phase 2)

### Patient Profile Update
```typescript
import { useUpdatePatientProfile } from '../hooks/useApi';

const { update, updating, error } = useUpdatePatientProfile(
  () => console.log('Profile updated'),
  (error) => console.error('Error:', error)
);

await update({
  fullName: 'John Doe Updated',
  email: 'john@example.com',
  gender: 'male',
  dateOfBirth: '1990-01-15',
  address: 'New Address',
  mobileNumber: '9000000000',
  status: 'active',
  emergencyContact: 'Jane Doe',
  emergencyContactPhone: '9000000001',
});
```

### Doctor Profile Update
```typescript
import { useUpdateDoctorProfile } from '../hooks/useApi';

const { update, updating, error } = useUpdateDoctorProfile(
  () => console.log('Profile updated'),
  (error) => console.error('Error:', error)
);

await update({
  fullName: 'Dr. Sanjay Kumar',
  specialty: 'Cardiology',
  experience: '7 Years',
  availability: 'Mon-Fri 9AM-5PM',
  fee: '₹500',
  mobileNumber: '8000000000',
  email: 'doctor@example.com',
  qualifications: ['MBBS', 'MD (Cardiology)'],
  active: true,
});
```

---

## Using AuthService for Session Management

### Session Persistence
```typescript
import { AuthService } from '../services/authService';

// After successful OTP verification:
await AuthService.saveSession(session);

// On app startup:
const session = await AuthService.loadSession();
if (session) {
  // User already logged in
  navigate('home');
} else {
  // Show login screen
  navigate('login');
}

// On logout:
await AuthService.clearSession();
```

### Getting Session Info
```typescript
const isAuth = await AuthService.isAuthenticated();
const token = await AuthService.getToken();
const tenantId = await AuthService.getTenantId();
const userId = await AuthService.getUserId();
const role = await AuthService.getRole();

// Or get full auth state
const authState = await AuthService.getAuthState();
console.log(authState);
// Output:
// {
//   isAuthenticated: true,
//   token: 'eyJ0eXAi...',
//   tenantId: 'T-1001',
//   userId: 'P-1234',
//   role: 'patient'
// }
```

---

## Custom Hooks Reference

### useApi
Generic hook for any API call with loading, error, and retry states.

```typescript
const { data, loading, error, execute, retry } = useApi(
  async () => sevacareApi.getLookups(),
  {
    onSuccess: (data) => { /* ... */ },
    onError: (error) => { /* ... */ },
  }
);
```

### useAuthenticatedApi
Hook for calls that need token + tenant ID (handled automatically).

```typescript
const { data, loading, error, execute, retry } = useAuthenticatedApi(
  async (token, tenantId) => 
    sevacareApi.listAppointmentRecords(tenantId, token),
  { onSuccess, onError }
);
```

### usePatientHome, useBookingSetup, useAppointments, useDoctorDashboard
Pre-configured hooks for common operations.

---

## Error Handling

### API Errors
```typescript
import type { ApiError } from '../api/types';

try {
  const result = await sevacareApi.verifyOtp({ /* ... */ });
} catch (error) {
  if (error instanceof Error) {
    const apiError: ApiError = {
      status: 0,
      message: error.message,
    };
    // Handle error
  }
}
```

### Hook Error Handling
```typescript
const { data, loading, error, retry } = usePatientHome({
  onError: (error: ApiError) => {
    if (error.message.includes('Not authenticated')) {
      // Redirect to login
    } else {
      // Show error message
      showToast(error.message);
    }
  },
});

if (error) {
  return (
    <View>
      <Text>{error.message}</Text>
      <Button onPress={retry} title="Retry" />
    </View>
  );
}
```

---

## Integration Patterns

### Pattern 1: Authenticated Screen
```typescript
import { usePatientHome } from '../hooks/useApi';

export function PatientDashboardScreen() {
  const { data: home, loading, error, retry } = usePatientHome();

  if (loading) return <ActivityIndicator />;
  if (error) return <ErrorCard message={error.message} onRetry={retry} />;

  return (
    <ScrollView>
      <AppointmentsList appointments={home.appointments} />
      <PrescriptionsList prescriptions={home.prescriptions} />
    </ScrollView>
  );
}
```

### Pattern 2: Form with API Call
```typescript
import { useState } from 'react';
import { useUpdatePatientProfile } from '../hooks/useApi';

export function EditProfileScreen() {
  const [form, setForm] = useState({...});
  const { update, updating, error } = useUpdatePatientProfile(
    () => navigation.goBack(),
    (err) => showToast(err.message)
  );

  return (
    <ScrollView>
      <InputField
        value={form.fullName}
        onChangeText={(text) => setForm({...form, fullName: text})}
      />
      {/* More fields */}
      <Button
        disabled={updating}
        loading={updating}
        onPress={() => update(form)}
        title="Save"
      />
      {error && <ErrorText>{error.message}</ErrorText>}
    </ScrollView>
  );
}
```

### Pattern 3: Search with Filters
```typescript
import { useState, useMemo } from 'react';
import { useDoctorSearch } from '../hooks/useApi';

export function DoctorSearchScreen({tenantId}) {
  const [specialty, setSpecialty] = useState('');
  const { data: doctorList } = useDoctorSearch(tenantId);

  const filtered = useMemo(
    () => doctorList?.doctors.filter(
      d => !specialty || d.specialty === specialty
    ) ?? [],
    [doctorList, specialty]
  );

  return (
    <View>
      <SpecialtyPicker value={specialty} onChange={setSpecialty} />
      <FlatList
        data={filtered}
        renderItem={({item}) => <DoctorCard doctor={item} />}
      />
    </View>
  );
}
```

---

## Database Schema & Entity Relationships

### Key Entities (Multi-Tenant)
- **Tenant**: Hospital/clinic (T-XXXX)
- **Doctor**: (DR-XXXX within tenant schema)
- **Patient**: (P-XXXX within tenant schema)
- **Appointment**: Links patient + doctor + time slot
- **Prescription**: Links doctor + patient + medicines

### Schema Pattern
Each tenant has its own PostgreSQL schema with isolated tables.

```
Database: sevacare
├── Schema: tenant_t_1001
│   ├── dt_doctor
│   ├── dt_patient
│   ├── dt_appointment
│   └── dt_prescription
├── Schema: tenant_t_1002
│   ├── dt_doctor
│   └── ...
└── ...
```

---

## Testing with Curl

### OTP Request
```bash
curl -X POST http://localhost:8081/api/v1/auth/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"tenantPublicId":"T-1001","role":"patient","mobileNumber":"9000000000"}'
```

### OTP Verify
```bash
curl -X POST http://localhost:8081/api/v1/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d '{"tenantPublicId":"T-1001","role":"patient","mobileNumber":"9000000000","otp":"0000"}'
```

### Get Patient Home
```bash
TOKEN="<token_from_verify>"
TENANT="T-1001"
PATIENT="P-1234"

curl -X GET "http://localhost:8081/api/v1/patients/$TENANT/$PATIENT/home" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-Id: $TENANT"
```

---

## Phase 2 Checklist

- [x] Backend API analysis & documentation
- [x] TypeScript types for all DTOs
- [x] API client implementation
- [x] Authentication service (session management)
- [x] React hooks for common operations
- [ ] Integration with login screen
- [ ] Integration with patient home screen
- [ ] Integration with doctor search screen
- [ ] Integration with booking flow
- [ ] Integration with profile edit screens
- [ ] Error handling & retry logic
- [ ] Loading states & skeleton screens
- [ ] Logout functionality
- [ ] Session persistence on app reload

---

## Environment Variables

```env
# .env or app.json
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1
```

## Next Steps (Phase 3)

1. **Prescriptions**: Upload, view, and manage prescriptions
2. **Feedback**: Rating and feedback system for appointments
3. **Dark Mode**: Time-based (after 6:30 PM IST) or manual toggle
4. **Notifications**: Push notifications for appointments
5. **Image Upload**: Profile pictures with CDN/S3 storage
6. **Message History**: In-app messaging between doctors and patients
