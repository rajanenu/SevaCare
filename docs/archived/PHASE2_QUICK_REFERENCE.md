# Phase 2 Quick Reference

## Authentication Flow

```typescript
// 1. Request OTP
const otpResponse = await sevacareApi.requestOtp({
  tenantPublicId: 'T-1001',
  role: 'patient',
  mobileNumber: '9000000000'
});
// Returns: { otpHint: '0000' }

// 2. Verify OTP
const session = await sevacareApi.verifyOtp({
  tenantPublicId: 'T-1001',
  role: 'patient',
  mobileNumber: '9000000000',
  otp: '0000'
});
// Returns: { token, tenantPublicId, subjectPublicId, role }

// 3. Save session
await AuthService.saveSession(session);

// 4. On startup, restore session
const session = await AuthService.loadSession();
```

## Common Hooks

### Patient Dashboard
```typescript
const { data: home, loading, error, retry } = usePatientHome({
  onSuccess: (data) => console.log('Home loaded'),
  onError: (error) => console.error(error.message)
});

// home.appointments, home.prescriptions
```

### Doctor Search
```typescript
const { data: doctorList, loading, error } = useDoctorSearch('T-1001');

// doctorList.doctors: DoctorSummary[]
// - doctorPublicId, name, specialty, fee, availability
// - experience, imageUrl, rating
```

### Booking Appointment
```typescript
// Step 1: Get setup data
const { data: setup } = useBookingSetup();
// setup.specialties, setup.slotIntervalMinutes

// Step 2: Book
const { book, loading, error } = useBookAppointment(
  (appointmentId) => console.log('Booked:', appointmentId)
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
  slot: '2024-03-22 10:30'
});
```

### Profile Updates
```typescript
// Patient profile
const { update: updatePatient, updating } = useUpdatePatientProfile(
  () => console.log('Updated'),
  (error) => console.error(error)
);

await updatePatient({
  fullName: 'John Doe',
  email: 'john@example.com',
  gender: 'male',
  dateOfBirth: '1990-01-15',
  address: 'New Address',
  mobileNumber: '9000000000',
  emergencyContact: 'Jane Doe',
  emergencyContactPhone: '9000000001'
});

// Doctor profile
const { update: updateDoctor } = useUpdateDoctorProfile();

await updateDoctor({
  fullName: 'Dr. Sanjay Kumar',
  specialty: 'Cardiology',
  experience: '7 Years',
  availability: 'Mon-Fri 9AM-5PM',
  fee: '₹500',
  qualifications: ['MBBS', 'MD (Cardiology)']
});
```

## Session Management

```typescript
// Check if logged in
const isAuth = await AuthService.isAuthenticated();

// Get user details
const token = await AuthService.getToken();
const tenantId = await AuthService.getTenantId();
const userId = await AuthService.getUserId();
const role = await AuthService.getRole();

// Get full state at once
const authState = await AuthService.getAuthState();

// Logout
await AuthService.clearSession();
```

## API Base URLs

```
Public: /public/tenants, /public/lookups, /public/onboarding
Auth: /auth/otp/request, /auth/otp/verify
Patient: /patients/{tenantId}/{patientId}/...
Doctor: /doctors/{tenantId}/{doctorId}/...
Admin: /admin/{tenantId}/...
```

## Required Headers (Authenticated Calls)

```
Authorization: Bearer {token}
X-Tenant-Id: {tenantId}
Content-Type: application/json
```

## Error Handling Template

```typescript
try {
  const result = await someApiCall();
} catch (error: ApiError) {
  if (error.message.includes('Not authenticated')) {
    // Redirect to login
    navigate('login');
  } else if (error.message.includes('Not found')) {
    // Show "Not found" message
    showToast('Data not found');
  } else {
    // Generic error
    showToast(error.message);
  }
}
```

## Component Template

```typescript
import { usePatientHome } from '../hooks/useApi';

export function MyScreen() {
  const { data, loading, error, retry } = usePatientHome({
    onError: (error) => showToast(error.message)
  });

  if (loading) return <LoadingView />;
  if (error) return <ErrorView message={error.message} onRetry={retry} />;
  if (!data) return <EmptyView />;

  return <ContentView data={data} />;
}
```

## Types Reference

### Appointment
```typescript
{
  appointmentPublicId: string;
  doctorPublicId: string;
  doctorName: string;
  slot: string;            // "YYYY-MM-DD HH:MM"
  status: string;          // "confirmed", "pending", "cancelled"
  note: string;
}
```

### Doctor
```typescript
{
  doctorPublicId: string;
  name: string;
  specialty: string;
  fee: string;             // e.g., "₹500"
  availability: string;    // e.g., "Mon-Fri 9AM-5PM"
  experience?: string;     // e.g., "7 Years"
  imageUrl?: string;
  rating?: string;         // e.g., "4.8"
}
```

### Patient
```typescript
{
  patientPublicId: string;
  fullName: string;
  mobileNumber: string;
  email?: string;
  gender?: 'male' | 'female' | 'other';
  dateOfBirth?: string;
  address?: string;
  emergencyContact?: string;
  emergencyContactPhone?: string;
}
```

## Files Added in Phase 2

```
sevacare-frontend/
├── src/
│   ├── api/
│   │   ├── client.ts        (API calls - EXISTING, enhanced)
│   │   └── types.ts         (TypeScript types - EXISTING, enhanced)
│   ├── services/
│   │   └── authService.ts   (Session management - NEW)
│   └── hooks/
│       └── useApi.ts        (React hooks - NEW)
└── PHASE2_INTEGRATION_GUIDE.md (This file path + quick reference below)
```

## Testing Checklist

- [ ] OTP request/verify flow works
- [ ] Session persists on app reload
- [ ] Patient home loads with appointments
- [ ] Doctor search filters by specialty
- [ ] Appointment booking completes successfully
- [ ] Profile updates persist
- [ ] Logout clears session
- [ ] Error messages display correctly
- [ ] Loading states show during API calls
- [ ] Retry works on failed requests
