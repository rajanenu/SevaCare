package com.sevacare.shared.dto;

import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.constraints.NotBlank;

public final class AdminDtos {

    private AdminDtos() {
    }

    public record AdminOverview(String tenantPublicId, List<Metric> metrics) {
    }

    public record Metric(String label, String value, String trend) {
    }

    public record CreateActorRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String name,
            @NotBlank String specialtyOrAgeBand,
            String mobileNumber
    ) {
    }

    public record ManagedActor(String publicId, String tenantPublicId, String name, String action) {
    }

    public record DeleteActorResult(String publicId, String tenantPublicId, String action) {
    }

        public record AdminUserView(
            String adminPublicId,
            String tenantPublicId,
            String fullName,
            String name,
            String email,
            String mobileNumber,
            boolean active,
            LocalDateTime createdAt,
            boolean isGeneric
        ) {
        }

        public record AdminUserCollection(String tenantPublicId, List<AdminUserView> admins) {
        }

        public record AdminUserUpsertRequest(
            @NotBlank String fullName,
            String name,
            String email,
            String mobileNumber,
            Boolean active
        ) {
        }
}
