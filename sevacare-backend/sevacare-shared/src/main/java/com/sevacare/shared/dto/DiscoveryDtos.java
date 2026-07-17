package com.sevacare.shared.dto;

import java.util.List;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public final class DiscoveryDtos {

    private DiscoveryDtos() {
    }

    /**
     * A tenant as the public directory sees it. {@code hasClinical} / {@code hasPharmacy}
     * mirror the two module switches on {@code tenant_registry}, so a caller that asked
     * for everything can still tell a hospital from a medical store — and a store that
     * also runs a clinic shows up truthfully under both.
     */
    public record TenantSummary(String tenantPublicId, String hospitalName, String city, String specialty,
            String themeKey, String pinCode, boolean hasClinical, boolean hasPharmacy) {
    }

    /**
     * Hero image for a hospital's login background. Once migrated, {@code mediaSha}
     * carries a content-addressed reference (fetch from /api/v1/public/media/{sha})
     * and the base64 fields are null; legacy rows still return base64 + contentType.
     * All fields are null when the tenant has no image.
     */
    public record TenantHeroImage(String tenantPublicId, String imageBase64, String contentType, String mediaSha) {
    }

    public record DoctorSummary(String doctorPublicId, String name, String specialty, String availability, String fee,
            String bookingMode, Integer experienceYears, String qualification, Double averageRating, int reviewCount) {
    }

    public record TenantDirectory(List<TenantSummary> tenants) {
    }

    public record DoctorDirectory(String tenantPublicId, List<DoctorSummary> doctors) {
    }

    public record ReferenceLookups(List<String> specializations, List<String> cities) {
    }

    public record OnboardingDocumentView(String documentPublicId, String fileName, String contentType, long fileSize) {
    }

    public record TenantOnboardingRequest(
            @NotBlank String hospitalName,
            @NotBlank String licenseNumber,
            @NotBlank String state,
            @NotBlank String city,
            @NotBlank String address,
            @NotBlank String country,
            @NotBlank String contactName,
            @NotBlank String contactMobile,
            @NotBlank @Email String contactEmail,
            String supportingDocs,
            @NotBlank @Pattern(regexp = "hospital|clinic") String facilityType,
            String pinCode
    ) {
    }

    public record TenantOnboardingAccepted(String requestPublicId, String status, String message, List<OnboardingDocumentView> documents) {
    }
}
