package com.sevacare.doctor.service;

import java.time.LocalDate;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.doctor.entity.Doctor;
import com.sevacare.doctor.repository.DoctorRepository;
import com.sevacare.patient.entity.Patient;
import com.sevacare.patient.repository.PatientRepository;
import com.sevacare.patient.service.PatientDomainService;
import com.sevacare.shared.dto.DiscoveryDtos;
import com.sevacare.shared.dto.DoctorDtos;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.tenant.service.TenantRegistryService;

import jakarta.persistence.EntityManager;

@Service
public class DoctorDomainService {

    private static final Logger log = LoggerFactory.getLogger(DoctorDomainService.class);
    private static final Pattern DOCTOR_ID_PATTERN = Pattern.compile("^D-(\\d+)$");

    private final DoctorRepository doctorRepository;
    private final PatientRepository patientRepository;
    private final TenantRegistryService tenantRegistryService;
    private final JdbcTemplate jdbcTemplate;
    private final PatientDomainService patientDomainService;
    private final EntityManager entityManager;

    public DoctorDomainService(DoctorRepository doctorRepository, PatientRepository patientRepository, TenantRegistryService tenantRegistryService, JdbcTemplate jdbcTemplate, PatientDomainService patientDomainService, EntityManager entityManager) {
        this.doctorRepository = doctorRepository;
        this.patientRepository = patientRepository;
        this.tenantRegistryService = tenantRegistryService;
        this.jdbcTemplate = jdbcTemplate;
        this.patientDomainService = patientDomainService;
        this.entityManager = entityManager;
    }

    @Transactional(readOnly = true)
    public DiscoveryDtos.DoctorDirectory listDoctors(String tenantPublicId) {
        List<DiscoveryDtos.DoctorSummary> doctors = doctorRepository.findByTenantPublicIdAndActiveTrueOrderByDoctorPublicIdAsc(tenantPublicId)
                .stream()
                .map(doctor -> new DiscoveryDtos.DoctorSummary(
                doctor.getDoctorPublicId(),
                doctor.getFullName(),
                doctor.getSpecialty(),
                doctor.getAvailability(),
                doctor.getFee()
            ))
            .toList();

        return new DiscoveryDtos.DoctorDirectory(tenantPublicId, doctors);
        }

        @Transactional(readOnly = true)
        public Doctor findFirstDoctorForTenant(String tenantPublicId) {
        return doctorRepository.findFirstByTenantPublicIdAndActiveTrueOrderByDoctorPublicIdAsc(tenantPublicId)
            .orElseThrow(() -> new IllegalArgumentException("No doctor exists for tenant"));
        }

        @Transactional(readOnly = true)
        public DoctorDtos.DoctorDashboardView dashboard(String tenantPublicId, String doctorPublicId) {
        Doctor doctor = doctorRepository.findByDoctorPublicIdAndTenantPublicId(doctorPublicId, tenantPublicId)
            .orElseThrow(() -> new IllegalArgumentException("Doctor not found for tenant"));

        List<PatientDtos.AppointmentEntityView> queue = patientDomainService.getDoctorPatientQueue(tenantPublicId, doctorPublicId);

        Patient nextPatient = null;
        if (!queue.isEmpty()) {
            nextPatient = patientRepository.findByPatientPublicIdAndTenantPublicId(queue.get(0).patientPublicId(), tenantPublicId).orElse(null);
        }
        if (nextPatient == null) {
            nextPatient = patientRepository.findFirstByTenantPublicIdOrderByPatientPublicIdAsc(tenantPublicId).orElse(null);
        }

        log.info("doctor_dashboard tenantPublicId={} doctorPublicId={} queueSize={}",
                tenantPublicId,
                doctorPublicId,
                queue.size());

        return new DoctorDtos.DoctorDashboardView(
            doctor.getDoctorPublicId(),
            tenantPublicId,
            queue.size(),
            2,
            nextPatient == null ? "P-0000" : nextPatient.getPatientPublicId(),
            nextPatient == null ? "No patient" : nextPatient.getFullName(),
            queue
        );
        }

        @Transactional(readOnly = true)
        public PatientDtos.DoctorQueueDayView queueForDate(String tenantPublicId, String doctorPublicId, LocalDate date) {
        doctorRepository.findByDoctorPublicIdAndTenantPublicId(doctorPublicId, tenantPublicId)
            .orElseThrow(() -> new IllegalArgumentException("Doctor not found for tenant"));
        return patientDomainService.getDoctorQueueForDate(tenantPublicId, doctorPublicId, date);
        }

        @Transactional
        public DoctorDtos.DisablePatientResult disablePatient(String tenantPublicId, String patientPublicId, DoctorDtos.DisablePatientRequest request) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
            .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        patient.setStatus("disabled");
        patientRepository.save(patient);

        String reason = request == null || request.reason() == null || request.reason().isBlank()
            ? "Disabled by doctor action"
            : request.reason();

        log.info("doctor_disable_patient tenantPublicId={} patientPublicId={} reason={}",
                tenantPublicId,
                patientPublicId,
                reason);
        return new DoctorDtos.DisablePatientResult(tenantPublicId, patientPublicId, "disabled", reason);
        }

        @Transactional
        public Doctor save(Doctor doctor) {
        return doctorRepository.save(doctor);
        }

        @Transactional
        public DoctorDtos.DoctorOnboardingResult registerDoctor(String tenantPublicId, DoctorDtos.DoctorOnboardingRequest request) {
            if (request.fullName() == null || request.fullName().isBlank()) {
                throw new IllegalArgumentException("Doctor full name is required");
            }
            if (request.mobileNumber() == null || request.mobileNumber().isBlank()) {
                throw new IllegalArgumentException("Doctor mobile number is required");
            }

            String doctorPublicId = tenantRegistryService.nextDoctorPublicId();
            String schedulePublicId = tenantRegistryService.nextDoctorPublicId().replace("D-", "DS-");

            // Create doctor record
            Doctor doctor = new Doctor();
            doctor.setDoctorPublicId(doctorPublicId);
            doctor.setTenantPublicId(tenantPublicId);
            doctor.setFullName(request.fullName());
            doctor.setSpecialty(request.specialization());
            doctor.setAvailability("Available");
            doctor.setFee("₹500");
            doctor.setActive(true);
            doctorRepository.save(doctor);
            entityManager.flush();

            // Create doctor details record
            jdbcTemplate.update(
                """
                INSERT INTO doctor_details (doctor_public_id, tenant_public_id, mobile_number, age, gender, 
                    license_number, experience_years, address, city, state)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                doctorPublicId,
                tenantPublicId,
                request.mobileNumber(),
                request.age(),
                request.gender(),
                request.licenseNumber(),
                request.experienceYears(),
                request.address(),
                request.city(),
                request.state()
            );

            // Create doctor schedule record
            jdbcTemplate.update(
                """
                INSERT INTO doctor_schedule (schedule_public_id, doctor_public_id, tenant_public_id, 
                    appointment_interval_minutes, lunch_break_start_time, lunch_break_end_time, 
                    max_appointments_per_day, working_days, clinic_start_time, clinic_end_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, '09:00', '18:00')
                """,
                schedulePublicId,
                doctorPublicId,
                tenantPublicId,
                request.appointmentIntervalMinutes(),
                request.lunchBreakStartTime(),
                request.lunchBreakEndTime(),
                request.maxAppointmentsPerDay(),
                request.workingDays()
            );

            log.info("doctor_onboarded tenantPublicId={} doctorPublicId={} specialization={}",
                    tenantPublicId,
                    doctorPublicId,
                    request.specialization());

            return new DoctorDtos.DoctorOnboardingResult(
                doctorPublicId,
                tenantPublicId,
                "registered",
                "Doctor registered successfully with ID: " + doctorPublicId
            );
        }

        @Transactional(readOnly = true)
        public DoctorDtos.DoctorCollection listDoctorRecords(String tenantPublicId) {
            List<DoctorDtos.DoctorView> items = doctorRepository.findByTenantPublicIdAndActiveTrueOrderByDoctorPublicIdAsc(tenantPublicId)
                    .stream()
                    .map(this::toDoctorView)
                    .toList();
            return new DoctorDtos.DoctorCollection(tenantPublicId, items);
        }

        @Transactional(readOnly = true)
        public DoctorDtos.DoctorView getDoctorRecord(String tenantPublicId, String doctorPublicId) {
            Doctor doctor = doctorRepository.findByDoctorPublicIdAndTenantPublicId(doctorPublicId, tenantPublicId)
                    .orElseThrow(() -> new IllegalArgumentException("Doctor not found for tenant"));
            return toDoctorView(doctor);
        }

        @Transactional
        public DoctorDtos.DoctorView upsertDoctorRecord(String tenantPublicId, String doctorPublicId, DoctorDtos.DoctorUpsertRequest request) {
            if (request.fullName() == null || request.fullName().isBlank()) {
                throw new IllegalArgumentException("Doctor full name is required");
            }

            Doctor doctor = doctorRepository.findByDoctorPublicIdAndTenantPublicId(doctorPublicId, tenantPublicId)
                    .orElseGet(() -> {
                        Doctor fresh = new Doctor();
                        fresh.setDoctorPublicId(doctorPublicId);
                        fresh.setTenantPublicId(tenantPublicId);
                        return fresh;
                    });

            doctor.setFullName(request.fullName());
            doctor.setSpecialty(request.specialty());
            doctor.setAvailability(request.availability());
            doctor.setFee(request.fee());
            doctor.setActive(request.active());
            doctor.setAge(request.age());
            doctor.setAddress(request.address());
            doctor.setAboutMe(request.aboutMe());
            doctor.setAvailableFrom(request.availableFrom());
            doctor.setReadyToLookPatients(request.readyToLookPatients());

            Doctor saved = doctorRepository.save(doctor);
            log.info("doctor_upsert tenantPublicId={} doctorPublicId={} active={}",
                    tenantPublicId,
                    saved.getDoctorPublicId(),
                    saved.isActive());
            return toDoctorView(saved);
        }

        @Transactional
        public DoctorDtos.DoctorView createDoctorRecord(String tenantPublicId, DoctorDtos.DoctorUpsertRequest request) {
            String nextDoctorId = nextDoctorPublicIdForTenant(tenantPublicId);
            return upsertDoctorRecord(tenantPublicId, nextDoctorId, request);
        }

        @Transactional(readOnly = true)
        public String nextDoctorPublicIdForTenant(String tenantPublicId) {
            int maxNumeric = doctorRepository.findByTenantPublicIdOrderByDoctorPublicIdAsc(tenantPublicId)
                    .stream()
                    .map(Doctor::getDoctorPublicId)
                    .mapToInt(this::extractDoctorIdNumber)
                    .max()
                    .orElse(1000);
            return "D-" + String.format("%04d", maxNumeric + 1);
        }

        @Transactional
        public void deleteDoctorRecord(String tenantPublicId, String doctorPublicId) {
            doctorRepository.findByDoctorPublicIdAndTenantPublicId(doctorPublicId, tenantPublicId)
                    .orElseThrow(() -> new IllegalArgumentException("Doctor not found for tenant"));

            String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);

            jdbcTemplate.update(
                    "DELETE FROM " + schema + ".prescription_medicine pm USING " + schema + ".prescription p " +
                            "WHERE pm.prescription_public_id = p.prescription_public_id AND p.doctor_public_id = ?",
                    doctorPublicId
            );
            jdbcTemplate.update("DELETE FROM " + schema + ".prescription WHERE doctor_public_id = ?", doctorPublicId);
            jdbcTemplate.update("DELETE FROM " + schema + ".appointment WHERE doctor_public_id = ?", doctorPublicId);
            jdbcTemplate.update("DELETE FROM " + schema + ".doctor_schedule WHERE doctor_public_id = ?", doctorPublicId);
            jdbcTemplate.update("DELETE FROM " + schema + ".doctor_license_metadata WHERE doctor_public_id = ?", doctorPublicId);
            jdbcTemplate.update("DELETE FROM " + schema + ".doctor_details WHERE doctor_public_id = ?", doctorPublicId);
            jdbcTemplate.update("DELETE FROM " + schema + ".doctor WHERE doctor_public_id = ?", doctorPublicId);

            log.info("doctor_delete tenantPublicId={} doctorPublicId={}", tenantPublicId, doctorPublicId);
        }

        private int extractDoctorIdNumber(String doctorPublicId) {
            if (doctorPublicId == null) {
                return 0;
            }
            Matcher matcher = DOCTOR_ID_PATTERN.matcher(doctorPublicId.trim());
            if (!matcher.matches()) {
                return 0;
            }
            try {
                return Integer.parseInt(matcher.group(1));
            } catch (NumberFormatException ex) {
                return 0;
            }
        }

        private DoctorDtos.DoctorView toDoctorView(Doctor doctor) {
            return new DoctorDtos.DoctorView(
                    doctor.getDoctorPublicId(),
                    doctor.getTenantPublicId(),
                    doctor.getFullName(),
                    doctor.getSpecialty(),
                    doctor.getAvailability(),
                    doctor.getFee(),
                    doctor.isActive(),
                    doctor.getAge(),
                    doctor.getAddress(),
                    doctor.getAboutMe(),
                    doctor.getAvailableFrom(),
                    doctor.getReadyToLookPatients()
            );
        }
    }
