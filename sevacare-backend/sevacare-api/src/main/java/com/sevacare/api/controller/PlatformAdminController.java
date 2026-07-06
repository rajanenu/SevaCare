package com.sevacare.api.controller;

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

import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.PlatformAdminDtos;
import com.sevacare.tenant.service.PlatformAdminService;

import jakarta.validation.Valid;

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

    @PostMapping("/tenants")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformTenantView> createTenant(
            @Valid @RequestBody PlatformAdminDtos.PlatformTenantUpsertRequest request
    ) {
        return ContractResponse.of(platformAdminService.createTenant(request));
    }

    @PutMapping("/tenants/{tenantPublicId}")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformTenantView> updateTenant(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody PlatformAdminDtos.PlatformTenantUpsertRequest request
    ) {
        return ContractResponse.of(platformAdminService.updateTenant(tenantPublicId, request));
    }

    @DeleteMapping("/tenants/{tenantPublicId}")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<String> deleteTenant(
            @PathVariable String tenantPublicId
    ) {
        return ContractResponse.of(platformAdminService.deleteTenant(tenantPublicId));
    }

    @PutMapping("/tenants/{tenantPublicId}/hero-image")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<String> updateTenantHeroImage(
            @PathVariable String tenantPublicId,
            @RequestBody PlatformAdminDtos.PlatformTenantHeroImageRequest request
    ) {
        platformAdminService.updateTenantHeroImage(tenantPublicId, request);
        return ContractResponse.of(tenantPublicId);
    }

    @PostMapping("/tenants/{tenantPublicId}/qrcode/generate")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformTenantQrCodeView> generateTenantQrCode(
            @PathVariable String tenantPublicId
    ) {
        return ContractResponse.of(platformAdminService.generateOrGetTenantQrCode(tenantPublicId));
    }

    @GetMapping("/onboarding-requests")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformOnboardingCollection> listOnboardingRequests() {
        return ContractResponse.of(platformAdminService.listOnboardingRequests());
    }

    @GetMapping("/users")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformAdminUserCollection> listPlatformAdmins(
            @RequestParam(defaultValue = "false") boolean activeOnly
    ) {
        return ContractResponse.of(platformAdminService.listPlatformAdmins(activeOnly));
    }

    @GetMapping("/users/{platformAdminPublicId}")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformAdminUserView> getPlatformAdmin(
            @PathVariable String platformAdminPublicId
    ) {
        return ContractResponse.of(platformAdminService.getPlatformAdmin(platformAdminPublicId));
    }

    @GetMapping("/users/next-public-id")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<String> nextPlatformAdminPublicId() {
        return ContractResponse.of(platformAdminService.nextPlatformAdminPublicId());
    }

    @PostMapping("/users")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformAdminUserView> createPlatformAdmin(
            @Valid @RequestBody PlatformAdminDtos.PlatformAdminUserUpsertRequest request
    ) {
        return ContractResponse.of(platformAdminService.createPlatformAdmin(request));
    }

    @PutMapping("/users/{platformAdminPublicId}")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformAdminUserView> updatePlatformAdmin(
            @PathVariable String platformAdminPublicId,
            @Valid @RequestBody PlatformAdminDtos.PlatformAdminUserUpsertRequest request
    ) {
        return ContractResponse.of(platformAdminService.updatePlatformAdmin(platformAdminPublicId, request));
    }

    @PutMapping("/users/{platformAdminPublicId}/deactivate")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PlatformAdminUserView> deactivatePlatformAdmin(
            @PathVariable String platformAdminPublicId
    ) {
        return ContractResponse.of(platformAdminService.deactivatePlatformAdmin(platformAdminPublicId));
    }

    @DeleteMapping("/users/{platformAdminPublicId}")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<String> deletePlatformAdmin(
            @PathVariable String platformAdminPublicId
    ) {
        return ContractResponse.of(platformAdminService.deletePlatformAdmin(platformAdminPublicId));
    }

    // Self-service account deletion — disables login only; tenants/onboarding
    // records this platform admin created or approved are untouched.
    @DeleteMapping("/users/{platformAdminPublicId}/account")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<String> deleteMyAccount(
            @PathVariable String platformAdminPublicId
    ) {
        platformAdminService.requestAccountDeletion(platformAdminPublicId);
        return ContractResponse.of("deleted");
    }
}