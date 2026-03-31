package com.sevacare.shared.dto;

import java.time.LocalDateTime;
import java.util.List;

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
}