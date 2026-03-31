# Phase 3 Roadmap: Advanced Features

**Date**: March 21, 2026  
**Status**: Planning  
**Timeline**: After Phase 2 Integration Complete

---

## Phase 3 Overview

Phase 3 focuses on advanced healthcare features, enhanced user experience, and mobile-specific functionality. These features build on top of the Phase 2 backend API integration.

---

## Feature Categories

### 1. Prescriptions & Medical Records 📋

#### 1.1 Prescription Upload
**Actors**: Doctor, Admin  
**API Endpoint**: `POST /doctors/{tenantId}/{doctorId}/prescriptions`

Features:
- Upload prescription files (PDF, images)
- Generate prescription ID (RX-XXXX)
- Link to patient and appointment
- Store supporting documents

**Implementation**:
```typescript
// Create hook: usePrescriptionUpload
const { upload, uploading, error } = usePrescriptionUpload();

await upload({
  patientPublicId: 'P-1234',
  appointmentPublicId: 'AP-5678',
  medicines: [
    { name: 'Paracetamol', dosage: '500mg', frequency: 'Twice daily' },
    { name: 'Amoxicillin', dosage: '250mg', frequency: 'Thrice daily' }
  ],
  notes: 'Take with food',
  file: prescriptionPDF  // Optional PDF
});
```

#### 1.2 Prescription Viewing
**Actors**: Patient, Doctor, Admin  
**API Endpoint**: `GET /patients/{tenantId}/{patientId}/prescriptions`

Features:
- View past prescriptions
- Download prescription files
- Print prescriptions
- Filter by date/doctor

#### 1.3 Medical History
**Actors**: Patient, Doctor, Admin  
**API Endpoint**: New endpoint to define

Features:
- View all past appointments
- Track medications
- Document allergies
- Medical conditions tracking

---

### 2. Feedback & Ratings ⭐

#### 2.1 Appointment Feedback
**Actors**: Patient  
**API Endpoint**: `POST /appointments/{appointmentId}/feedback`

Features:
- 5-star rating for doctor
- Comment/review section
- Would-recommend toggle
- Anonymity option

**Data Model**:
```typescript
type AppointmentFeedback = {
  appointmentPublicId: string;
  patientPublicId: string;
  doctorPublicId: string;
  rating: number; // 1-5
  comment: string;
  wouldRecommend: boolean;
  isAnonymous: boolean;
  createdAt: string;
};
```

#### 2.2 Doctor Ratings Display
**Actors**: Patients (viewing doctors)  
**Component**: DoctorCard enhancement

Features:
- Show average rating on doctor card
- Display review count
- Show top reviews
- Filter doctors by rating

#### 2.3 Hospital/Clinic Ratings
**Actors**: Patients  
**API Endpoint**: `GET /tenants/{tenantId}/ratings`

---

### 3. Dark Mode 🌙

#### 3.1 Time-Based Dark Mode
**Requirement**: Automatic after 6:30 PM IST

Implementation:
```typescript
// Create hook: useDarkMode
const { isDarkMode, toggleMode } = useDarkMode({
  autoEnabled: true,
  startTime: '18:30', // 6:30 PM
  timeZone: 'Asia/Kolkata'
});
```

#### 3.2 Manual Override
- Enable/disable dark mode manually
- Persist user preference
- System default option

#### 3.3 Theme Colors
- Dark background: #121212 or #1a1a1a
- Text: #FFFFFF or #E0E0E0
- Accent: Maintain brand colors
- Components: Update all with dark variants

#### 3.4 Images & Media in Dark Mode
- Invert brightness for diagrams
- Adjust transparency
- Dark overlays for images

---

### 4. Mobile-Specific Features 📱

#### 4.1 Push Notifications
**Service**: Firebase Cloud Messaging (FCM)

Features:
- Appointment reminders (15 min, 1 hour, 1 day before)
- New prescription available
- Doctor accepted appointment
- Feedback request after appointment
- Emergency alerts

#### 4.2 Offline Support
**Implementation**: React Query + SQLite cache

Features:
- View cached data when offline
- Queue actions for sync when online
- Show sync status indicator
- Conflict resolution

#### 4.3 Background Sync
- Sync blocked patient list
- Sync appointment updates
- Sync rating submissions

#### 4.4 Share Functionality
- Share doctor details
- Share appointment confirmation
- Share prescription results

---

### 5. Messaging & Communication 💬

#### 5.1 In-App Messaging
**Actors**: Doctor ↔ Patient

Features:
- Text messages
- File sharing (reports, test results)
- Message notifications
- Chat history
- Read receipts

**API Endpoints**:
```
POST   /messages
GET    /messages/{appointmentId}
PUT    /messages/{messageId}
DELETE /messages/{messageId}
```

#### 5.2 Video Consultation (Future)
- Integrate video SDK (Agora, Twilio)
- Schedule video appointments
- Recording capability
- Screen sharing

---

### 6. Advanced Profile Features 👤

#### 6.1 Image Upload & Management
**Implementation**: Cloud storage (S3/Firebase)

Features:
- Profile picture upload
- Image cropping/editing
- Delete old images
- Privacy settings

#### 6.2 Medical Documents
**Actors**: Patient

Features:
- Upload test reports
- Upload medical images (X-rays, scans)
- Organized folder structure
- Sharing with doctors

#### 6.3 Emergency Contact Management
Features:
- Add multiple emergency contacts
- Emergency info visibility
- Quick contact access

---

### 7. Advanced Appointment Features 📅

#### 7.1 Appointment Series
**For recurring appointments**

Features:
- Schedule recurring appointments
- Modify single occurrence
- Cancel series or single
- Reschedule entire series

#### 7.2 Appointment Rescheduling
**Actors**: Patient, Doctor

Features:
- View available slots
- Automatic conflict detection
- Cancellation reason tracking
- Reschedule fee policy

#### 7.3 Slot Management (Admin)
- Auto-generate recurring slots
- Bulk import from calendar
- Blackout dates/times
- Buffer between appointments
- Lunch breaks auto-skip

---

### 8. Analytics Dashboard 📊

#### 8.1 Patient Dashboard (Phase 3 Enhanced)
Metrics:
- Appointment history graph
- Doctor visit frequency
- Medication compliance tracking
- Health trends over time

#### 8.2 Doctor Dashboard (Phase 3 Enhanced)
Metrics:
- Patient satisfaction score
- Appointment completion rate
- Average rating trend
- Revenue tracking
- Patient reviews

#### 8.3 Admin Dashboard
Metrics:
- Hospital occupancy rate
- Doctor performance
- Patient demographics
- Revenue analytics
- System health

---

## Implementation Timeline

### Week 1-2: Prescriptions
- [ ] Upload API integration
- [ ] Prescription viewing screen
- [ ] File download/print

### Week 3-4: Ratings & Feedback
- [ ] Feedback submission UI
- [ ] Rating display components
- [ ] Review aggregation

### Week 5: Dark Mode
- [ ] Time-based detection
- [ ] Theme system refactor
- [ ] Component dark variants

### Week 6-7: Push Notifications
- [ ] FCM setup
- [ ] Notification scheduling
- [ ] Deep linking (open right screen)

### Week 8-9: Messaging
- [ ] Message API integration
- [ ] Chat UI components
- [ ] Message notifications

### Week 10: Testing & Polish
- [ ] E2E testing for Phase 3 features
- [ ] Performance optimization
- [ ] Bug fixes

---

## Design Files Needed for Phase 3

1. **Dark mode**: Redesign all screens
2. **Prescriptions**: Prescription viewer UI
3. **Feedback form**: Review/rating screen
4. **Messaging**: Chat interface
5. **Enhanced profiles**: Medical history, documents
6. **Analytics**: Dashboard charts

---

## Backend APIs Needed for Phase 3

| Feature | Endpoint | Method | Status |
|---------|----------|--------|--------|
| Upload prescription | `/prescriptions` | POST | ❌ To Define |
| Get prescriptions | `/prescriptions` | GET | ❌ To Define |
| Download prescription | `/prescriptions/{id}/download` | GET | ❌ To Define |
| Submit feedback | `/appointments/{id}/feedback` | POST | ❌ To Define |
| Get doctor ratings | `/doctors/{id}/ratings` | GET | ❌ To Define |
| Send message | `/messages` | POST | ❌ To Define |
| Get messages | `/messages/{appointmentId}` | GET | ❌ To Define |

---

## Database Schema Changes (Phase 3)

### New Tables
```sql
-- Prescriptions
CREATE TABLE dt_prescription (
  id SERIAL PRIMARY KEY,
  prescription_public_id VARCHAR(20) UNIQUE,
  patient_id INT REFERENCES dt_patient,
  doctor_id INT REFERENCES dt_doctor,
  appointment_id INT REFERENCES dt_appointment,
  medicines JSONB, -- Array of medicine objects
  notes TEXT,
  file_url VARCHAR,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Feedback
CREATE TABLE dt_feedback (
  id SERIAL PRIMARY KEY,
  appointment_id INT REFERENCES dt_appointment,
  rating INT CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  is_anonymous BOOLEAN,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Messages
CREATE TABLE dt_message (
  id SERIAL PRIMARY KEY,
  sender_id INT,
  receiver_id INT,
  appointment_id INT REFERENCES dt_appointment,
  content TEXT,
  attachment_url VARCHAR,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## Dependencies to Add (Phase 3)

```json
{
  "dependencies": {
    "expo-notifications": "^0.27.0",
    "expo-dark-mode": "^1.0.0",
    "react-query": "^3.39.3",
    "expo-sqlite": "^13.4.0",
    "@react-navigation/native": "^latest",
    "firebase": "^9.0.0",
    "react-native-image-picker": "^7.0.0"
  },
  "devDependencies": {
    "@types/react-query": "^1.0.0"
  }
}
```

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Large file uploads (images) | Network timeouts | Implement chunked upload, compression |
| Offline data sync conflicts | Data loss | Implement conflict resolution strategy |
| Notification spam | User frustration | Smart scheduling, user preferences |
| Privacy concerns (messaging) | Data breach | End-to-end encryption (optional) |
| Performance (many messages) | Slow app | Pagination, lazy loading |

---

## Success Criteria

- [ ] All Phase 2 features stable in production
- [ ] Phase 3 features implemented with >95% test coverage
- [ ] App performance: <2s initial load, <500ms API calls
- [ ] User satisfaction: >4.0 rating on app stores
- [ ] Support tickets: <5% Phase 3 related
- [ ] Admin dashboard provides actionable insights

---

## Phase 4 Preview (Future)

- **Telemedicine**: Video consultations
- **Lab Integration**: Direct test booking
- **Pharmacy Integration**: Prescription forwarding
- **Insurance Claims**: Digital billing
- **AI Recommendations**: Doctor suggestions based on symptoms
- **Multi-language Support**: Regional language support

---

**Next Step**: Begin Phase 2 Integration Testing with backend
