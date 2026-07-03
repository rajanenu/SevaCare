package com.sevacare.api.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.admin.repository.AdminUserRepository;
import com.sevacare.doctor.service.LeaveRequestService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.NotificationDtos;
import com.sevacare.shared.tenant.TenantContext;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class LeaveRequestController {

    private final LeaveRequestService leaveRequestService;
    private final AdminUserRepository adminUserRepository;

    public LeaveRequestController(LeaveRequestService leaveRequestService,
                                  AdminUserRepository adminUserRepository) {
        this.leaveRequestService = leaveRequestService;
        this.adminUserRepository = adminUserRepository;
    }

    // Doctor submits a leave/message request
    @PostMapping("/{tenantPublicId}/doctors/{doctorPublicId}/leave-requests")
    @PreAuthorize("hasRole('DOCTOR')")
    public ContractResponse<NotificationDtos.LeaveRequestView> create(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @RequestParam(required = false, defaultValue = "") String adminPublicId,
            @Valid @RequestBody NotificationDtos.LeaveRequestCreateRequest body
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        // Auto-resolve admin if caller didn't supply one (doctor screens don't know admin IDs)
        String resolvedAdminId = adminPublicId.isBlank()
                ? adminUserRepository
                        .findFirstByTenantPublicIdAndActiveTrueOrderByAdminPublicIdAsc(tenantPublicId)
                        .map(a -> a.getAdminPublicId())
                        .orElse("")
                : adminPublicId;
        return ContractResponse.of(leaveRequestService.createLeaveRequest(tenantPublicId, doctorPublicId, body, resolvedAdminId));
    }

    // Doctor views their own requests
    @GetMapping("/{tenantPublicId}/doctors/{doctorPublicId}/leave-requests")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<NotificationDtos.LeaveRequestCollection> listForDoctor(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(leaveRequestService.listForDoctor(tenantPublicId, doctorPublicId));
    }

    // IP-Staff submits a leave/message request (staff JWTs carry the ADMIN role)
    @PostMapping("/{tenantPublicId}/staff/{staffPublicId}/leave-requests")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<NotificationDtos.LeaveRequestView> createForStaff(
            @PathVariable String tenantPublicId,
            @PathVariable String staffPublicId,
            @Valid @RequestBody NotificationDtos.LeaveRequestCreateRequest body
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        var staff = adminUserRepository.findById(staffPublicId)
                .filter(a -> tenantPublicId.equals(a.getTenantPublicId()))
                .orElseThrow(() -> new IllegalArgumentException("Staff member not found"));
        // Notify the first active non-requester admin
        String resolvedAdminId = adminUserRepository
                .findByTenantPublicIdAndActiveTrueOrderByAdminPublicIdAsc(tenantPublicId)
                .stream()
                .filter(a -> !a.getAdminPublicId().equals(staffPublicId))
                .filter(a -> !"STAFF".equals(a.getUserType()))
                .map(a -> a.getAdminPublicId())
                .findFirst()
                .orElse("");
        return ContractResponse.of(leaveRequestService.createStaffLeaveRequest(
                tenantPublicId, staffPublicId, staff.getFullName(), body, resolvedAdminId));
    }

    // IP-Staff views their own requests
    @GetMapping("/{tenantPublicId}/staff/{staffPublicId}/leave-requests")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<NotificationDtos.LeaveRequestCollection> listForStaff(
            @PathVariable String tenantPublicId,
            @PathVariable String staffPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(leaveRequestService.listForStaff(tenantPublicId, staffPublicId));
    }

    // Admin views ALL requests across all doctors
    @GetMapping("/{tenantPublicId}/admin/leave-requests")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<NotificationDtos.LeaveRequestCollection> listForAdmin(
            @PathVariable String tenantPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(leaveRequestService.listForAdmin(tenantPublicId));
    }

    // Admin takes action: APPROVE | DECLINE | COMMENT
    @PutMapping("/{tenantPublicId}/admin/leave-requests/{requestPublicId}/action")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<NotificationDtos.LeaveRequestView> action(
            @PathVariable String tenantPublicId,
            @PathVariable String requestPublicId,
            @Valid @RequestBody NotificationDtos.LeaveRequestActionRequest body
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(leaveRequestService.actionRequest(tenantPublicId, requestPublicId, body));
    }
}
