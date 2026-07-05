package com.sevacare.admin.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
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

        return adminUserRepository.findFirstByTenantPublicIdAndMobileNumberAndActiveTrueOrderByAdminPublicIdAsc(tenantPublicId, normalizedMobileNumber)
                .orElseThrow(() -> new IllegalArgumentException("No active admin exists for the provided mobile number"));
    }

    @Transactional(readOnly = true)
    public AdminUser findStaffForLogin(String tenantPublicId, String mobileNumber) {
        String normalizedMobileNumber = normalize(mobileNumber);
        if (normalizedMobileNumber == null) {
            throw new IllegalArgumentException("Staff mobile number is required");
        }
        return adminUserRepository.findFirstByTenantPublicIdAndMobileNumberAndUserTypeAndActiveTrueOrderByAdminPublicIdAsc(
                        tenantPublicId, normalizedMobileNumber, "STAFF")
                .orElseThrow(() -> new IllegalArgumentException(
                        "This mobile number is not registered as IP-Staff for this hospital. Please contact your hospital admin."));
    }

    @Transactional(readOnly = true)
    public AdminDtos.AdminOverview overview(String tenantPublicId) {
        long totalPatients = patientRepository.countByTenantPublicId(tenantPublicId);
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
                admins.stream()
                      .filter(a -> !"STAFF".equals(a.getUserType()))
                      .map(this::toAdminUserView).toList()
        );
    }

    @Transactional(readOnly = true)
    public AdminDtos.StaffUserCollection listStaff(String tenantPublicId, boolean activeOnly) {
        List<AdminUser> staff = activeOnly
                ? adminUserRepository.findByTenantPublicIdAndUserTypeAndActiveTrueOrderByAdminPublicIdAsc(tenantPublicId, "STAFF")
                : adminUserRepository.findByTenantPublicIdAndUserTypeOrderByAdminPublicIdAsc(tenantPublicId, "STAFF");
        return new AdminDtos.StaffUserCollection(tenantPublicId, staff.stream().map(this::toAdminUserView).toList());
    }

    @Transactional
    public AdminDtos.AdminUserView createStaff(String tenantPublicId, AdminDtos.AdminUserUpsertRequest request) {
        String mobile = normalize(request.mobileNumber());
        if (mobile == null || mobile.isBlank()) {
            throw new IllegalArgumentException("Mobile number is required for staff");
        }
        if (adminUserRepository.existsByTenantPublicIdAndMobileNumber(tenantPublicId, mobile)) {
            throw new IllegalStateException("Mobile number already registered for this hospital");
        }
        AdminUser staffUser = new AdminUser();
        staffUser.setAdminPublicId(tenantRegistryService.nextAdminPublicId());
        staffUser.setTenantPublicId(tenantPublicId);
        staffUser.setUserType("STAFF");
        applyAdminUserUpdates(staffUser, request, true);
        staffUser.setCreatedAt(LocalDateTime.now());
        AdminUser saved = adminUserRepository.save(staffUser);
        log.info("staff_created tenantPublicId={} adminPublicId={}", tenantPublicId, saved.getAdminPublicId());
        return toAdminUserView(saved);
    }

    @Transactional
    public AdminDtos.DeleteActorResult deleteStaff(String tenantPublicId, String staffPublicId) {
        AdminUser staffUser = adminUserRepository.findById(staffPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Staff not found: " + staffPublicId));
        if (!tenantPublicId.equals(staffUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Staff does not belong to tenant");
        }
        if (!"STAFF".equals(staffUser.getUserType())) {
            throw new IllegalArgumentException("User is not a staff member");
        }
        adminUserRepository.delete(staffUser);
        log.info("staff_deleted tenantPublicId={} staffPublicId={}", tenantPublicId, staffPublicId);
        return new AdminDtos.DeleteActorResult(staffPublicId, tenantPublicId, "deleted");
    }

    @Transactional
    public AdminDtos.AdminUserView deactivateStaff(String tenantPublicId, String staffPublicId) {
        AdminUser staffUser = adminUserRepository.findById(staffPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Staff not found: " + staffPublicId));
        if (!tenantPublicId.equals(staffUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Staff does not belong to tenant");
        }
        staffUser.setActive(false);
        AdminUser saved = adminUserRepository.save(staffUser);
        log.info("staff_deactivated tenantPublicId={} staffPublicId={}", tenantPublicId, staffPublicId);
        return toAdminUserView(saved);
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
        String mobile = request.mobileNumber() != null && !request.mobileNumber().isBlank()
                ? request.mobileNumber().trim() : "0000000000";
        patient.setMobileNumber(mobile);
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
        // Only set userType if not already set (createStaff pre-sets it to STAFF)
        if (adminUser.getUserType() == null) {
            String requestedType = request.userType();
            adminUser.setUserType(requestedType != null && !requestedType.isBlank() ? requestedType.toUpperCase() : "ADMIN");
        }
    }

    private AdminDtos.AdminUserView toAdminUserView(AdminUser adminUser) {
        boolean isGeneric = false; // generic/temp admin flow removed — contact mobile is the admin
        return new AdminDtos.AdminUserView(
                adminUser.getAdminPublicId(),
                adminUser.getTenantPublicId(),
                adminUser.getFullName(),
                adminUser.getName(),
                adminUser.getEmail(),
                adminUser.getMobileNumber(),
                adminUser.isActive(),
                adminUser.getCreatedAt(),
                isGeneric,
                adminUser.getUserType()
        );
    }

    @Transactional(readOnly = true)
    public List<AdminDtos.StaffBookingStat> getStaffBookingStats(String tenantPublicId) {
        String schemaName = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        List<AdminUser> staffList = adminUserRepository.findByTenantPublicIdAndUserTypeOrderByAdminPublicIdAsc(tenantPublicId, "STAFF");
        List<AdminDtos.StaffBookingStat> stats = new ArrayList<>();
        LocalDate today = LocalDate.now();
        String todayStr = today.toString();
        String weekStart = today.minusDays(6).toString();
        String monthStart = today.withDayOfMonth(1).toString();
        String yearStart = today.withDayOfYear(1).toString();
        for (AdminUser staff : staffList) {
            String marker = "Booked by IP-Staff: " + staff.getAdminPublicId();
            int todayCount = countStaffBookings(schemaName, tenantPublicId, marker, todayStr, todayStr);
            int weekCount = countStaffBookings(schemaName, tenantPublicId, marker, weekStart, todayStr);
            int monthCount = countStaffBookings(schemaName, tenantPublicId, marker, monthStart, todayStr);
            int yearCount = countStaffBookings(schemaName, tenantPublicId, marker, yearStart, todayStr);
            stats.add(new AdminDtos.StaffBookingStat(
                    staff.getAdminPublicId(), staff.getFullName(), staff.getMobileNumber(),
                    todayCount, weekCount, monthCount, yearCount));
        }
        return stats;
    }

    private int countStaffBookings(String schemaName, String tenantPublicId, String marker, String fromDate, String toDate) {
        try {
            Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM " + schemaName + ".appointment WHERE tenant_public_id = ? AND notes LIKE ? " +
                    "AND appointment_slot >= ? AND appointment_slot <= ?",
                    Long.class, tenantPublicId, "%" + marker + "%", fromDate, toDate + " 23:59");
            return count == null ? 0 : count.intValue();
        } catch (Exception e) {
            return 0;
        }
    }

    // How patients are arriving at this hospital: Patient App vs QR walk-in vs
    // IP-Staff front-desk booking, plus how many QR requests are still awaiting a
    // doctor's confirmation. Mirrors getStaffBookingStats' today/week/month/year
    // windows but groups by the explicit booking_source column instead of a notes marker.
    @Transactional(readOnly = true)
    public AdminDtos.BookingChannelStats getBookingChannelStats(String tenantPublicId) {
        String schemaName = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        LocalDate today = LocalDate.now();
        String todayStr = today.toString();
        String weekStart = today.minusDays(6).toString();
        String monthStart = today.withDayOfMonth(1).toString();
        String yearStart = today.withDayOfYear(1).toString();

        List<AdminDtos.BookingSourceCount> sources = new ArrayList<>();
        for (String[] source : new String[][] {
                {"PATIENT_APP", "Patient App"},
                {"QR_CODE", "QR Code"},
                {"IP_STAFF", "IP-Staff"}
        }) {
            String code = source[0];
            String label = source[1];
            sources.add(new AdminDtos.BookingSourceCount(
                    code,
                    label,
                    countBySource(schemaName, tenantPublicId, code, todayStr, todayStr),
                    countBySource(schemaName, tenantPublicId, code, weekStart, todayStr),
                    countBySource(schemaName, tenantPublicId, code, monthStart, todayStr),
                    countBySource(schemaName, tenantPublicId, code, yearStart, todayStr)
            ));
        }

        int qrPendingRequests = 0;
        try {
            Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM public.appointment_request WHERE tenant_public_id = ? AND request_status = 'pending'",
                    Long.class, tenantPublicId);
            qrPendingRequests = count == null ? 0 : count.intValue();
        } catch (Exception e) {
            log.warn("qr_pending_requests_count_failed tenantPublicId={}", tenantPublicId, e);
        }

        return new AdminDtos.BookingChannelStats(tenantPublicId, sources, qrPendingRequests);
    }

    private int countBySource(String schemaName, String tenantPublicId, String source, String fromDate, String toDate) {
        try {
            Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM " + schemaName + ".appointment WHERE tenant_public_id = ? AND booking_source = ? " +
                    "AND appointment_slot >= ? AND appointment_slot <= ?",
                    Long.class, tenantPublicId, source, fromDate, toDate + " 23:59");
            return count == null ? 0 : count.intValue();
        } catch (Exception e) {
            return 0;
        }
    }

    @Transactional(readOnly = true)
    public AdminDtos.PatientPage listPatientsWithLastAppointment(
            String tenantPublicId, int page, int size, String search) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        int safeSize   = Math.max(1, Math.min(size, 100));
        int safeOffset = Math.max(0, page) * safeSize;
        boolean hasSearch = search != null && !search.isBlank();
        String like = hasSearch ? "%" + search.trim().toLowerCase() + "%" : null;

        // Total count
        String countSql = "SELECT COUNT(*) FROM " + schema + ".patient WHERE tenant_public_id = ?" +
                (hasSearch ? " AND (LOWER(full_name) LIKE ? OR mobile_number LIKE ?)" : "");
        Object[] countArgs = hasSearch
                ? new Object[]{tenantPublicId, like, like}
                : new Object[]{tenantPublicId};
        Long total = jdbcTemplate.queryForObject(countSql, Long.class, countArgs);

        // Paginated patients with last appointment slot via correlated sub-select
        String dataSql = """
                SELECT p.patient_public_id, p.full_name, p.mobile_number, p.gender, p.age,
                       (SELECT a.appointment_slot FROM %s.appointment a
                        WHERE a.patient_public_id = p.patient_public_id
                          AND a.tenant_public_id  = p.tenant_public_id
                        ORDER BY a.appointment_slot DESC LIMIT 1) AS last_appointment
                FROM %s.patient p
                WHERE p.tenant_public_id = ?
                %s
                ORDER BY p.patient_public_id DESC
                LIMIT ? OFFSET ?
                """.formatted(schema, schema,
                hasSearch ? "AND (LOWER(full_name) LIKE ? OR mobile_number LIKE ?)" : "");

        Object[] dataArgs = hasSearch
                ? new Object[]{tenantPublicId, like, like, safeSize, safeOffset}
                : new Object[]{tenantPublicId, safeSize, safeOffset};

        List<AdminDtos.PatientSummary> patients = jdbcTemplate.query(dataSql, dataArgs, (rs, i) ->
                new AdminDtos.PatientSummary(
                        rs.getString("patient_public_id"),
                        rs.getString("full_name"),
                        rs.getString("mobile_number"),
                        rs.getString("gender"),
                        rs.getObject("age", Integer.class),
                        rs.getString("last_appointment")
                ));

        return new AdminDtos.PatientPage(patients, total == null ? 0 : total, page, safeSize);
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
