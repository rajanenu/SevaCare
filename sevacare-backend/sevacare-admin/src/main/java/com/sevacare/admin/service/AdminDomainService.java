package com.sevacare.admin.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

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
import com.sevacare.shared.dto.IpdDtos;
import com.sevacare.shared.dto.PatientDtos;
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

    /** Memo for {@link #hasColumn} — schema shape only changes when a migration runs. */
    private final Map<String, Boolean> columnPresence = new ConcurrentHashMap<>();

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

        // These are all-time counters, and the labels now say so. The first one was
        // called "Daily visits" while holding every patient ever registered, so the
        // dashboard rendered a lifetime total under a "Today's Patients" LIVE badge
        // and it never moved. Anything that needs a window of time asks report().
        return new AdminDtos.AdminOverview(tenantPublicId, List.of(
                new AdminDtos.Metric("Total patients", String.valueOf(totalPatients), "+0"),
                new AdminDtos.Metric("Upcoming appointments", String.valueOf(upcomingAppointments), "+0"),
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

    /**
     * Self-service "delete my account" for both ADMIN and STAFF (same table).
     * Only disables login — patients, appointments, prescriptions and every
     * other record this user touched are left untouched.
     */
    @Transactional
    public void requestAccountDeletion(String tenantPublicId, String adminPublicId) {
        AdminUser adminUser = adminUserRepository.findById(adminPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Admin not found: " + adminPublicId));
        if (!tenantPublicId.equals(adminUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Admin does not belong to tenant");
        }
        if ("ADMIN".equals(adminUser.getUserType()) && adminUser.isActive()
                && adminUserRepository.countByTenantPublicIdAndActiveTrue(tenantPublicId) <= 1) {
            throw new IllegalStateException("Cannot delete the last active admin user for this hospital");
        }
        adminUser.setActive(false);
        adminUser.setDeletionRequestedAt(LocalDateTime.now());
        adminUserRepository.save(adminUser);
        log.info("admin_user_account_deletion_requested tenantPublicId={} adminPublicId={} userType={}",
                tenantPublicId, adminPublicId, adminUser.getUserType());
    }

    @Transactional(readOnly = true)
    public PatientDtos.PhotoView getAdminPhoto(String tenantPublicId, String adminPublicId) {
        AdminUser adminUser = adminUserRepository.findById(adminPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Admin not found: " + adminPublicId));
        if (!tenantPublicId.equals(adminUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Admin does not belong to tenant");
        }
        return new PatientDtos.PhotoView(adminUser.getPhotoBase64());
    }

    @Transactional
    public void updateAdminPhoto(String tenantPublicId, String adminPublicId, String photoBase64) {
        AdminUser adminUser = adminUserRepository.findById(adminPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Admin not found: " + adminPublicId));
        if (!tenantPublicId.equals(adminUser.getTenantPublicId())) {
            throw new IllegalArgumentException("Admin does not belong to tenant");
        }
        adminUser.setPhotoBase64(photoBase64);
        adminUserRepository.save(adminUser);
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
        // Only touch the login mobile when the caller actually sent one — a
        // profile save that (deliberately) omits it must not null out the
        // number this account signs in with.
        String mobile = normalize(request.mobileNumber());
        if (mobile != null) {
            adminUser.setMobileNumber(mobile);
        }
        adminUser.setSecondaryMobile(normalize(request.secondaryMobile()));

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
                adminUser.getSecondaryMobile(),
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
                {"IP_STAFF", "IP-Staff"},
                {"CHATBOT", "Chatbot"}
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

    // ── Reports ─────────────────────────────────────────────────────────────────
    //
    // Everything the Reports tab shows is counted here, for one window of time, from
    // this tenant's own rows. The tab used to read the all-time overview counters and
    // multiply completed visits by a flat ₹500, which is why it showed the same
    // numbers every day whatever the period button said.
    //
    // What a visit earns is the treating doctor's own fee: the fee stamped on the
    // appointment if one was (consultation_fee), otherwise the fee configured on the
    // doctor. doctor.fee is free text ('₹500'), so the digits are pulled out in SQL —
    // a doctor with no fee on file contributes 0 rather than a guess.

    /** doctor.fee is text like '₹500' — take the digits, and treat 'no fee on file' as 0, not as a default. */
    private static final String FEE_EXPR =
            "COALESCE(NULLIF(a.consultation_fee, 0), " +
            "NULLIF(regexp_replace(COALESCE(d.fee, ''), '[^0-9]', '', 'g'), '')::int, 0)";

    @Transactional(readOnly = true)
    public AdminDtos.HospitalReport report(String tenantPublicId, String period) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        LocalDate today = LocalDate.now();

        // Calendar-aligned windows, so "This Month" also contains the days still to
        // come — that is what makes "upcoming" a real number rather than always 0.
        String key = period == null ? "week" : period.trim().toLowerCase();
        LocalDate from;
        LocalDate to;
        String label;
        switch (key) {
            case "today" -> { from = today;                     to = today;                              label = "Today"; }
            case "month" -> { from = today.withDayOfMonth(1);   to = from.plusMonths(1).minusDays(1);    label = "This Month"; }
            case "year"  -> { from = today.withDayOfYear(1);    to = from.plusYears(1).minusDays(1);     label = "This Year"; }
            default      -> {
                key = "week";
                from = today.minusDays(today.getDayOfWeek().getValue() - 1L); // Monday
                to = from.plusDays(6);
                label = "This Week";
            }
        }
        String fromArg = from.toString();
        String toArg = to + " 23:59";

        // appointment_slot is 'yyyy-MM-dd HH:mm' text, so a lexicographic range is a
        // chronological one — the same trick the rest of this file relies on.
        String joined = " FROM " + schema + ".appointment a LEFT JOIN " + schema + ".doctor d " +
                " ON d.doctor_public_id = a.doctor_public_id " +
                " WHERE a.tenant_public_id = ? AND a.appointment_slot >= ? AND a.appointment_slot <= ? ";

        Map<String, Object> totals = jdbcTemplate.queryForMap(
                "SELECT COUNT(*) AS total, " +
                " COUNT(*) FILTER (WHERE lower(a.appointment_status) = 'completed') AS completed, " +
                " COUNT(*) FILTER (WHERE lower(a.appointment_status) = 'cancelled') AS cancelled, " +
                " COUNT(*) FILTER (WHERE lower(a.appointment_status) NOT IN ('completed', 'cancelled')) AS upcoming, " +
                " COALESCE(SUM(" + FEE_EXPR + ") FILTER (WHERE lower(a.appointment_status) = 'completed'), 0) AS revenue " +
                joined,
                tenantPublicId, fromArg, toArg);

        int total = asInt(totals.get("total"));
        int completed = asInt(totals.get("completed"));
        int cancelled = asInt(totals.get("cancelled"));
        int upcoming = asInt(totals.get("upcoming"));
        long revenue = asLong(totals.get("revenue"));

        int newPatients = countOrZero(
                "SELECT COUNT(*) FROM " + schema + ".patient WHERE tenant_public_id = ? " +
                "AND created_at >= ?::date AND created_at < (?::date + INTERVAL '1 day')",
                tenantPublicId, fromArg, to.toString());

        int prescriptions = countOrZero(
                "SELECT COUNT(*) FROM " + schema + ".prescription WHERE tenant_public_id = ? " +
                "AND COALESCE(prescription_date, created_at::date) BETWEEN ?::date AND ?::date",
                tenantPublicId, fromArg, to.toString());

        // The shape of the period: hour by hour for one day, day by day for a week or
        // a month, month by month for a year. Only buckets that have something in them
        // come back — the client draws the gaps.
        String bucket = switch (key) {
            case "today" -> "substring(a.appointment_slot from 12 for 2) || ':00'";
            case "year"  -> "left(a.appointment_slot, 7)";
            default      -> "left(a.appointment_slot, 10)";
        };
        List<AdminDtos.ReportDayPoint> trend = jdbcTemplate.query(
                "SELECT " + bucket + " AS bucket, COUNT(*) AS booked, " +
                " COUNT(*) FILTER (WHERE lower(a.appointment_status) = 'completed') AS completed " +
                joined + " GROUP BY 1 ORDER BY 1",
                (rs, i) -> new AdminDtos.ReportDayPoint(
                        rs.getString("bucket") == null ? "" : rs.getString("bucket"),
                        rs.getInt("booked"),
                        rs.getInt("completed")),
                tenantPublicId, fromArg, toArg);

        List<AdminDtos.ReportDoctorRow> doctors = jdbcTemplate.query(
                "SELECT a.doctor_public_id, COALESCE(d.full_name, a.doctor_public_id) AS full_name, d.specialty, " +
                " COUNT(*) AS visits, " +
                " COUNT(*) FILTER (WHERE lower(a.appointment_status) = 'completed') AS completed, " +
                " COALESCE(SUM(" + FEE_EXPR + ") FILTER (WHERE lower(a.appointment_status) = 'completed'), 0) AS revenue " +
                joined +
                " GROUP BY a.doctor_public_id, d.full_name, d.specialty " +
                " ORDER BY visits DESC, revenue DESC LIMIT 8",
                (rs, i) -> new AdminDtos.ReportDoctorRow(
                        rs.getString("doctor_public_id"),
                        rs.getString("full_name"),
                        rs.getString("specialty"),
                        rs.getInt("visits"),
                        rs.getInt("completed"),
                        rs.getLong("revenue")),
                tenantPublicId, fromArg, toArg);

        String peakHour = null;
        List<String> hours = jdbcTemplate.query(
                "SELECT substring(a.appointment_slot from 12 for 2) AS hh, COUNT(*) AS c " + joined +
                " AND length(a.appointment_slot) >= 13 GROUP BY 1 ORDER BY c DESC, hh ASC LIMIT 1",
                (rs, i) -> rs.getString("hh"),
                tenantPublicId, fromArg, toArg);
        if (!hours.isEmpty() && hours.get(0) != null && !hours.get(0).isBlank()) {
            try {
                int h = Integer.parseInt(hours.get(0).trim());
                peakHour = String.format("%02d:00 - %02d:00", h, (h + 1) % 24);
            } catch (NumberFormatException ignored) {
                // A slot without a parseable hour simply has no peak — not an error.
            }
        }

        List<AdminDtos.BookingSourceCount> channels = channelCounts(schema, tenantPublicId, fromArg, toArg);

        int avgFee = completed > 0 ? (int) (revenue / completed) : 0;
        int completionRate = total > 0 ? (int) Math.round(completed * 100.0 / total) : 0;

        log.info("admin_report tenantPublicId={} period={} from={} to={} visits={} completed={} revenue={}",
                tenantPublicId, key, from, to, total, completed, revenue);

        return new AdminDtos.HospitalReport(
                tenantPublicId, key, label, from.toString(), to.toString(),
                total, completed, upcoming, cancelled,
                newPatients, prescriptions,
                revenue, avgFee, completionRate, peakHour,
                trend, doctors, channels);
    }

    /** Booking channel mix for one window. The four count fields all carry that window. */
    private List<AdminDtos.BookingSourceCount> channelCounts(
            String schema, String tenantPublicId, String fromArg, String toArg) {
        List<AdminDtos.BookingSourceCount> channels = new ArrayList<>();
        for (String[] source : new String[][] {
                {"PATIENT_APP", "Patient App"},
                {"QR_CODE", "QR Code"},
                {"IP_STAFF", "IP-Staff"},
                {"CHATBOT", "Chatbot"}
        }) {
            int c = countOrZero(
                    "SELECT COUNT(*) FROM " + schema + ".appointment WHERE tenant_public_id = ? AND booking_source = ? " +
                    "AND appointment_slot >= ? AND appointment_slot <= ?",
                    tenantPublicId, source[0], fromArg, toArg);
            channels.add(new AdminDtos.BookingSourceCount(source[0], source[1], c, c, c, c));
        }
        return channels;
    }

    private int countOrZero(String sql, Object... args) {
        Long count = jdbcTemplate.queryForObject(sql, Long.class, args);
        return count == null ? 0 : count.intValue();
    }

    private static int asInt(Object o) {
        return o instanceof Number n ? n.intValue() : 0;
    }

    private static long asLong(Object o) {
        return o instanceof Number n ? n.longValue() : 0L;
    }

    @Transactional(readOnly = true)
    public AdminDtos.PatientPage listPatientsWithLastAppointment(
            String tenantPublicId, int page, int size, String search) {
        return listPatientsWithLastAppointment(tenantPublicId, page, size, search, null, null);
    }

    // Whitelisted sort columns — sortBy is user-supplied and must never be
    // concatenated into SQL directly (SQL injection via ORDER BY).
    private static final java.util.Map<String, String> PATIENT_SORT_COLUMNS = java.util.Map.of(
            "name", "p.full_name",
            "age", "p.age",
            "lastAppointment", "last_appointment"
    );

    @Transactional(readOnly = true)
    public AdminDtos.PatientPage listPatientsWithLastAppointment(
            String tenantPublicId, int page, int size, String search, String sortBy, String sortDir) {
        return listPatientsWithLastAppointment(tenantPublicId, page, size, search, sortBy, sortDir, null, null, null);
    }

    /**
     * fromDate/toDate (yyyy-MM-dd) keep only patients with at least one
     * appointment in that window — how front-desk staff find "everyone who
     * visited last week". specialty narrows the same window to one department's
     * doctors; hospital-wide today (always null from the UI), the hook exists
     * so department-scoped IP-Staff can reuse this query untouched.
     */
    @Transactional(readOnly = true)
    public AdminDtos.PatientPage listPatientsWithLastAppointment(
            String tenantPublicId, int page, int size, String search, String sortBy, String sortDir,
            String fromDate, String toDate, String specialty) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        int safeSize   = Math.max(1, Math.min(size, 100));
        int safeOffset = Math.max(0, page) * safeSize;
        boolean hasSearch = search != null && !search.isBlank();
        String like = hasSearch ? "%" + search.trim().toLowerCase() + "%" : null;
        boolean hasFrom = fromDate != null && !fromDate.isBlank();
        boolean hasTo   = toDate != null && !toDate.isBlank();
        boolean hasSpec = specialty != null && !specialty.isBlank();
        boolean hasVisitFilter = hasFrom || hasTo || hasSpec;

        // "Recent patients first" is the default staff view — most recent
        // visit on top unless an explicit sort is requested.
        String orderBy = (sortBy != null && PATIENT_SORT_COLUMNS.containsKey(sortBy))
                ? PATIENT_SORT_COLUMNS.get(sortBy) + " " + ("asc".equalsIgnoreCase(sortDir) ? "ASC" : "DESC")
                        + " NULLS LAST, p.patient_public_id DESC"
                : "last_appointment DESC NULLS LAST, p.patient_public_id DESC";

        // appointment_slot is 'yyyy-MM-dd[ HH:mm]' text — date-prefix compares work lexically.
        StringBuilder visitClause = new StringBuilder();
        List<Object> visitArgs = new ArrayList<>();
        if (hasVisitFilter) {
            visitClause.append("AND EXISTS (SELECT 1 FROM ").append(schema).append(".appointment a2 ")
                    .append("WHERE a2.patient_public_id = p.patient_public_id AND a2.tenant_public_id = p.tenant_public_id");
            if (hasFrom) { visitClause.append(" AND a2.appointment_slot >= ?"); visitArgs.add(fromDate.trim()); }
            if (hasTo)   { visitClause.append(" AND a2.appointment_slot <= ?"); visitArgs.add(toDate.trim() + " 23:59"); }
            if (hasSpec) {
                visitClause.append(" AND a2.doctor_public_id IN (SELECT d.doctor_public_id FROM ")
                        .append(schema).append(".doctor d WHERE d.specialty = ?)");
                visitArgs.add(specialty.trim());
            }
            visitClause.append(") ");
        }

        String searchClause = hasSearch ? "AND (LOWER(full_name) LIKE ? OR mobile_number LIKE ?) " : "";
        List<Object> filterArgs = new ArrayList<>();
        filterArgs.add(tenantPublicId);
        if (hasSearch) { filterArgs.add(like); filterArgs.add(like); }
        filterArgs.addAll(visitArgs);

        // Total count
        String countSql = "SELECT COUNT(*) FROM " + schema + ".patient p WHERE p.tenant_public_id = ? "
                + searchClause + visitClause;
        Long total = jdbcTemplate.queryForObject(countSql, Long.class, filterArgs.toArray());

        // Paginated patients with last appointment slot via correlated sub-select
        String dataSql = """
                SELECT p.patient_public_id, p.full_name, p.mobile_number, p.gender, p.age, p.blood_group,
                       (SELECT a.appointment_slot FROM %s.appointment a
                        WHERE a.patient_public_id = p.patient_public_id
                          AND a.tenant_public_id  = p.tenant_public_id
                        ORDER BY a.appointment_slot DESC LIMIT 1) AS last_appointment
                FROM %s.patient p
                WHERE p.tenant_public_id = ?
                %s%s
                ORDER BY %s
                LIMIT ? OFFSET ?
                """.formatted(schema, schema, searchClause, visitClause, orderBy);

        List<Object> dataArgList = new ArrayList<>(filterArgs);
        dataArgList.add(safeSize);
        dataArgList.add(safeOffset);
        Object[] dataArgs = dataArgList.toArray();

        List<AdminDtos.PatientSummary> patients = jdbcTemplate.query(dataSql, dataArgs, (rs, i) ->
                new AdminDtos.PatientSummary(
                        rs.getString("patient_public_id"),
                        rs.getString("full_name"),
                        rs.getString("mobile_number"),
                        rs.getString("gender"),
                        rs.getObject("age", Integer.class),
                        rs.getString("blood_group"),
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

    /**
     * Whether a tenant's table carries a column — the shape check the overview uses to
     * stay tolerant of schemas migrated at different times.
     *
     * <p>Memoized because the answer can only change when a migration runs, while the
     * question was being asked on every request: the admin dashboard re-polls its
     * overview every 20 seconds, and {@code information_schema.columns} is a catalog view
     * whose cost grows with the number of columns in the entire database — every tenant
     * onboarded made this check slower for all of them.
     */
    private boolean hasColumn(String schemaName, String tableName, String columnName) {
        return columnPresence.computeIfAbsent(
                schemaName + "." + tableName + "." + columnName,
                key -> Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                        "SELECT EXISTS (SELECT 1 FROM information_schema.columns " +
                                "WHERE table_schema = ? AND table_name = ? AND column_name = ?)",
                        Boolean.class,
                        schemaName,
                        tableName,
                        columnName
                )));
    }

    // ── IPD rooms ─────────────────────────────────────────────────────────────
    // The whole feature is "which patient is in which room". A room is AVAILABLE
    // or OCCUPIED; an admission ties a patient to a room until discharge. One
    // patient per room, admit-now only — the DB's partial unique indexes, not
    // application checks, are what make a double-booked room impossible.

    private static final String ADMITTED = "ADMITTED";
    private static final String DISCHARGED = "DISCHARGED";

    @Transactional(readOnly = true)
    public IpdDtos.RoomCollection listRooms(String tenantPublicId) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        String sql = """
                SELECT r.room_id, r.label, r.room_type, r.status,
                       a.admission_id,
                       to_char(a.admitted_at, 'YYYY-MM-DD HH24:MI') AS admitted_at,
                       a.patient_public_id,
                       p.full_name AS patient_name
                FROM %s.room r
                LEFT JOIN %s.admission a
                       ON a.room_id = r.room_id AND a.status = ?
                LEFT JOIN %s.patient p
                       ON p.patient_public_id = a.patient_public_id
                      AND p.tenant_public_id  = r.tenant_public_id
                WHERE r.tenant_public_id = ?
                ORDER BY LOWER(r.label) ASC
                """.formatted(schema, schema, schema);
        List<IpdDtos.RoomView> rooms = jdbcTemplate.query(sql, (rs, i) ->
                new IpdDtos.RoomView(
                        rs.getLong("room_id"),
                        rs.getString("label"),
                        rs.getString("room_type"),
                        rs.getString("status"),
                        rs.getString("patient_public_id"),
                        rs.getString("patient_name"),
                        rs.getObject("admission_id", Long.class),
                        rs.getString("admitted_at")
                ), ADMITTED, tenantPublicId);
        return new IpdDtos.RoomCollection(rooms);
    }

    @Transactional
    public IpdDtos.RoomView createRoom(String tenantPublicId, IpdDtos.CreateRoomRequest request) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        String label = normalize(request.label());
        if (label == null) {
            throw new IllegalArgumentException("Room label is required");
        }
        String roomType = normalize(request.roomType());
        Long existing = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".room WHERE tenant_public_id = ? AND LOWER(label) = LOWER(?)",
                Long.class, tenantPublicId, label);
        if (existing != null && existing > 0) {
            throw new IllegalStateException("A room named \"" + label + "\" already exists");
        }
        Long roomId = jdbcTemplate.queryForObject(
                "INSERT INTO " + schema + ".room (tenant_public_id, label, room_type, status) " +
                        "VALUES (?, ?, ?, 'AVAILABLE') RETURNING room_id",
                Long.class, tenantPublicId, label, roomType);
        log.info("room_create tenantPublicId={} roomId={} label={}", tenantPublicId, roomId, label);
        return new IpdDtos.RoomView(roomId == null ? 0L : roomId, label, roomType, "AVAILABLE",
                null, null, null, null);
    }

    @Transactional
    public void deleteRoom(String tenantPublicId, long roomId) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        Long active = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".admission WHERE room_id = ? AND status = ?",
                Long.class, roomId, ADMITTED);
        if (active != null && active > 0) {
            throw new IllegalStateException("Discharge the patient before removing this room");
        }
        // A room that has ever held a patient is kept, so the record of who was
        // where survives (and the admission FK stays intact). Only a never-used
        // room — typically one added by mistake — can be removed.
        Long history = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".admission WHERE room_id = ?",
                Long.class, roomId);
        if (history != null && history > 0) {
            throw new IllegalStateException("This room has patient history, so it can't be removed");
        }
        int rows = jdbcTemplate.update(
                "DELETE FROM " + schema + ".room WHERE room_id = ? AND tenant_public_id = ?",
                roomId, tenantPublicId);
        if (rows == 0) {
            throw new IllegalArgumentException("Room not found for tenant");
        }
        log.info("room_delete tenantPublicId={} roomId={}", tenantPublicId, roomId);
    }

    @Transactional(readOnly = true)
    public IpdDtos.AdmissionCollection listAdmissions(String tenantPublicId, String status) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        boolean onlyAdmitted = status == null || status.isBlank() || ADMITTED.equalsIgnoreCase(status);
        StringBuilder sql = new StringBuilder("""
                SELECT a.admission_id, a.patient_public_id, a.room_id, a.status,
                       to_char(a.admitted_at, 'YYYY-MM-DD HH24:MI')   AS admitted_at,
                       to_char(a.discharged_at, 'YYYY-MM-DD HH24:MI') AS discharged_at,
                       a.notes, r.label AS room_label,
                       p.full_name, p.mobile_number, p.blood_group
                FROM %s.admission a
                JOIN %s.room r ON r.room_id = a.room_id
                LEFT JOIN %s.patient p
                       ON p.patient_public_id = a.patient_public_id
                      AND p.tenant_public_id  = a.tenant_public_id
                WHERE a.tenant_public_id = ?
                """.formatted(schema, schema, schema));
        List<Object> args = new ArrayList<>();
        args.add(tenantPublicId);
        if (onlyAdmitted) {
            sql.append("AND a.status = ? ");
            args.add(ADMITTED);
        }
        sql.append("ORDER BY a.admitted_at DESC");
        List<IpdDtos.AdmissionView> admissions = jdbcTemplate.query(sql.toString(), args.toArray(), (rs, i) ->
                new IpdDtos.AdmissionView(
                        rs.getLong("admission_id"),
                        rs.getString("patient_public_id"),
                        rs.getString("full_name"),
                        rs.getString("mobile_number"),
                        rs.getString("blood_group"),
                        rs.getLong("room_id"),
                        rs.getString("room_label"),
                        rs.getString("status"),
                        rs.getString("admitted_at"),
                        rs.getString("discharged_at"),
                        rs.getString("notes")
                ));
        return new IpdDtos.AdmissionCollection(admissions);
    }

    @Transactional
    public IpdDtos.AdmissionView admit(String tenantPublicId, IpdDtos.AdmitRequest request, String admittedBy) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        String patientId = normalize(request.patientPublicId());
        if (patientId == null || request.roomId() == null) {
            throw new IllegalArgumentException("Patient and room are both required");
        }
        long roomId = request.roomId();

        Map<String, Object> patient = firstRow(
                "SELECT full_name, mobile_number, blood_group FROM " + schema + ".patient " +
                        "WHERE patient_public_id = ? AND tenant_public_id = ?",
                patientId, tenantPublicId);
        if (patient == null) {
            throw new IllegalArgumentException("Patient not found for tenant");
        }

        Map<String, Object> room = firstRow(
                "SELECT label, status FROM " + schema + ".room WHERE room_id = ? AND tenant_public_id = ?",
                roomId, tenantPublicId);
        if (room == null) {
            throw new IllegalArgumentException("Room not found for tenant");
        }
        if ("OCCUPIED".equalsIgnoreCase(String.valueOf(room.get("status")))) {
            throw new IllegalStateException("That room is already occupied");
        }

        Long already = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".admission WHERE patient_public_id = ? AND status = ?",
                Long.class, patientId, ADMITTED);
        if (already != null && already > 0) {
            throw new IllegalStateException("This patient is already admitted");
        }

        Long admissionId = jdbcTemplate.queryForObject(
                "INSERT INTO " + schema + ".admission " +
                        "(tenant_public_id, patient_public_id, room_id, status, admitted_by, notes) " +
                        "VALUES (?, ?, ?, 'ADMITTED', ?, ?) RETURNING admission_id",
                Long.class, tenantPublicId, patientId, roomId, admittedBy, normalize(request.notes()));
        jdbcTemplate.update(
                "UPDATE " + schema + ".room SET status = 'OCCUPIED' WHERE room_id = ? AND tenant_public_id = ?",
                roomId, tenantPublicId);
        log.info("ipd_admit tenantPublicId={} admissionId={} patientPublicId={} roomId={}",
                tenantPublicId, admissionId, patientId, roomId);

        return listAdmissions(tenantPublicId, ADMITTED).admissions().stream()
                .filter(a -> admissionId != null && a.admissionId() == admissionId)
                .findFirst()
                .orElseGet(() -> new IpdDtos.AdmissionView(
                        admissionId == null ? 0L : admissionId, patientId,
                        String.valueOf(patient.get("full_name")),
                        String.valueOf(patient.get("mobile_number")),
                        (String) patient.get("blood_group"),
                        roomId, String.valueOf(room.get("label")),
                        ADMITTED, null, null, normalize(request.notes())));
    }

    @Transactional
    public void discharge(String tenantPublicId, long admissionId) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        Map<String, Object> admission = firstRow(
                "SELECT room_id, status FROM " + schema + ".admission " +
                        "WHERE admission_id = ? AND tenant_public_id = ?",
                admissionId, tenantPublicId);
        if (admission == null) {
            throw new IllegalArgumentException("Admission not found for tenant");
        }
        if (!ADMITTED.equalsIgnoreCase(String.valueOf(admission.get("status")))) {
            throw new IllegalStateException("This patient has already been discharged");
        }
        long roomId = ((Number) admission.get("room_id")).longValue();
        jdbcTemplate.update(
                "UPDATE " + schema + ".admission SET status = 'DISCHARGED', discharged_at = CURRENT_TIMESTAMP " +
                        "WHERE admission_id = ? AND tenant_public_id = ?",
                admissionId, tenantPublicId);
        jdbcTemplate.update(
                "UPDATE " + schema + ".room SET status = 'AVAILABLE' WHERE room_id = ? AND tenant_public_id = ?",
                roomId, tenantPublicId);
        log.info("ipd_discharge tenantPublicId={} admissionId={} roomId={}", tenantPublicId, admissionId, roomId);
    }

    private Map<String, Object> firstRow(String sql, Object... args) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, args);
        return rows.isEmpty() ? null : rows.get(0);
    }
}
