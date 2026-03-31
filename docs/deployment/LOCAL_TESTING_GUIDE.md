# SevaCare - Local Testing Guide

## 🚀 Live URLs (Currently Running)

### Frontend (React Native Web)
- **URL**: http://localhost:8086
- **Status**: ✅ Running on Python HTTP server
- **Updated API Base**: Configured to connect to http://localhost:8082/api/v1

### Backend API
- **URL**: http://localhost:8082
- **API Base**: http://localhost:8082/api/v1
- **Status**: ✅ Running on Spring Boot
- **Health Check**: http://localhost:8082/actuator/health
- **Database**: Connected to Docker PostgreSQL (seva_care)

### Docker PostgreSQL
- **Host**: localhost
- **Port**: 5432
- **Database**: seva_care
- **Username**: postgres
- **Password**: postgres
- **Status**: ✅ Running

---

## 📋 Architecture Overview

### Database Schema Structure
Using **multi-tenant architecture** with schema per tenant:
- **tenant_t_1001**: Aurora Multispeciality (Premium theme)
- **tenant_t_1002**: GreenLeaf Family Clinic (Clinic theme)

Each tenant schema contains:
- `patient` - Patient records
- `doctor` - Doctor basic info
- **`doctor_details`** ⭐ NEW - Extended doctor information
- **`doctor_schedule`** ⭐ NEW - Doctor appointment scheduling
- **`doctor_license_metadata`** ⭐ NEW - License file tracking
- `appointment` - Booking records
- `prescription` - Medical prescriptions
- `admin_user` - Tenant administrators

---

## 🔧 Doctor Onboarding Implementation

### Doctor Registration Fields
When registering a doctor, the following details are now captured:

```json
{
  "fullName": "string",
  "specialization": "string",
  "mobileNumber": "string (10 digits)",
  "age": "integer (min 18)",
  "gender": "string",
  "licenseNumber": "string (unique)",
  "experienceYears": "integer (min 0)",
  "address": "string",
  "city": "string",
  "state": "string",
  "appointmentIntervalMinutes": "integer (10-60 min)",
  "lunchBreakStartTime": "string (HH:MM format)",
  "lunchBreakEndTime": "string (HH:MM format)",
  "maxAppointmentsPerDay": "integer (min 1)",
  "workingDays": "string (MONDAY,TUESDAY,...SUNDAY)"
}
```

### Doctor Schedule Configuration
- **Appointment Intervals**: Support for 15, 20, or 30-minute slots
- **Lunch Break**: Configurable daily break time
- **Daily Capacity**: Set maximum appointments per day
- **Working Hours**: Clinic start/end times (default: 09:00-18:00)
- **Working Days**: Select specific days (e.g., MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY)
- **License Storage**: Metadata tracking for license photos

### Example: Register a Doctor

**Endpoint**: `POST /api/v1/public/tenants/{tenantPublicId}/doctors/register`

```bash
curl -X POST http://localhost:8082/api/v1/public/tenants/T-1001/doctors/register \
  -H 'Content-Type: application/json' \
  -d '{
    "fullName": "Dr. Rajesh Kumar",
    "specialization": "Cardiologist",
    "mobileNumber": "9999123456",
    "age": 42,
    "gender": "Male",
    "licenseNumber": "MCI/2024/123456",
    "experienceYears": 15,
    "address": "123 Medical Plaza, Fort, Mumbai",
    "city": "Mumbai",
    "state": "Maharashtra",
    "appointmentIntervalMinutes": 15,
    "lunchBreakStartTime": "13:00",
    "lunchBreakEndTime": "14:00",
    "maxAppointmentsPerDay": 24,
    "workingDays": "MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY"
  }'
```

---

## 🏥 Tenant Onboarding Enhancements

### Updated Tenant Registration Fields

```json
{
  "hospitalName": "string",
  "city": "string",
  "address": "string (NEW)",
  "country": "string (NEW)",
  "contactName": "string",
  "contactMobile": "string",
  "contactEmail": "string (valid email)",
  "facilityType": "string (hospital|clinic)"
}
```

### Example: Submit Tenant Onboarding Request

**Endpoint**: `POST /api/v1/public/onboarding/request`

```bash
curl -X POST http://localhost:8082/api/v1/public/onboarding/request \
  -H 'Content-Type: application/json' \
  -d '{
    "hospitalName": "Fortis Healthcare Ltd",
    "city": "Mumbai",
    "address": "10 Pandurang Budhkar Marg, Mahim",
    "country": "India",
    "contactName": "Mr. Amit Desai",
    "contactMobile": "9876543210",
    "contactEmail": "contact@fortis.com",
    "facilityType": "hospital"
  }'
```

---

## 🔑 Test Credentials

### Pre-loaded Tenants
1. **Aurora Multispeciality** (T-1001)
   - Theme: Premium (light blue gradients)
   - Admin: A-1001
   - Sample Doctor: D-1001 (Dr. Meera Rao, Cardiologist)
   - Sample Patient: P-1001 (Rohan Sharma)

2. **GreenLeaf Family Clinic** (T-1002)
   - Theme: Clinic
   - Admin: A-1002
   - Sample Doctor: D-1003 (Dr. Kavya Reddy, Family Medicine)
   - Sample Patient: P-1003 (Sita Naik)

### Patient Login
- Mobile: 9000000001 (Tenant: T-1001)
- OTP: 0000 (development mode)
- PIN: 0000 (if PIN verification needed)

### Doctor Login
- Mobile or Employee ID: Use doctor's registered mobile or ID
- OTP: 0000

---

## 📡 Key API Endpoints

### Public (No Auth Required)
- `GET /api/v1/public/tenants` - List all active tenants
- `GET /api/v1/public/tenants/{tenantPublicId}/doctors` - List doctors for a tenant
- `POST /api/v1/public/onboarding/request` - Submit tenant onboarding request
- `POST /api/v1/public/tenants/{tenantPublicId}/doctors/register` - Register new doctor

### Authentication
- `POST /api/v1/auth/otp/request` - Request OTP for login
- `POST /api/v1/auth/otp/verify` - Verify OTP and get session token

### Patient APIs (Authenticated)
- `GET /api/v1/patients/{tenantPublicId}/{patientPublicId}/home` - Patient home dashboard
- `GET /api/v1/patients/{tenantPublicId}/{patientPublicId}/booking/setup` - Get booking configuration (interval, specialties)
- `POST /api/v1/patients/{tenantPublicId}/{patientPublicId}/appointments` - Book appointment

---

## 🗄️ Database Schema Changes

### New Tables in Each Tenant Schema

#### `doctor_details`
Stores extended doctor information:
- doctor_public_id (FK to doctor)
- mobile_number
- age, gender
- license_number (unique)
- experience_years
- address, city, state
- license_photo_url (nullable, for future file upload feature)

#### `doctor_schedule`
Manages appointment scheduling:
- schedule_public_id (unique identifier)
- doctor_public_id (FK)
- appointment_interval_minutes (15, 20, or 30)
- lunch_break_start_time, lunch_break_end_time
- max_appointments_per_day
- working_days (MONDAY,TUESDAY,...)
- clinic_start_time, clinic_end_time (default: 09:00-18:00)

#### `doctor_license_metadata`
Tracks license file uploads:
- license_id (unique)
- doctor_public_id (FK)
- license_file_name
- license_file_size
- license_upload_time

### Enhanced Public Schema Table
#### `tenant_onboarding_request`
Now includes:
- address (NEW)
- country (NEW, default: "India")
- Other existing fields: hospital_name, city, contact details

---

## 🎨 Frontend Enhancements

### Updated Components
- **Login Screen**: Editable fields for patient mobile, doctor mobile/employee ID
- **Patient Home**: Book appointment, View appointments, History buttons
- **Booking Form**: Name, gender, age, mobile, address fields
- **Specialty Selection**: Chip-based selection with doctor filtering
- **Slot Display**: 
  - Shows interval minutes (e.g., "15-minute intervals")
  - Color-coded: Green (available), Red (unavailable), Disabled (already booked)
- **Appointments Tab**: Upcoming/History filtering

### Store State (Zustand)
New state fields added:
- `bookingName`, `bookingGender`, `bookingAge`
- `bookingMobile`, `bookingAddress`
- `bookingSpecialty`
- `slotIntervalMinutes` (fetched from API)
- `bookedSlots` (array of locked slots)

---

## 🧪 Testing Steps

### 1. Test Tenant Discovery
```bash
curl http://localhost:8082/api/v1/public/tenants | jq .
```

### 2. List Doctors for a Tenant
```bash
curl http://localhost:8082/api/v1/public/tenants/T-1001/doctors | jq .
```

### 3. Submit Tenant Onboarding
```bash
curl -X POST http://localhost:8082/api/v1/public/onboarding/request \
  -H 'Content-Type: application/json' \
  -d '{
    "hospitalName": "Test Hospital",
    "city": "Delhi",
    "address": "Test Address",
    "country": "India",
    "contactName": "Test Admin",
    "contactMobile": "9000000000",
    "contactEmail": "test@hospital.com",
    "facilityType": "hospital"
  }' | jq .
```

### 4. Register Doctor
(Use the JSON structure provided above)

### 5. Access Frontend
Open http://localhost:8086 in browser and:
- Select a tenant (Aurora Multispeciality or GreenLeaf Family Clinic)
- Login with mobile: 9000000001, OTP: 0000
- Navigate to "Book Appointment"
- Select specialty and doctor
- View available slots
- Complete booking

---

## 📊 Verification Queries

### Check Doctor Tables Created
```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d seva_care \
  -c "\dt tenant_t_1001.*"
```

Expected output:
```
 admin_user
 appointment
 doctor
 doctor_details (NEW)
 doctor_license_metadata (NEW)
 doctor_schedule (NEW)
 patient
 prescription
```

### View Registered Doctors
```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d seva_care \
  -c "SELECT doctor_public_id, full_name, specialty FROM tenant_t_1001.doctor;"
```

### View Doctor Details
```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d seva_care \
  -c "SELECT doctor_public_id, mobile_number, age, gender, license_number, \
     experience_years, city FROM tenant_t_1001.doctor_details;"
```

### View Doctor Schedules
```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d seva_care \
  -c "SELECT doctor_public_id, appointment_interval_minutes, \
     lunch_break_start_time, max_appointments_per_day, \
     working_days FROM tenant_t_1001.doctor_schedule;"
```

---

## 🚨 Troubleshooting

### Backend Not Starting
- **Port 8082 in use**: Change PORT environment variable
- **Database connection failed**: Check Docker PostgreSQL is running (`PGPASSWORD=postgres psql -h localhost -U postgres -c "SELECT 1;"`)
- **Migration errors**: Check `/tmp/sevacare-backend.log` for details

### Frontend Not Loading
- **API calls failing**: Verify backend is running on 8082
- **Port 8086 in use**: Stop the process (`lsof -i :8086`) and restart
- **CSS/JS not loading**: Clear browser cache and refresh

### Database Issues
- **Schema not created**: Flyway migrations may have failed. Check backend logs
- **Tables missing**: Run migrations manually via backend restart
- **Connection timeout**: Ensure PostgreSQL container is running (`docker ps`)

---

## 📝 Code Structure

### Backend Modules
- **sevacare-shared**: DTOs, common utilities
- **sevacare-tenant**: Tenant registry and onboarding
- **sevacare-doctor**: Doctor domain logic (including new registerDoctor() method)
- **sevacare-patient**: Patient booking logic
- **sevacare-api**: API controllers and routes

### Frontend Structure
- **src/screens**: Login, Patient Home, Booking, Appointments
- **src/api**: API client with updated base URL
- **src/store**: Zustand state management
- **src/theme**: UI theming for premium/clinic

---

## ✅ What's Working

✅ Multi-tenant architecture with schema per tenant  
✅ Patient booking with specialty filtering  
✅ Appointment slot management with interval display  
✅ Doctor onboarding with comprehensive details  
✅ Doctor schedule configuration  
✅ Tenant onboarding request submission  
✅ Frontend-backend API integration  
✅ Database migration system (Flyway)  
✅ JWT token-based authentication  
✅ Docker PostgreSQL setup  

---

## 🔮 Future Enhancements

- ⏳ WebP conversion pipeline for document uploads
- ⏳ Prescription upload API with file storage
- ⏳ Doctor file/license upload endpoint
- ⏳ Follow-up reminder scheduler (SMS/Push notifications)
- ⏳ Admin dashboard for tenant management
- ⏳ Doctor availability calendar view
- ⏳ Rating and review system

---

## 📞 Support

For issues or questions:
1. Check logs: `/tmp/sevacare-backend.log`
2. Verify database: `PGPASSWORD=postgres psql -h localhost -U postgres -d seva_care`
3. Test API: `curl http://localhost:8082/actuator/health`

---

**Last Updated**: March 21, 2026  
**Frontend**: http://localhost:8086  
**Backend**: http://localhost:8082/api/v1  
**Database**: localhost:5432/seva_care  
