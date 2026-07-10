package com.sevacare.api.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.doctor.repository.DoctorRepository;
import com.sevacare.patient.service.NotificationDomainService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.NotificationDtos;
import com.sevacare.shared.tenant.TenantContext;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class NotificationController {

    private final NotificationDomainService notificationService;
    private final DoctorRepository doctorRepository;

    public NotificationController(
            NotificationDomainService notificationService,
            DoctorRepository doctorRepository
    ) {
        this.notificationService = notificationService;
        this.doctorRepository = doctorRepository;
    }

    @GetMapping("/{tenantPublicId}/notifications")
    @PreAuthorize("isAuthenticated()")
    public ContractResponse<NotificationDtos.NotificationCollection> list(
            @PathVariable String tenantPublicId,
            @RequestParam String recipientId,
            @RequestParam String recipientType
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(notificationService.listForRecipient(tenantPublicId, recipientId, recipientType));
    }

    @PostMapping("/{tenantPublicId}/notifications/{notificationPublicId}/read")
    @PreAuthorize("isAuthenticated()")
    public ContractResponse<String> markRead(
            @PathVariable String tenantPublicId,
            @PathVariable String notificationPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        notificationService.markRead(tenantPublicId, notificationPublicId);
        return ContractResponse.of("read");
    }

    @PostMapping("/{tenantPublicId}/notifications/read-all")
    @PreAuthorize("isAuthenticated()")
    public ContractResponse<String> markAllRead(
            @PathVariable String tenantPublicId,
            @RequestParam String recipientId,
            @RequestParam String recipientType
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        notificationService.markAllRead(tenantPublicId, recipientId, recipientType);
        return ContractResponse.of("all-read");
    }

    // Admin sends a message — ALL | DEPARTMENT | INDIVIDUAL
    @PostMapping("/{tenantPublicId}/admin/messages")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<String> sendAdminMessage(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody NotificationDtos.AdminMessageRequest body
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        if (body.targetType() == null || body.targetType().isBlank()) {
            throw new IllegalArgumentException("targetType is required");
        }

        switch (body.targetType().trim().toUpperCase()) {
            case "ALL" -> doctorRepository
                    .findByTenantPublicIdAndActiveTrueOrderByDoctorPublicIdAsc(tenantPublicId)
                    .forEach(doc -> notificationService.createNotification(
                            tenantPublicId, doc.getDoctorPublicId(), "DOCTOR",
                            "ADMIN_MESSAGE", body.title(), body.body(), null));

            case "DEPARTMENT" -> {
                String specialty = body.targetSpecialty();
                if (specialty == null || specialty.isBlank()) {
                    throw new IllegalArgumentException("targetSpecialty is required for DEPARTMENT messages");
                }
                doctorRepository
                        .findByTenantPublicIdAndSpecialtyAndActiveTrueOrderByDoctorPublicIdAsc(tenantPublicId, specialty)
                        .forEach(doc -> notificationService.createNotification(
                                tenantPublicId, doc.getDoctorPublicId(), "DOCTOR",
                                "ADMIN_MESSAGE", body.title(), body.body(), null));
            }

            case "INDIVIDUAL" -> {
                String targetId = body.targetDoctorId();
                if (targetId == null || targetId.isBlank()) {
                    throw new IllegalArgumentException("targetDoctorId is required for INDIVIDUAL messages");
                }
                notificationService.createNotification(
                        tenantPublicId, targetId, "DOCTOR",
                        "ADMIN_MESSAGE", body.title(), body.body(), null);
            }

            default -> throw new IllegalArgumentException("Unknown targetType: " + body.targetType());
        }
        return ContractResponse.of("sent");
    }
}
