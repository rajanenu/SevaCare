package com.sevacare.shared.dto;

import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.constraints.NotBlank;

public final class PlatformAdminDtos {

    private PlatformAdminDtos() {
    }

    public record PlatformAdminOverview(long activeTenants, long onboardingRequests, long approvedOnboardings, long platformAdmins) {
    }

    public record PlatformTenantView(
            String tenantPublicId,
            String hospitalName,
            String themeKey,
            String schemaName,
            String status
    ) {
    }

    public record PlatformTenantCollection(List<PlatformTenantView> tenants) {
    }

    public record PlatformTenantUpsertRequest(
            @NotBlank String hospitalName,
            String themeKey,
            String contactName,
            String contactMobile,
            String contactEmail,
            String status
    ) {
    }

    public record PlatformTenantQrCodeView(
            String qrcodePublicId,
            String tenantPublicId,
            String qrcodeUuid
    ) {
    }

    public record PlatformOnboardingRequestView(
            String requestPublicId,
            String hospitalName,
            String city,
            String facilityType,
            String status,
            String contactName,
            String contactMobile,
            String contactEmail,
            LocalDateTime requestedAt
    ) {
    }

    public record PlatformOnboardingCollection(List<PlatformOnboardingRequestView> requests) {
    }

    public record PlatformAdminUserView(
            String platformAdminPublicId,
            String fullName,
            String mobileNumber,
            String email,
            boolean active,
            LocalDateTime createdAt
    ) {
    }

    public record PlatformAdminUserCollection(List<PlatformAdminUserView> admins) {
    }

    public record PlatformAdminUserUpsertRequest(
            @NotBlank String fullName,
            @NotBlank String mobileNumber,
            String email,
            Boolean active
    ) {
    }
}