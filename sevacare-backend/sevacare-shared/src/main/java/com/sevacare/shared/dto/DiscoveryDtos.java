package com.sevacare.shared.dto;

import java.util.List;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public final class DiscoveryDtos {

    private DiscoveryDtos() {
    }

    public record TenantSummary(String tenantPublicId, String hospitalName, String city, String specialty, String themeKey) {
    }

    public record DoctorSummary(String doctorPublicId, String name, String specialty, String availability, String fee) {
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
            @NotBlank @Pattern(regexp = "hospital|clinic") String facilityType
    ) {
    }

    public record TenantOnboardingAccepted(String requestPublicId, String status, String message, List<OnboardingDocumentView> documents) {
    }
}
