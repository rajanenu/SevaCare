package com.sevacare.patient.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.concurrent.ThreadLocalRandom;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.patient.entity.Appointment;
import com.sevacare.patient.entity.MedicalHistory;
import com.sevacare.patient.entity.Patient;
import com.sevacare.patient.entity.Prescription;
import com.sevacare.patient.entity.PrescriptionMedicine;
import com.sevacare.patient.repository.AppointmentRepository;
import com.sevacare.patient.repository.MedicalHistoryRepository;
import com.sevacare.patient.repository.PatientRepository;
import com.sevacare.patient.repository.PrescriptionMedicineRepository;
import com.sevacare.patient.repository.PrescriptionRepository;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.shared.tenant.TenantContext;

@Service
public class PatientDomainService {

    private static final Logger log = LoggerFactory.getLogger(PatientDomainService.class);

    private final PatientRepository patientRepository;
    private final AppointmentRepository appointmentRepository;
    private final PrescriptionRepository prescriptionRepository;
    private final PrescriptionMedicineRepository prescriptionMedicineRepository;
    private final MedicalHistoryRepository medicalHistoryRepository;
        private final JdbcTemplate jdbcTemplate;

    public PatientDomainService(
            PatientRepository patientRepository,
            AppointmentRepository appointmentRepository,
            PrescriptionRepository prescriptionRepository,
            PrescriptionMedicineRepository prescriptionMedicineRepository,
                        MedicalHistoryRepository medicalHistoryRepository,
                        JdbcTemplate jdbcTemplate
    ) {
        this.patientRepository = patientRepository;
        this.appointmentRepository = appointmentRepository;
        this.prescriptionRepository = prescriptionRepository;
        this.prescriptionMedicineRepository = prescriptionMedicineRepository;
        this.medicalHistoryRepository = medicalHistoryRepository;
                this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public PatientDtos.PatientHomeView home(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));

        List<PatientDtos.AppointmentView> appointments = appointmentRepository.findByTenantPublicIdAndPatientPublicIdOrderByAppointmentSlotDesc(tenantPublicId, patient.getPatientPublicId())
                .stream()
                .map(item -> new PatientDtos.AppointmentView(
                        item.getAppointmentPublicId(),
                        item.getDoctorPublicId(),
                        item.getDoctorPublicId(),
                        item.getAppointmentSlot(),
                        item.getAppointmentStatus(),
                        item.getNotes()
                ))
                .toList();

        List<PatientDtos.PrescriptionView> prescriptions = prescriptionRepository.findByTenantPublicIdAndPatientPublicIdOrderByPrescriptionPublicIdAsc(tenantPublicId, patient.getPatientPublicId())
                .stream()
                .map(item -> new PatientDtos.PrescriptionView(
                        item.getPrescriptionPublicId(),
                        item.getDoctorPublicId(),
                        item.getDoctorName(),
                        item.getIssuedOn(),
                        List.of(item.getNotes())
                ))
                .toList();

        return new PatientDtos.PatientHomeView(patientPublicId, tenantPublicId, appointments, prescriptions);
    }

        @Transactional(readOnly = true)
        public PatientDtos.BookingSetupView bookingSetup(String tenantPublicId, List<String> specialties) {
                List<String> normalized = specialties.stream()
                                .map(value -> value == null ? "" : value.trim())
                                .filter(value -> !value.isBlank())
                                .map(value -> value.substring(0, 1).toUpperCase(Locale.ROOT) + value.substring(1))
                                .distinct()
                                .toList();

                // Build available dates: today + next 2 weeks
                LocalDate today = LocalDate.now();
                List<String> availableDates = new ArrayList<>();
                for (int i = 0; i <= 14; i++) {
                        availableDates.add(today.plusDays(i).toString());
                }

                // Build time slots: Morning 09:00-14:00, Evening 17:00-21:00 in 15-min intervals
                List<String> morningSlots = new ArrayList<>();
                LocalTime morningStart = LocalTime.of(9, 0);
                LocalTime morningEnd = LocalTime.of(14, 0);
                for (LocalTime t = morningStart; t.isBefore(morningEnd); t = t.plusMinutes(15)) {
                        morningSlots.add(t.format(DateTimeFormatter.ofPattern("HH:mm")));
                }

                List<String> eveningSlots = new ArrayList<>();
                LocalTime eveningStart = LocalTime.of(17, 0);
                LocalTime eveningEnd = LocalTime.of(21, 0);
                for (LocalTime t = eveningStart; t.isBefore(eveningEnd); t = t.plusMinutes(15)) {
                        eveningSlots.add(t.format(DateTimeFormatter.ofPattern("HH:mm")));
                }

                return new PatientDtos.BookingSetupView(tenantPublicId, 15, normalized, availableDates, morningSlots, eveningSlots);
        }

        @Transactional
        public PatientDtos.AppointmentBookingResult bookAppointment(String tenantPublicId, String patientPublicId, PatientDtos.AppointmentBookingRequest request) {
                if (!tenantPublicId.equals(request.tenantPublicId()) || !patientPublicId.equals(request.patientPublicId())) {
                        throw new IllegalArgumentException("Tenant or patient mismatch");
                }

                // Validate slot date/time
                validateBookingSlot(request.slot());

                appointmentRepository.findByTenantPublicIdAndDoctorPublicIdAndAppointmentSlotAndAppointmentStatus(
                                tenantPublicId,
                                request.doctorPublicId(),
                                request.slot(),
                                "upcoming"
                        )
                                .ifPresent(existing -> {
                                        throw new IllegalStateException("Selected slot is already booked");
                                });

                Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                                .orElseGet(() -> {
                                        Patient fresh = new Patient();
                                        fresh.setPatientPublicId(patientPublicId);
                                        fresh.setTenantPublicId(tenantPublicId);
                                        fresh.setFullName(request.patientName());
                                        fresh.setMobileNumber(request.mobileNumber());
                                        fresh.setStatus("active");
                                        return patientRepository.save(fresh);
                                });

                patient.setFullName(request.patientName());
                patient.setMobileNumber(request.mobileNumber());
                patientRepository.save(patient);

                Appointment appointment = new Appointment();
                appointment.setAppointmentPublicId(nextAppointmentPublicId());
                appointment.setTenantPublicId(tenantPublicId);
                appointment.setPatientPublicId(patientPublicId);
                appointment.setDoctorPublicId(request.doctorPublicId());
                appointment.setAppointmentSlot(request.slot());
                appointment.setAppointmentStatus("upcoming");
                appointment.setNotes("Booked via patient app");

                Appointment saved = appointmentRepository.save(appointment);
                log.info("patient_book_appointment tenantPublicId={} patientPublicId={} appointmentPublicId={} doctorPublicId={} slot={}",
                        tenantPublicId,
                        patientPublicId,
                        saved.getAppointmentPublicId(),
                        saved.getDoctorPublicId(),
                        saved.getAppointmentSlot());
                return new PatientDtos.AppointmentBookingResult(
                                saved.getAppointmentPublicId(),
                                tenantPublicId,
                                saved.getDoctorPublicId(),
                                saved.getPatientPublicId(),
                                saved.getAppointmentSlot(),
                                saved.getAppointmentStatus()
                );
        }

    @Transactional(readOnly = true)
    public Patient findFirstPatientForTenant(String tenantPublicId) {
        return patientRepository.findFirstByTenantPublicIdOrderByPatientPublicIdAsc(tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("No patient exists for tenant"));
    }

        @Transactional
        public Patient findOrCreatePatientForLogin(String tenantPublicId, String mobileNumber) {
                String normalizedMobileNumber = mobileNumber == null ? "" : mobileNumber.trim();
                if (normalizedMobileNumber.isBlank()) {
                        throw new IllegalArgumentException("Mobile number is required");
                }

                Optional<Patient> existingPatient = patientRepository.findByTenantPublicIdAndMobileNumber(tenantPublicId, normalizedMobileNumber);
                if (existingPatient.isPresent()) {
                        return existingPatient.get();
                }

                Patient patient = new Patient();
                patient.setPatientPublicId(nextPatientPublicId());
                patient.setTenantPublicId(tenantPublicId);
                patient.setMobileNumber(normalizedMobileNumber);
                patient.setStatus("active");
                patient.setFullName("Patient " + normalizedMobileNumber.substring(Math.max(0, normalizedMobileNumber.length() - 4)));
                return patientRepository.save(patient);
        }

    @Transactional
    public Patient save(Patient patient) {
        return patientRepository.save(patient);
    }

    @Transactional(readOnly = true)
    public PatientDtos.PatientCollection listPatientRecords(String tenantPublicId) {
        List<PatientDtos.PatientView> records = patientRepository.findByTenantPublicIdOrderByPatientPublicIdAsc(tenantPublicId)
                .stream()
                .map(patient -> new PatientDtos.PatientView(
                        patient.getPatientPublicId(),
                        patient.getTenantPublicId(),
                        patient.getFullName(),
                        patient.getMobileNumber(),
                        patient.getStatus(),
                        patient.getEmail(),
                        patient.getGender(),
                        patient.getAge(),
                        patient.getAddress()
                ))
                .toList();
        return new PatientDtos.PatientCollection(tenantPublicId, records);
    }

    @Transactional(readOnly = true)
    public PatientDtos.PatientView getPatientRecord(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        return new PatientDtos.PatientView(
                patient.getPatientPublicId(),
                patient.getTenantPublicId(),
                patient.getFullName(),
                patient.getMobileNumber(),
                patient.getStatus(),
                patient.getEmail(),
                patient.getGender(),
                patient.getAge(),
                patient.getAddress()
        );
    }

    @Transactional
    public PatientDtos.PatientView upsertPatientRecord(String tenantPublicId, String patientPublicId, PatientDtos.PatientUpsertRequest request) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseGet(() -> {
                    Patient fresh = new Patient();
                    fresh.setPatientPublicId(patientPublicId);
                    fresh.setTenantPublicId(tenantPublicId);
                    return fresh;
                });

        patient.setFullName(request.fullName());
        patient.setMobileNumber(request.mobileNumber());
        patient.setStatus(request.status());
        patient.setEmail(request.email());
        patient.setGender(request.gender());
        patient.setAge(request.age());
        patient.setAddress(request.address());

        Patient saved = patientRepository.save(patient);
        log.info("patient_upsert tenantPublicId={} patientPublicId={} status={}",
                tenantPublicId,
                saved.getPatientPublicId(),
                saved.getStatus());
        return new PatientDtos.PatientView(
                saved.getPatientPublicId(),
                saved.getTenantPublicId(),
                saved.getFullName(),
                saved.getMobileNumber(),
                saved.getStatus(),
                saved.getEmail(),
                saved.getGender(),
                saved.getAge(),
                saved.getAddress()
        );
    }

    @Transactional
    public void deletePatientRecord(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        patientRepository.delete(patient);
        log.info("patient_delete tenantPublicId={} patientPublicId={}", tenantPublicId, patientPublicId);
    }

    @Transactional(readOnly = true)
    public PatientDtos.AppointmentCollection listAppointmentRecords(String tenantPublicId) {
        List<PatientDtos.AppointmentEntityView> records = appointmentRepository.findByTenantPublicIdOrderByAppointmentSlotDesc(tenantPublicId)
                .stream()
                .map(appointment -> new PatientDtos.AppointmentEntityView(
                        appointment.getAppointmentPublicId(),
                        appointment.getPatientPublicId(),
                        appointment.getDoctorPublicId(),
                        appointment.getAppointmentSlot(),
                        appointment.getAppointmentStatus(),
                        appointment.getNotes()
                ))
                .toList();
        return new PatientDtos.AppointmentCollection(tenantPublicId, records);
    }

    @Transactional(readOnly = true)
    public PatientDtos.AppointmentEntityView getAppointmentRecord(String tenantPublicId, String appointmentPublicId) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));
        return new PatientDtos.AppointmentEntityView(
                appointment.getAppointmentPublicId(),
                appointment.getPatientPublicId(),
                appointment.getDoctorPublicId(),
                appointment.getAppointmentSlot(),
                appointment.getAppointmentStatus(),
                appointment.getNotes()
        );
    }

    @Transactional
    public PatientDtos.AppointmentEntityView upsertAppointmentRecord(String tenantPublicId, String appointmentPublicId, PatientDtos.AppointmentUpsertRequest request) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseGet(() -> {
                    Appointment fresh = new Appointment();
                    fresh.setAppointmentPublicId(appointmentPublicId);
                    fresh.setTenantPublicId(tenantPublicId);
                    return fresh;
                });

        appointment.setPatientPublicId(request.patientPublicId());
        appointment.setDoctorPublicId(request.doctorPublicId());
        appointment.setAppointmentSlot(request.slot());
        appointment.setAppointmentStatus(request.status());
        appointment.setNotes(request.note());

        Appointment saved = appointmentRepository.save(appointment);
        log.info("appointment_upsert tenantPublicId={} appointmentPublicId={} status={}",
                tenantPublicId,
                saved.getAppointmentPublicId(),
                saved.getAppointmentStatus());
        return new PatientDtos.AppointmentEntityView(
                saved.getAppointmentPublicId(),
                saved.getPatientPublicId(),
                saved.getDoctorPublicId(),
                saved.getAppointmentSlot(),
                saved.getAppointmentStatus(),
                saved.getNotes()
        );
    }

    @Transactional
    public void deleteAppointmentRecord(String tenantPublicId, String appointmentPublicId) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));
        appointmentRepository.delete(appointment);
        log.info("appointment_delete tenantPublicId={} appointmentPublicId={}", tenantPublicId, appointmentPublicId);
    }

    @Transactional
    public void completeAppointment(String tenantPublicId, String doctorPublicId, String appointmentPublicId) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found"));
        if (!appointment.getDoctorPublicId().equals(doctorPublicId)) {
            throw new IllegalArgumentException("You are not the assigned doctor for this appointment");
        }
        appointment.setAppointmentStatus("completed");
        appointmentRepository.save(appointment);
        log.info("appointment_complete tenantPublicId={} doctorPublicId={} appointmentPublicId={}", tenantPublicId, doctorPublicId, appointmentPublicId);
    }

    // Prescription Methods
    @Transactional(readOnly = true)
    public PatientDtos.PatientPrescriptionsWrapper getPatientPrescriptions(String tenantPublicId, String patientPublicId) {
        List<PatientDtos.PrescriptionDetailView> prescriptions = prescriptionRepository.findByTenantPublicIdAndPatientPublicIdOrderByPrescriptionPublicIdAsc(tenantPublicId, patientPublicId)
                .stream()
                .map(prescription -> {
                    List<PatientDtos.MedicineView> medicines = prescriptionMedicineRepository.findByPrescriptionPublicId(prescription.getPrescriptionPublicId())
                            .stream()
                            .map(medicine -> new PatientDtos.MedicineView(
                                    medicine.getMedicineName(),
                                    medicine.getStrength(),
                                    medicine.getFrequency(),
                                    medicine.getDuration(),
                                    medicine.getInstructions()
                            ))
                            .toList();
                    return new PatientDtos.PrescriptionDetailView(
                            prescription.getPrescriptionPublicId(),
                            prescription.getDoctorPublicId(),
                            prescription.getDoctorName(),
                            null, null, null,
                            prescription.getIssuedOn(),
                            prescription.getValidUntil() != null ? prescription.getValidUntil().toString() : null,
                            prescription.getNotes(),
                            prescription.getStatus() != null ? prescription.getStatus() : "active",
                            medicines
                    );
                })
                .toList();
        return new PatientDtos.PatientPrescriptionsWrapper(tenantPublicId, patientPublicId, prescriptions);
    }

    @Transactional(readOnly = true)
    public PatientDtos.PrescriptionDetailView getPrescriptionDetail(String tenantPublicId, String prescriptionPublicId) {
        Prescription prescription = prescriptionRepository.findByTenantPublicIdAndPrescriptionPublicId(tenantPublicId, prescriptionPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Prescription not found for tenant"));

        List<PatientDtos.MedicineView> medicines = prescriptionMedicineRepository.findByPrescriptionPublicId(prescriptionPublicId)
                .stream()
                .map(medicine -> new PatientDtos.MedicineView(
                        medicine.getMedicineName(),
                        medicine.getStrength(),
                        medicine.getFrequency(),
                        medicine.getDuration(),
                        medicine.getInstructions()
                ))
                .toList();

        String schema = TenantContext.tenantSchema();
        String doctorSpecialty = jdbcTemplate.query(
                "SELECT specialty FROM " + schema + ".doctor WHERE doctor_public_id = ? LIMIT 1",
                rs -> rs.next() ? rs.getString("specialty") : null,
                prescription.getDoctorPublicId()
        );
        String patientName = jdbcTemplate.query(
                "SELECT full_name FROM " + schema + ".patient WHERE patient_public_id = ? LIMIT 1",
                rs -> rs.next() ? rs.getString("full_name") : null,
                prescription.getPatientPublicId()
        );

        return new PatientDtos.PrescriptionDetailView(
                prescription.getPrescriptionPublicId(),
                prescription.getDoctorPublicId(),
                prescription.getDoctorName(),
                doctorSpecialty,
                prescription.getPatientPublicId(),
                patientName,
                prescription.getIssuedOn(),
                prescription.getValidUntil() != null ? prescription.getValidUntil().toString() : null,
                prescription.getNotes(),
                prescription.getStatus() != null ? prescription.getStatus() : "active",
                medicines
        );
    }

    @Transactional
    public PatientDtos.PrescriptionUploadResult uploadPrescription(String tenantPublicId, String patientPublicId, PatientDtos.PrescriptionUploadRequest request) {
        if (request.medicines() == null || request.medicines().isEmpty()) {
            throw new IllegalArgumentException("At least one medicine is required");
        }

        patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));

        Prescription prescription = new Prescription();
        prescription.setPrescriptionPublicId(nextPrescriptionPublicId());
        prescription.setTenantPublicId(tenantPublicId);
        prescription.setPatientPublicId(patientPublicId);
        prescription.setDoctorPublicId(request.doctorPublicId());
        prescription.setDoctorName(request.doctorName());
        prescription.setIssuedOn(LocalDate.now().toString());
        prescription.setValidUntil(LocalDate.now().plusMonths(1));
        prescription.setNotes(request.notes() != null ? request.notes() : "");
        prescription.setStatus("active");
        prescription.setCreatedAt(LocalDateTime.now());
        prescription.setUpdatedAt(LocalDateTime.now());

        Prescription saved = prescriptionRepository.save(prescription);

        // Save medicines
        if (request.medicines() != null && !request.medicines().isEmpty()) {
            for (PatientDtos.MedicineUploadRequest medicine : request.medicines()) {
                PrescriptionMedicine prescMedicine = new PrescriptionMedicine();
                prescMedicine.setPrescriptionPublicId(saved.getPrescriptionPublicId());
                prescMedicine.setMedicineName(medicine.medicineName());
                prescMedicine.setStrength(medicine.strength());
                prescMedicine.setFrequency(medicine.frequency());
                prescMedicine.setDuration(medicine.duration());
                prescMedicine.setInstructions(medicine.instructions());
                prescMedicine.setCreatedAt(LocalDateTime.now());
                prescriptionMedicineRepository.save(prescMedicine);
            }
        }

        log.info("prescription_upload tenantPublicId={} patientPublicId={} prescriptionPublicId={} doctorPublicId={} medicineCount={}",
                tenantPublicId,
                patientPublicId,
                saved.getPrescriptionPublicId(),
                saved.getDoctorPublicId(),
                request.medicines() != null ? request.medicines().size() : 0);

        return new PatientDtos.PrescriptionUploadResult(
                saved.getPrescriptionPublicId(),
                saved.getPatientPublicId(),
                saved.getDoctorPublicId(),
                saved.getIssuedOn(),
                request.medicines() != null ? request.medicines().size() : 0,
                saved.getStatus()
        );
    }

    @Transactional(readOnly = true)
    public String downloadPrescription(String tenantPublicId, String prescriptionPublicId) {
        Prescription prescription = prescriptionRepository.findByTenantPublicIdAndPrescriptionPublicId(tenantPublicId, prescriptionPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Prescription not found for tenant"));
        
        // For now, return null or a placeholder URL
        // In real implementation, would generate PDF and return S3 URL
                return "https://example.com/prescriptions/" + prescription.getPrescriptionPublicId() + ".pdf";
    }

    @Transactional(readOnly = true)
    public PatientDtos.MedicalHistoryView getPatientMedicalHistory(String tenantPublicId, String patientPublicId) {
        // Get all medical history records
        List<MedicalHistory> allRecords = medicalHistoryRepository.findByTenantPublicIdAndPatientPublicId(tenantPublicId, patientPublicId);

        // Get appointments
        List<Appointment> appointments = appointmentRepository.findByTenantPublicIdAndPatientPublicIdOrderByAppointmentSlotDesc(tenantPublicId, patientPublicId);

        // Get prescriptions
        List<Prescription> prescriptions = prescriptionRepository.findByTenantPublicIdAndPatientPublicIdOrderByPrescriptionPublicIdAsc(tenantPublicId, patientPublicId);

        // Convert all records to views
        List<PatientDtos.MedicalHistoryRecordView> allergies = allRecords.stream()
                .filter(r -> "allergy".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.MedicalHistoryRecordView> conditions = allRecords.stream()
                .filter(r -> "condition".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.MedicalHistoryRecordView> records = allRecords.stream()
                .filter(r -> "record".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.MedicalHistoryRecordView> followUps = allRecords.stream()
                .filter(r -> "follow_up".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.AppointmentEntityView> appointmentViews = appointments.stream()
                .map(a -> new PatientDtos.AppointmentEntityView(a.getAppointmentPublicId(), a.getPatientPublicId(), a.getDoctorPublicId(), a.getAppointmentSlot(), a.getAppointmentStatus(), a.getNotes()))
                .toList();

        List<PatientDtos.PrescriptionDetailView> prescriptionViews = prescriptions.stream()
                .map(p -> {
                    List<PatientDtos.MedicineView> medicines = prescriptionMedicineRepository.findByPrescriptionPublicId(p.getPrescriptionPublicId())
                            .stream()
                            .map(m -> new PatientDtos.MedicineView(m.getMedicineName(), m.getStrength(), m.getFrequency(), m.getDuration(), m.getInstructions()))
                            .toList();
                    return new PatientDtos.PrescriptionDetailView(p.getPrescriptionPublicId(), p.getDoctorPublicId(), p.getDoctorName(), null, p.getPatientPublicId(), null, p.getIssuedOn(), p.getValidUntil() != null ? p.getValidUntil().toString() : null, p.getNotes(), p.getStatus() != null ? p.getStatus() : "active", medicines);
                })
                .toList();

        return new PatientDtos.MedicalHistoryView(
                patientPublicId,
                allergies,
                conditions,
                records,
                followUps,
                appointmentViews,
                prescriptionViews
        );
    }

        private String nextAppointmentPublicId() {
                int value = ThreadLocalRandom.current().nextInt(1000, 9999);
                return "APT-" + value;
        }

        private String nextPrescriptionPublicId() {
                int value = ThreadLocalRandom.current().nextInt(1000, 9999);
                return "RX-" + value;
        }

        private static final DateTimeFormatter SLOT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

        private void validateBookingSlot(String slot) {
                LocalDateTime slotDateTime;
                try {
                        slotDateTime = LocalDateTime.parse(slot, SLOT_FORMATTER);
                } catch (DateTimeParseException e) {
                        throw new IllegalArgumentException("Invalid slot format. Expected: yyyy-MM-dd HH:mm");
                }

                LocalDateTime now = LocalDateTime.now();
                LocalDate today = now.toLocalDate();
                LocalDate slotDate = slotDateTime.toLocalDate();
                LocalTime slotTime = slotDateTime.toLocalTime();

                // No past dates
                if (slotDate.isBefore(today)) {
                        throw new IllegalArgumentException("Cannot book appointments for past dates");
                }

                // Max 2 weeks in advance
                if (slotDate.isAfter(today.plusWeeks(2))) {
                        throw new IllegalArgumentException("Cannot book appointments more than 2 weeks in advance");
                }

                // For today, no past time slots
                if (slotDate.equals(today) && slotDateTime.isBefore(now)) {
                        throw new IllegalArgumentException("Cannot book a time slot that has already passed");
                }

                // Valid time ranges: 09:00-14:00 or 17:00-21:00
                boolean inMorning = !slotTime.isBefore(LocalTime.of(9, 0)) && slotTime.isBefore(LocalTime.of(14, 0));
                boolean inEvening = !slotTime.isBefore(LocalTime.of(17, 0)) && slotTime.isBefore(LocalTime.of(21, 0));
                if (!inMorning && !inEvening) {
                        throw new IllegalArgumentException("Appointment slot must be within 09:00-14:00 or 17:00-21:00");
                }

                // Slot must be on 15-minute boundary
                if (slotTime.getMinute() % 15 != 0) {
                        throw new IllegalArgumentException("Appointment slot must be on a 15-minute interval");
                }
        }

    // Doctor-scoped patient list (derived from appointments)
    @Transactional(readOnly = true)
    public PatientDtos.DoctorPatientCollection getDoctorPatients(String tenantPublicId, String doctorPublicId) {
        List<Appointment> appointments = appointmentRepository.findByTenantPublicIdAndDoctorPublicIdOrderByAppointmentSlotDesc(tenantPublicId, doctorPublicId);

        // Build unique patient list with last appointment info
        java.util.Map<String, Appointment> latestByPatient = new java.util.LinkedHashMap<>();
        for (Appointment a : appointments) {
            latestByPatient.put(a.getPatientPublicId(), a);
        }

        List<PatientDtos.DoctorPatientView> patients = latestByPatient.entrySet().stream()
                .map(entry -> {
                    String patientId = entry.getKey();
                    Appointment lastAppt = entry.getValue();
                    Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientId, tenantPublicId).orElse(null);
                    return new PatientDtos.DoctorPatientView(
                            patientId,
                            patient != null ? patient.getFullName() : patientId,
                            patient != null ? patient.getMobileNumber() : "",
                            patient != null ? patient.getStatus() : "unknown",
                            lastAppt.getAppointmentSlot()
                    );
                })
                .toList();

        return new PatientDtos.DoctorPatientCollection(tenantPublicId, doctorPublicId, patients);
    }

    // Doctor-scoped prescription list
    @Transactional(readOnly = true)
    public PatientDtos.DoctorPrescriptionCollection getDoctorPrescriptions(String tenantPublicId, String doctorPublicId) {
        List<PatientDtos.PrescriptionDetailView> prescriptions = prescriptionRepository.findByTenantPublicIdAndDoctorPublicId(tenantPublicId, doctorPublicId)
                .stream()
                .map(prescription -> {
                    List<PatientDtos.MedicineView> medicines = prescriptionMedicineRepository.findByPrescriptionPublicId(prescription.getPrescriptionPublicId())
                            .stream()
                            .map(medicine -> new PatientDtos.MedicineView(
                                    medicine.getMedicineName(),
                                    medicine.getStrength(),
                                    medicine.getFrequency(),
                                    medicine.getDuration(),
                                    medicine.getInstructions()
                            ))
                            .toList();
                    return new PatientDtos.PrescriptionDetailView(
                            prescription.getPrescriptionPublicId(),
                            prescription.getDoctorPublicId(),
                            prescription.getDoctorName(),
                            null,
                            prescription.getPatientPublicId(),
                            null,
                            prescription.getIssuedOn(),
                            prescription.getValidUntil() != null ? prescription.getValidUntil().toString() : null,
                            prescription.getNotes(),
                            prescription.getStatus() != null ? prescription.getStatus() : "active",
                            medicines
                    );
                })
                .toList();
        return new PatientDtos.DoctorPrescriptionCollection(tenantPublicId, doctorPublicId, prescriptions);
    }

    // Cancel appointment (soft delete via status change)
    @Transactional
        public PatientDtos.AppointmentActionResult cancelAppointment(String tenantPublicId, String patientPublicId, String appointmentPublicId, PatientDtos.AppointmentCancelRequest request) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));

                if (!appointment.getPatientPublicId().equals(patientPublicId)) {
                        throw new IllegalArgumentException("Patient mismatch for appointment");
                }

        appointment.setAppointmentStatus("cancelled");
        appointment.setNotes(request != null && request.reason() != null ? request.reason() : "Cancelled by user");
        appointmentRepository.save(appointment);
        log.info("appointment_cancel tenantPublicId={} appointmentPublicId={} reason={}",
                tenantPublicId,
                appointmentPublicId,
                request != null ? request.reason() : "Cancelled by user");

        return new PatientDtos.AppointmentActionResult(appointmentPublicId, "cancelled", "Appointment cancelled successfully");
    }

    // Reschedule appointment
    @Transactional
        public PatientDtos.AppointmentActionResult rescheduleAppointment(String tenantPublicId, String patientPublicId, String appointmentPublicId, PatientDtos.AppointmentRescheduleRequest request) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));

                if (!appointment.getPatientPublicId().equals(patientPublicId)) {
                        throw new IllegalArgumentException("Patient mismatch for appointment");
                }

        // Check new slot availability
        appointmentRepository.findByTenantPublicIdAndDoctorPublicIdAndAppointmentSlotAndAppointmentStatus(
                tenantPublicId, appointment.getDoctorPublicId(), request.newSlot(), "upcoming")
                .ifPresent(existing -> {
                    throw new IllegalStateException("New slot is already booked");
                });

        appointment.setAppointmentSlot(request.newSlot());
        appointment.setNotes("Rescheduled");
        appointmentRepository.save(appointment);
        log.info("appointment_reschedule tenantPublicId={} appointmentPublicId={} newSlot={}",
                tenantPublicId,
                appointmentPublicId,
                request.newSlot());

        return new PatientDtos.AppointmentActionResult(appointmentPublicId, "rescheduled", "Appointment rescheduled to " + request.newSlot());
    }

        // Delete appointment for patient after marking it cancelled (audit-friendly flow)
        @Transactional
        public PatientDtos.AppointmentActionResult deleteAppointmentForPatient(String tenantPublicId, String patientPublicId, String appointmentPublicId) {
                Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));

                if (!appointment.getPatientPublicId().equals(patientPublicId)) {
                        throw new IllegalArgumentException("Patient mismatch for appointment");
                }

                appointment.setAppointmentStatus("cancelled");
                appointment.setNotes("Cancelled and deleted by patient");
                appointmentRepository.save(appointment);
                appointmentRepository.delete(appointment);

                log.info("appointment_delete_by_patient tenantPublicId={} patientPublicId={} appointmentPublicId={}",
                                tenantPublicId,
                                patientPublicId,
                                appointmentPublicId);

                return new PatientDtos.AppointmentActionResult(appointmentPublicId, "deleted", "Appointment deleted successfully");
        }

    // Doctor patient queue (upcoming appointments)
    @Transactional(readOnly = true)
    public List<PatientDtos.AppointmentEntityView> getDoctorPatientQueue(String tenantPublicId, String doctorPublicId) {
        return appointmentRepository.findByTenantPublicIdAndDoctorPublicIdOrderByAppointmentSlotDesc(tenantPublicId, doctorPublicId)
                .stream()
                .filter(a -> "upcoming".equals(a.getAppointmentStatus()))
                .map(a -> new PatientDtos.AppointmentEntityView(
                        a.getAppointmentPublicId(),
                        a.getPatientPublicId(),
                        a.getDoctorPublicId(),
                        a.getAppointmentSlot(),
                        a.getAppointmentStatus(),
                        a.getNotes()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public PatientDtos.DoctorQueueDayView getDoctorQueueForDate(String tenantPublicId, String doctorPublicId, LocalDate date) {
        List<Appointment> doctorAppointments = appointmentRepository.findByTenantPublicIdAndDoctorPublicIdOrderByAppointmentSlotDesc(tenantPublicId, doctorPublicId);

        List<Appointment> dayAppointments = doctorAppointments.stream()
                .filter(appointment -> parseSlotDate(appointment.getAppointmentSlot())
                        .map(slotDate -> slotDate.equals(date))
                        .orElse(false))
                .sorted(Comparator.comparing(Appointment::getAppointmentSlot))
                .toList();

        List<PatientDtos.DoctorQueueFacetView> facets = dayAppointments.stream()
                .map(appointment -> toDoctorQueueFacet(tenantPublicId, doctorPublicId, appointment, doctorAppointments, date))
                .toList();

        int totalAppointments = (int) facets.stream()
                .filter(facet -> !"cancelled".equalsIgnoreCase(facet.status()))
                .count();

        boolean currentOrPastDay = !date.isAfter(LocalDate.now());
        int pendingNotes = currentOrPastDay
                ? (int) facets.stream()
                        .filter(facet -> !"cancelled".equalsIgnoreCase(facet.status()))
                        .filter(facet -> facet.diagnosis() == null || facet.diagnosis().isBlank())
                        .count()
                : 0;

        int avgConsultMinutes = facets.isEmpty() ? 0 : 15;

        return new PatientDtos.DoctorQueueDayView(
                tenantPublicId,
                doctorPublicId,
                date.toString(),
                totalAppointments,
                pendingNotes,
                avgConsultMinutes,
                facets
        );
    }

    private PatientDtos.DoctorQueueFacetView toDoctorQueueFacet(
            String tenantPublicId,
            String doctorPublicId,
            Appointment appointment,
            List<Appointment> allDoctorAppointments,
            LocalDate selectedDate
    ) {
        Patient patient = patientRepository
                .findByPatientPublicIdAndTenantPublicId(appointment.getPatientPublicId(), tenantPublicId)
                .orElse(null);

        Optional<Prescription> linkedPrescription = resolvePrescriptionForAppointment(doctorPublicId, appointment);

        List<PatientDtos.MedicineView> medicines = linkedPrescription
                .map(prescription -> prescriptionMedicineRepository.findByPrescriptionPublicId(prescription.getPrescriptionPublicId())
                        .stream()
                        .map(medicine -> new PatientDtos.MedicineView(
                                medicine.getMedicineName(),
                                medicine.getStrength(),
                                medicine.getFrequency(),
                                medicine.getDuration(),
                                medicine.getInstructions()
                        ))
                        .toList())
                .orElse(List.of());

        boolean followUp = allDoctorAppointments.stream()
                .filter(other -> !other.getAppointmentPublicId().equals(appointment.getAppointmentPublicId()))
                .filter(other -> other.getPatientPublicId().equals(appointment.getPatientPublicId()))
                .anyMatch(other -> parseSlotDate(other.getAppointmentSlot())
                        .map(slotDate -> slotDate.isBefore(selectedDate))
                        .orElse(false));

        String note = appointment.getNotes() == null ? "" : appointment.getNotes().trim();
        String symptoms = buildSymptoms(note, followUp);
        String diagnosis = linkedPrescription
                .map(Prescription::getNotes)
                .filter(text -> text != null && !text.isBlank())
                .orElse("");
        String rxNotes = linkedPrescription
                .map(Prescription::getNotes)
                .orElse("");

        return new PatientDtos.DoctorQueueFacetView(
                appointment.getAppointmentPublicId(),
                appointment.getPatientPublicId(),
                patient == null ? appointment.getPatientPublicId() : patient.getFullName(),
                appointment.getAppointmentSlot(),
                appointment.getAppointmentStatus(),
                followUp,
                symptoms,
                diagnosis,
                medicines,
                rxNotes
        );
    }

    private Optional<Prescription> resolvePrescriptionForAppointment(String doctorPublicId, Appointment appointment) {
        if (appointment.getAppointmentPublicId() != null && !appointment.getAppointmentPublicId().isBlank()) {
            Optional<Prescription> byAppointment = prescriptionRepository.findByTenantPublicIdAndDoctorPublicIdAndAppointmentPublicId(
                    appointment.getTenantPublicId(),
                    doctorPublicId,
                    appointment.getAppointmentPublicId()
            );
            if (byAppointment.isPresent()) {
                return byAppointment;
            }
        }

        return prescriptionRepository
                .findByTenantPublicIdAndDoctorPublicIdAndPatientPublicIdOrderByCreatedAtDesc(
                        appointment.getTenantPublicId(),
                        doctorPublicId,
                        appointment.getPatientPublicId()
                )
                .stream()
                .findFirst();
    }

    private String buildSymptoms(String notes, boolean followUp) {
        if (!notes.isBlank() && !"Booked via patient app".equalsIgnoreCase(notes) && !"Rescheduled".equalsIgnoreCase(notes)) {
            return notes;
        }

        if (followUp) {
            return "Follow-up review with prior treatment response discussion";
        }

        return "General consultation and symptom assessment pending";
    }

    private Optional<LocalDate> parseSlotDate(String slot) {
        if (slot == null || slot.length() < 10) {
            return Optional.empty();
        }

        try {
            return Optional.of(LocalDate.parse(slot.substring(0, 10)));
        } catch (DateTimeParseException ignored) {
            return Optional.empty();
        }
    }

        private String nextPatientPublicId() {
                Long value = jdbcTemplate.queryForObject("SELECT nextval('public.patient_public_id_seq')", Long.class);
                if (value == null) {
                        throw new IllegalStateException("Could not generate patient id");
                }
                return "P-" + String.format("%04d", value);
        }
}
