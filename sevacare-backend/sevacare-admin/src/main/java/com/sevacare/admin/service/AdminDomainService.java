package com.sevacare.admin.service;

import java.time.LocalDateTime;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.admin.entity.AdminUser;
import com.sevacare.admin.repository.AdminUserRepository;
import com.sevacare.doctor.entity.Doctor;
import com.sevacare.doctor.service.DoctorDomainService;
import com.sevacare.patient.entity.Patient;
import com.sevacare.patient.repository.AppointmentRepository;
import com.sevacare.patient.repository.PatientRepository;
import com.sevacare.patient.repository.PrescriptionRepository;
import com.sevacare.patient.service.PatientDomainService;
import com.sevacare.shared.dto.AdminDtos;
import com.sevacare.tenant.service.TenantRegistryService;

@Service
public class AdminDomainService {

    private static final Logger log = LoggerFactory.getLogger(AdminDomainService.class);

    public static final String GENERIC_ADMIN_MOBILE = "9000000003";

    private final AdminUserRepository adminUserRepository;
    private final DoctorDomainService doctorDomainService;
    private final PatientDomainService patientDomainService;
    private final TenantRegistryService tenantRegistryService;
    private final PatientRepository patientRepository;
    private final AppointmentRepository appointmentRepository;
    private final PrescriptionRepository prescriptionRepository;
    private final JdbcTemplate jdbcTemplate;

    public AdminDomainService(
            AdminUserRepository adminUserRepository,
            DoctorDomainService doctorDomainService,
            PatientDomainService patientDomainService,
            TenantRegistryService tenantRegistryService,
            PatientRepository patientRepository,
            AppointmentRepository appointmentRepository,
            PrescriptionRepository prescriptionRepository,
            JdbcTemplate jdbcTemplate
    ) {
        this.adminUserRepository = adminUserRepository;
        this.doctorDomainService = doctorDomainService;
        this.patientDomainService = patientDomainService;
        this.tenantRegistryService = tenantRegistryService;
        this.patientRepository = patientRepository;
        this.appointmentRepository = appointmentRepository;
        this.prescriptionRepository = prescriptionRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public AdminUser findFirstAdminForTenant(String tenantPublicId) {
        return adminUserRepository.findFirstByTenantPublicIdAndActiveTrueOrderByAdminPublicIdAsc(tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("No admin exists for tenant"));
    }

    @Transactional(readOnly = true)
    public AdminUser findAdminForLogin(String tenantPublicId, String mobileNumber) {
        String normalizedMobileNumber = normalize(mobileNumber);
        if (normalizedMobileNumber == null) {
            throw new IllegalArgumentException("Admin mobile number is required");
        }

        if (GENERIC_ADMIN_MOBILE.equals(normalizedMobileNumber)) {
            long realAdminCount = adminUserRepository.countByTenantPublicIdAndActiveTrueAndMobileNumberNot(tenantPublicId, GENERIC_ADMIN_MOBILE);
            if (realAdminCount >= 2) {
                throw new IllegalArgumentException("Generic admin access is disabled. Your hospital already has active admins.");
            }
        }

        return adminUserRepository.findFirstByTenantPublicIdAndMobileNumberAndActiveTrueOrderByAdminPublicIdAsc(tenantPublicId, normalizedMobileNumber)
                .orElseThrow(() -> new IllegalArgumentException("No active admin exists for the provided mobile number"));
    }

    @Transactional(readOnly = true)
    public AdminDtos.AdminOverview overview(String tenantPublicId) {
        long totalPatients = patientRepository.findByTenantPublicIdOrderByPatientPublicIdAsc(tenantPublicId).size();
        long upcomingAppointments = countUpcomingAppointments(tenantPublicId);
        long totalPrescriptions = prescriptionRepository.countByTenantPublicId(tenantPublicId);

        log.info("admin_overview tenantPublicId={} totalPatients={} upcomingAppointments={} totalPrescriptions={}",
                tenantPublicId,
                totalPatients,
                upcomingAppointments,
                totalPrescriptions);

        return new AdminDtos.AdminOverview(tenantPublicId, List.of(
                new AdminDtos.Metric("Daily visits", String.valueOf(totalPatients), "+0"),
                new AdminDtos.Metric("Booked slots", String.valueOf(upcomingAppointments), "+0"),
                new AdminDtos.Metric("Prescriptions issued", String.valueOf(totalPrescriptions), "+0")
        ));
    }

    @Transactional(readOnly = true)
    public AdminDtos.AdminUserCollection listAdminUsers(String tenantPublicId, boolean activeOnly) {
        List<AdminUser> admins = activeOnly
                ? adminUserRepository.findByTenantPublicIdAndActiveTrueOrderByAdminPublicIdAsc(tenantPublicId)
                : adminUserRepository.findByTenantPublicIdOrderByAdminPublicIdAsc(tenantPublicId);

        return new AdminDtos.AdminUserCollection(
                tenantPublicId,
                admins.stream().map(this::toAdminUserView).toList()
        );
    }

    @Transactional(readOnly = true)
    public AdminDtos.AdminUserView getAdminUser(String tenantPublicId, String adminPublicId) {
        AdminUser adminUser = adminUserRepository.findById(adminPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Admin not found: " + adminPublicId));

        if (!tenantPublicId.equals(adminUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Admin does not belong to tenant");
        }

        return toAdminUserView(adminUser);
    }

    @Transactional
    public String nextAdminPublicIdForTenant(String tenantPublicId) {
        tenantRegistryService.mustFindActiveTenant(tenantPublicId);
        return tenantRegistryService.nextAdminPublicId();
    }

    @Transactional
    public AdminDtos.AdminUserView createAdminUser(String tenantPublicId, AdminDtos.AdminUserUpsertRequest request) {
        String normalizedEmail = normalize(request.email());
        if (normalizedEmail != null) {
            adminUserRepository.findByTenantPublicIdAndEmailIgnoreCase(tenantPublicId, normalizedEmail)
                    .ifPresent(existing -> {
                        throw new IllegalStateException("Admin email already exists for tenant");
                    });
        }

        AdminUser adminUser = new AdminUser();
        adminUser.setAdminPublicId(tenantRegistryService.nextAdminPublicId());
        adminUser.setTenantPublicId(tenantPublicId);
        applyAdminUserUpdates(adminUser, request, true);
        adminUser.setCreatedAt(LocalDateTime.now());

        AdminUser saved = adminUserRepository.save(adminUser);
        log.info("admin_user_created tenantPublicId={} adminPublicId={}", tenantPublicId, saved.getAdminPublicId());
        return toAdminUserView(saved);
    }

    @Transactional
    public AdminDtos.AdminUserView updateAdminUser(String tenantPublicId, String adminPublicId, AdminDtos.AdminUserUpsertRequest request) {
        AdminUser adminUser = adminUserRepository.findById(adminPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Admin not found: " + adminPublicId));

        if (!tenantPublicId.equals(adminUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Admin does not belong to tenant");
        }

        String normalizedEmail = normalize(request.email());
        if (normalizedEmail != null) {
            adminUserRepository.findByTenantPublicIdAndEmailIgnoreCase(tenantPublicId, normalizedEmail)
                    .filter(existing -> !existing.getAdminPublicId().equals(adminPublicId))
                    .ifPresent(existing -> {
                        throw new IllegalStateException("Admin email already exists for tenant");
                    });
        }

        applyAdminUserUpdates(adminUser, request, false);
        AdminUser saved = adminUserRepository.save(adminUser);
        log.info("admin_user_updated tenantPublicId={} adminPublicId={}", tenantPublicId, adminPublicId);
        return toAdminUserView(saved);
    }

    @Transactional
    public AdminDtos.AdminUserView deactivateAdminUser(String tenantPublicId, String adminPublicId) {
        AdminUser adminUser = adminUserRepository.findById(adminPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Admin not found: " + adminPublicId));

        if (!tenantPublicId.equals(adminUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Admin does not belong to tenant");
        }

        adminUser.setActive(false);
        AdminUser saved = adminUserRepository.save(adminUser);
        log.info("admin_user_deactivated tenantPublicId={} adminPublicId={}", tenantPublicId, adminPublicId);
        return toAdminUserView(saved);
    }

    @Transactional
    public AdminDtos.DeleteActorResult deleteAdminUser(String tenantPublicId, String adminPublicId) {
        AdminUser adminUser = adminUserRepository.findById(adminPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Admin not found: " + adminPublicId));

        if (!tenantPublicId.equals(adminUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Admin does not belong to tenant");
        }

        if (adminUser.isActive() && adminUserRepository.countByTenantPublicIdAndActiveTrue(tenantPublicId) <= 1) {
            throw new IllegalStateException("Cannot delete the last active admin user");
        }

        adminUserRepository.delete(adminUser);
        log.info("admin_user_deleted tenantPublicId={} adminPublicId={}", tenantPublicId, adminPublicId);
        return new AdminDtos.DeleteActorResult(adminPublicId, tenantPublicId, "deleted");
    }

    @Transactional
    public AdminDtos.ManagedActor createDoctor(AdminDtos.CreateActorRequest request) {
        if (request.name() == null || request.name().isBlank()) {
            throw new IllegalArgumentException("Doctor name is required");
        }
        String mobileNumber = normalize(request.mobileNumber());
        if (mobileNumber == null || mobileNumber.isBlank()) {
            throw new IllegalArgumentException("Doctor mobile number is required for login access");
        }

        Doctor doctor = new Doctor();
        doctor.setDoctorPublicId(tenantRegistryService.nextDoctorPublicId());
        doctor.setTenantPublicId(request.tenantPublicId());
        doctor.setFullName(request.name());
        doctor.setSpecialty(request.specialtyOrAgeBand());
        doctor.setMobileNumber(mobileNumber);
        doctor.setAvailability("Today · Open");
        doctor.setFee("₹500");
        doctor.setActive(true);
        doctorDomainService.save(doctor);
        log.info("admin_create_doctor tenantPublicId={} doctorPublicId={} name={}",
                request.tenantPublicId(),
                doctor.getDoctorPublicId(),
                request.name());
        return new AdminDtos.ManagedActor(doctor.getDoctorPublicId(), request.tenantPublicId(), request.name(), "created");
    }

    @Transactional
    public AdminDtos.DeleteActorResult deleteDoctor(String tenantPublicId, String doctorPublicId) {
        doctorDomainService.deleteDoctorRecord(tenantPublicId, doctorPublicId);
        log.info("admin_delete_doctor tenantPublicId={} doctorPublicId={}", tenantPublicId, doctorPublicId);
        return new AdminDtos.DeleteActorResult(doctorPublicId, tenantPublicId, "deleted");
    }

    @Transactional
    public AdminDtos.ManagedActor createPatient(AdminDtos.CreateActorRequest request) {
        if (request.name() == null || request.name().isBlank()) {
            throw new IllegalArgumentException("Patient name is required");
        }

        Patient patient = new Patient();
        patient.setPatientPublicId(tenantRegistryService.nextPatientPublicId());
        patient.setTenantPublicId(request.tenantPublicId());
        patient.setFullName(request.name());
        patient.setMobileNumber("9000000000");
        patient.setStatus("active");
        patientDomainService.save(patient);
        log.info("admin_create_patient tenantPublicId={} patientPublicId={} name={}",
                request.tenantPublicId(),
                patient.getPatientPublicId(),
                request.name());
        return new AdminDtos.ManagedActor(patient.getPatientPublicId(), request.tenantPublicId(), request.name(), "created");
    }

    @Transactional
    public AdminDtos.DeleteActorResult deletePatient(String tenantPublicId, String patientPublicId) {
        patientDomainService.deletePatientRecord(tenantPublicId, patientPublicId);
        log.info("admin_delete_patient tenantPublicId={} patientPublicId={}", tenantPublicId, patientPublicId);
        return new AdminDtos.DeleteActorResult(patientPublicId, tenantPublicId, "deleted");
    }

    private void applyAdminUserUpdates(AdminUser adminUser, AdminDtos.AdminUserUpsertRequest request, boolean isCreate) {
        String fullName = normalize(request.fullName());
        String displayName = normalize(request.name());
        String resolvedName = displayName != null ? displayName : fullName;
        String resolvedFullName = fullName != null ? fullName : resolvedName;

        if (resolvedFullName == null) {
            throw new IllegalArgumentException("fullName is required");
        }

        adminUser.setFullName(resolvedFullName);
        adminUser.setName(resolvedName != null ? resolvedName : resolvedFullName);
        adminUser.setEmail(normalize(request.email()));
        adminUser.setMobileNumber(normalize(request.mobileNumber()));

        if (request.active() != null) {
            adminUser.setActive(request.active());
        } else if (isCreate) {
            adminUser.setActive(true);
        }
    }

    private AdminDtos.AdminUserView toAdminUserView(AdminUser adminUser) {
        boolean isGeneric = GENERIC_ADMIN_MOBILE.equals(adminUser.getMobileNumber());
        return new AdminDtos.AdminUserView(
                adminUser.getAdminPublicId(),
                adminUser.getTenantPublicId(),
                adminUser.getFullName(),
                adminUser.getName(),
                adminUser.getEmail(),
                adminUser.getMobileNumber(),
                adminUser.isActive(),
                adminUser.getCreatedAt(),
                isGeneric
        );
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private long countUpcomingAppointments(String tenantPublicId) {
        String schemaName = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        if (hasColumn(schemaName, "appointment", "appointment_status")) {
            Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM " + schemaName + ".appointment WHERE tenant_public_id = ? AND appointment_status = ?",
                    Long.class,
                    tenantPublicId,
                    "upcoming"
            );
            return count == null ? 0L : count;
        }

        if (hasColumn(schemaName, "appointment", "status")) {
            Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM " + schemaName + ".appointment WHERE tenant_public_id = ? AND status IN (?, ?)",
                    Long.class,
                    tenantPublicId,
                    "upcoming",
                    "scheduled"
            );
            return count == null ? 0L : count;
        }

        Long count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schemaName + ".appointment WHERE tenant_public_id = ?",
                Long.class,
                tenantPublicId
        );
        return count == null ? 0L : count;
    }

    private boolean hasColumn(String schemaName, String tableName, String columnName) {
        Boolean exists = jdbcTemplate.queryForObject(
                "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = ? AND table_name = ? AND column_name = ?)",
                Boolean.class,
                schemaName,
                tableName,
                columnName
        );
        return Boolean.TRUE.equals(exists);
    }
}
