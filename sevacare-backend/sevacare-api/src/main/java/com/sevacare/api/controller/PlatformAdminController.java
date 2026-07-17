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

import com.sevacare.api.service.MediaService;
import com.sevacare.api.service.PasscodeService;
import com.sevacare.shared.dto.AuthDtos;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.PlatformAdminDtos;
import com.sevacare.tenant.service.PlatformAdminService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/platform-admin")
public class PlatformAdminController {

    private final PlatformAdminService platformAdminService;
    private final PasscodeService passcodeService;
    private final MediaService mediaService;

    public PlatformAdminController(PlatformAdminService platformAdminService, PasscodeService passcodeService,
            MediaService mediaService) {
        this.platformAdminService = platformAdminService;
        this.passcodeService = passcodeService;
        this.mediaService = mediaService;
    }

    /**
     * The operator's passcode-recovery lever: clears any user's passcode so the
     * default OTP applies again — including a hospital admin's, which their own
     * tenant cannot do for them.
     */
    @PostMapping("/passcode-reset")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<AuthDtos.PasscodeStatus> resetPasscode(
            @Valid @RequestBody AuthDtos.PasscodeResetRequest request
    ) {
        passcodeService.resetPasscode(request.mobileNumber(), "platform_admin");
        return ContractResponse.of(new AuthDtos.PasscodeStatus(PasscodeService.CredentialMode.DEFAULT_OTP.name()));
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

    /**
     * Fills the "what kind of pharmacy?" dropdown. The labels live in
     * {@code platform.capability_profile}, not in the app, so adding a profile
     * never needs a client release.
     */
    @GetMapping("/pharmacy-profiles")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ContractResponse<PlatformAdminDtos.PharmacyProfileCollection> pharmacyProfiles() {
        return ContractResponse.of(platformAdminService.pharmacyProfiles());
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
        String base64 = request.imageBase64();
        String mediaSha = null;
        if (base64 != null && !base64.isBlank()) {
            if (base64.length() > 4_000_000) {
                throw new IllegalArgumentException("Hero image too large — please upload an image under ~3 MB.");
            }
            MediaService.DecodedImage decoded = MediaService.decode(base64);
            if (decoded != null) {
                String contentType = (request.contentType() != null && !request.contentType().isBlank())
                        ? request.contentType()
                        : decoded.contentType();
                mediaSha = mediaService.put(decoded.bytes(), contentType);
            }
        }
        platformAdminService.updateTenantHeroImage(tenantPublicId, mediaSha);
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