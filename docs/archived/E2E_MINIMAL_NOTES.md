# SevaCare MVP Database Design

## 🏥 Tenant (Hospital)
tenant_id (PK)
name
code (unique)
logo_url
primary_color
status
created_at

---

## 👤 Patient
patient_id (PK)
tenant_id (FK)
name
mobile_number
gender
date_of_birth
created_at

---

## 👨‍⚕️ Doctor
doctor_id (PK)
tenant_id (FK)
name
mobile_number
specialization
experience_years
status
created_at

---

## 🏢 Admin
admin_id (PK)
tenant_id (FK)
name
mobile_number
role (ADMIN/RECEPTIONIST)
created_at

---

## 📅 Doctor Slots
slot_id (PK)
tenant_id (FK)
doctor_id (FK)
start_time
end_time
is_available

---

## 📌 Appointment
appointment_id (PK)
tenant_id (FK)
patient_id (FK)
doctor_id (FK)
slot_id (FK)
appointment_time
status (BOOKED/CANCELLED/COMPLETED)
created_at

---

## 🩺 Consultation
consultation_id (PK)
appointment_id (FK)
doctor_id (FK)
patient_id (FK)
diagnosis
notes
created_at

---

## 💊 Medications
medication_id (PK)
consultation_id (FK)
medicine_name
dosage
duration

---

## 💳 Payments
payment_id (PK)
appointment_id (FK)
amount
status (PAID/PENDING)
payment_mode
created_at

---

## 🔐 Important Rule
All tables must include:
tenant_id

---

## 🧩 Relationships

Tenant
 ├── Patients
 ├── Doctors
 ├── Admins
 ├── Slots
 └── Appointments
        └── Consultation
              └── Medications