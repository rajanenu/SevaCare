package com.sevacare.shared.dto;

import java.util.List;

import jakarta.validation.constraints.NotBlank;

public final class NotificationDtos {

    private NotificationDtos() {}

    // ── Leave Request DTOs ────────────────────────────────────────────────────

    public record LeaveRequestView(
            String requestPublicId,
            String tenantPublicId,
            String doctorPublicId,
            String doctorName,
            String leaveType,
            String fromDate,
            String toDate,
            String message,
            String status,
            String adminResponse,
            String submittedAt,
            String respondedAt
    ) {}

    public record LeaveRequestCollection(
            String tenantPublicId,
            List<LeaveRequestView> requests
    ) {}

    public record LeaveRequestCreateRequest(
            @NotBlank String leaveType,
            String fromDate,
            String toDate,
            String message
    ) {}

    public record LeaveRequestActionRequest(
            @NotBlank String action,  // APPROVE | DECLINE | COMMENT
            String response
    ) {}

    // ── Notification DTOs ─────────────────────────────────────────────────────

    public record NotificationView(
            String notificationPublicId,
            String recipientId,
            String recipientType,
            String notifType,
            String title,
            String body,
            String referenceId,
            boolean read,
            String createdAt
    ) {}

    public record NotificationCollection(
            String tenantPublicId,
            List<NotificationView> notifications,
            long unreadCount
    ) {}

    public record MarkReadRequest(String notificationPublicId) {}

    // ── Admin Message DTOs ────────────────────────────────────────────────────

    public record AdminMessageRequest(
            @NotBlank String title,
            @NotBlank String body,
            // ALL | DEPARTMENT | INDIVIDUAL
            @NotBlank String targetType,
            // required when targetType = INDIVIDUAL
            String targetDoctorId,
            // required when targetType = DEPARTMENT
            String targetSpecialty
    ) {}
}
