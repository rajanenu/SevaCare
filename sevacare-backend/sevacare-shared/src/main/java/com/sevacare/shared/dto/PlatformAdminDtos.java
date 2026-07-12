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
            String city,
            String pinCode,
            String themeKey,
            String schemaName,
            String status,
            boolean clinicalEnabled,
            String pharmacyProfileKey,
            /** "Hospital only" · "Pharmacy only" · "Hospital + Pharmacy" — for the tenant list. */
            String kindLabel
    ) {
    }

    public record PlatformTenantCollection(List<PlatformTenantView> tenants) {
    }

    /**
     * Two checkboxes, not one type picker. A business <em>has</em> a hospital, a
     * pharmacy, or both — asking it to pick a single identity would make a large
     * share of Indian clinics answer wrongly.
     *
     * @param hasClinical        doctors, appointments, patients. Absent means true,
     *                           so every existing caller keeps onboarding hospitals
     *                           exactly as it did before this field existed.
     * @param hasPharmacy        absent means false. Pharmacy is never a hospital's
     *                           default: a hospital with no medicine counter must
     *                           never see a pharmacy tab it did not ask for.
     * @param pharmacyProfileKey which kind of pharmacy, when {@code hasPharmacy} is
     *                           set. Null lets the backend pick the sensible default
     *                           — MEDICAL_STORE alone, CLINIC_DISPENSARY beside a
     *                           hospital.
     * @param termsAccepted      the customer was shown SevaCare's terms and agreed to
     *                           them at onboarding. Absent means "not recorded", and
     *                           the tenant's own admin is asked to accept in the app on
     *                           first sign-in — the question is never simply skipped.
     */
    public record PlatformTenantUpsertRequest(
            @NotBlank String hospitalName,
            String city,
            String pinCode,
            String themeKey,
            String contactName,
            String contactMobile,
            String contactEmail,
            String status,
            Boolean hasClinical,
            Boolean hasPharmacy,
            String pharmacyProfileKey,
            Boolean termsAccepted
    ) {
        public boolean clinicalEnabled() {
            return hasClinical == null || hasClinical;
        }

        public boolean pharmacyEnabled() {
            return Boolean.TRUE.equals(hasPharmacy);
        }

        public boolean termsAcceptedAtOnboarding() {
            return Boolean.TRUE.equals(termsAccepted);
        }
    }

    public record PharmacyProfileOptionView(String profileKey, String displayName, String description) {
    }

    public record PharmacyProfileCollection(List<PharmacyProfileOptionView> profiles) {
    }

    public record PlatformTenantQrCodeView(
            String qrcodePublicId,
            String tenantPublicId,
            String qrcodeUuid
    ) {
    }

    /** Hero image upload — pass a null/blank imageBase64 to clear the image. */
    public record PlatformTenantHeroImageRequest(
            String imageBase64,
            String contentType
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