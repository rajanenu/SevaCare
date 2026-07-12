package com.sevacare.api.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.admin.service.AdminDomainService;
import com.sevacare.shared.dto.AdminDtos;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.service.TenantRegistryService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {

    private final AdminDomainService adminDomainService;
    private final TenantRegistryService tenantRegistryService;

    public AdminController(AdminDomainService adminDomainService, TenantRegistryService tenantRegistryService) {
        this.adminDomainService = adminDomainService;
        this.tenantRegistryService = tenantRegistryService;
    }

    // Hospital-level support email — separate from any admin's personal profile email
    @GetMapping("/{tenantPublicId}/hospital-profile")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.HospitalProfileView> getHospitalProfile(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(new AdminDtos.HospitalProfileView(tenantRegistryService.getTenantEmail(tenantPublicId)));
    }

    @PutMapping("/{tenantPublicId}/hospital-profile")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.HospitalProfileView> updateHospitalProfile(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody AdminDtos.HospitalProfileUpdateRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        tenantRegistryService.updateTenantEmail(tenantPublicId, request.email());
        return ContractResponse.of(new AdminDtos.HospitalProfileView(tenantRegistryService.getTenantEmail(tenantPublicId)));
    }

    @GetMapping("/{tenantPublicId}/overview")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.AdminOverview> overview(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.overview(tenantPublicId));
    }

    @GetMapping("/{tenantPublicId}/users")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.AdminUserCollection> listAdminUsers(
            @PathVariable String tenantPublicId,
            @RequestParam(defaultValue = "false") boolean activeOnly
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.listAdminUsers(tenantPublicId, activeOnly));
    }

    @GetMapping("/{tenantPublicId}/users/{adminPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','STAFF')")
    public ContractResponse<AdminDtos.AdminUserView> getAdminUser(@PathVariable String tenantPublicId, @PathVariable String adminPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.getAdminUser(tenantPublicId, adminPublicId));
    }

    @GetMapping("/{tenantPublicId}/users/next-public-id")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<String> nextAdminPublicId(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.nextAdminPublicIdForTenant(tenantPublicId));
    }

    @PostMapping("/{tenantPublicId}/users")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.AdminUserView> createAdminUser(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody AdminDtos.AdminUserUpsertRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.createAdminUser(tenantPublicId, request));
    }

    @PutMapping("/{tenantPublicId}/users/{adminPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','STAFF')")
    public ContractResponse<AdminDtos.AdminUserView> updateAdminUser(
            @PathVariable String tenantPublicId,
            @PathVariable String adminPublicId,
            @Valid @RequestBody AdminDtos.AdminUserUpsertRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.updateAdminUser(tenantPublicId, adminPublicId, request));
    }

    @PutMapping("/{tenantPublicId}/users/{adminPublicId}/deactivate")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.AdminUserView> deactivateAdminUser(
            @PathVariable String tenantPublicId,
            @PathVariable String adminPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.deactivateAdminUser(tenantPublicId, adminPublicId));
    }

    @DeleteMapping("/{tenantPublicId}/users/{adminPublicId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.DeleteActorResult> deleteAdminUser(
            @PathVariable String tenantPublicId,
            @PathVariable String adminPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.deleteAdminUser(tenantPublicId, adminPublicId));
    }

    // Self-service account deletion (ADMIN or STAFF deleting their own account)
    // — disables login only; patients, appointments and history are untouched.
    @DeleteMapping("/{tenantPublicId}/users/{adminPublicId}/account")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<String> deleteMyAccount(
            @PathVariable String tenantPublicId,
            @PathVariable String adminPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        adminDomainService.requestAccountDeletion(tenantPublicId, adminPublicId);
        return ContractResponse.of("deleted");
    }

    @GetMapping("/{tenantPublicId}/users/{adminPublicId}/photo")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<PatientDtos.PhotoView> getPhoto(@PathVariable String tenantPublicId, @PathVariable String adminPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.getAdminPhoto(tenantPublicId, adminPublicId));
    }

    @PutMapping("/{tenantPublicId}/users/{adminPublicId}/photo")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<String> updatePhoto(
            @PathVariable String tenantPublicId,
            @PathVariable String adminPublicId,
            @RequestBody PatientDtos.PhotoUpdateRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        adminDomainService.updateAdminPhoto(tenantPublicId, adminPublicId, request.photoBase64());
        return ContractResponse.of("saved");
    }

    @GetMapping("/{tenantPublicId}/staff")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.StaffUserCollection> listStaff(
            @PathVariable String tenantPublicId,
            @RequestParam(defaultValue = "false") boolean activeOnly
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.listStaff(tenantPublicId, activeOnly));
    }

    @PostMapping("/{tenantPublicId}/staff")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.AdminUserView> createStaff(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody AdminDtos.AdminUserUpsertRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.createStaff(tenantPublicId, request));
    }

    @PutMapping("/{tenantPublicId}/staff/{staffPublicId}/deactivate")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.AdminUserView> deactivateStaff(
            @PathVariable String tenantPublicId,
            @PathVariable String staffPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.deactivateStaff(tenantPublicId, staffPublicId));
    }

    @DeleteMapping("/{tenantPublicId}/staff/{staffPublicId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.DeleteActorResult> deleteStaff(
            @PathVariable String tenantPublicId,
            @PathVariable String staffPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.deleteStaff(tenantPublicId, staffPublicId));
    }

    @PostMapping("/doctors")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.ManagedActor> createDoctor(@Valid @RequestBody AdminDtos.CreateActorRequest request) {
        if (!request.tenantPublicId().equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.createDoctor(request));
    }

    @DeleteMapping("/{tenantPublicId}/doctors/{doctorPublicId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.DeleteActorResult> deleteDoctor(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.deleteDoctor(tenantPublicId, doctorPublicId));
    }

    @GetMapping("/{tenantPublicId}/staff-booking-stats")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<List<AdminDtos.StaffBookingStat>> getStaffBookingStats(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.getStaffBookingStats(tenantPublicId));
    }

    @GetMapping("/{tenantPublicId}/booking-channel-stats")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.BookingChannelStats> getBookingChannelStats(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.getBookingChannelStats(tenantPublicId));
    }

    /** Real, period-scoped performance figures for the Reports tab. period: today|week|month|year. */
    @GetMapping("/{tenantPublicId}/reports")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.HospitalReport> getReport(
            @PathVariable String tenantPublicId,
            @RequestParam(defaultValue = "week") String period) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.report(tenantPublicId, period));
    }

    @GetMapping("/{tenantPublicId}/patients")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.PatientPage> listPatients(
            @PathVariable String tenantPublicId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String sortBy,
            @RequestParam(required = false) String sortDir,
            @RequestParam(required = false) String fromDate,
            @RequestParam(required = false) String toDate,
            @RequestParam(required = false) String specialty) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.listPatientsWithLastAppointment(
                tenantPublicId, page, size, search, sortBy, sortDir, fromDate, toDate, specialty));
    }

    @PostMapping("/patients")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.ManagedActor> createPatient(@Valid @RequestBody AdminDtos.CreateActorRequest request) {
        if (!request.tenantPublicId().equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.createPatient(request));
    }

    @DeleteMapping("/{tenantPublicId}/patients/{patientPublicId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<AdminDtos.DeleteActorResult> deletePatient(@PathVariable String tenantPublicId, @PathVariable String patientPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(adminDomainService.deletePatient(tenantPublicId, patientPublicId));
    }
}
