package com.sevacare.api.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.PlatformAdminDtos;
import com.sevacare.tenant.service.PlatformAdminService;

@RestController
@RequestMapping("/api/v1/platform-admin")
public class PlatformAdminController {

    private final PlatformAdminService platformAdminService;

    public PlatformAdminController(PlatformAdminService platformAdminService) {
        this.platformAdminService = platformAdminService;
    }

    @GetMapping("/overview")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformAdminOverview> overview() {
        return ContractResponse.of(platformAdminService.overview());
    }

    @GetMapping("/tenants")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformTenantCollection> listTenants() {
        return ContractResponse.of(platformAdminService.listTenants());
    }

    @GetMapping("/onboarding-requests")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformOnboardingCollection> listOnboardingRequests() {
        return ContractResponse.of(platformAdminService.listOnboardingRequests());
    }
}