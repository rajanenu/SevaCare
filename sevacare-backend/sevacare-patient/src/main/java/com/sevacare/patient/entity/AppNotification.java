package com.sevacare.patient.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "app_notification")
public class AppNotification {

    @Id
    @Column(name = "notification_public_id", nullable = false, length = 40)
    private String notificationPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    // patient/doctor/admin public id
    @Column(name = "recipient_id", nullable = false, length = 40)
    private String recipientId;

    // PATIENT | DOCTOR | ADMIN
    @Column(name = "recipient_type", nullable = false, length = 16)
    private String recipientType;

    // LEAVE_REQUEST | LEAVE_APPROVED | LEAVE_DECLINED | APPOINTMENT_REMINDER | PRESCRIPTION_SHARED | ADMIN_MESSAGE
    @Column(name = "notif_type", nullable = false, length = 40)
    private String notifType;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "body", nullable = false, columnDefinition = "TEXT")
    private String body;

    @Column(name = "reference_id", length = 40)
    private String referenceId;

    @Column(name = "is_read", nullable = false)
    private boolean read;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public String getNotificationPublicId() { return notificationPublicId; }
    public void setNotificationPublicId(String v) { this.notificationPublicId = v; }

    public String getTenantPublicId() { return tenantPublicId; }
    public void setTenantPublicId(String v) { this.tenantPublicId = v; }

    public String getRecipientId() { return recipientId; }
    public void setRecipientId(String v) { this.recipientId = v; }

    public String getRecipientType() { return recipientType; }
    public void setRecipientType(String v) { this.recipientType = v; }

    public String getNotifType() { return notifType; }
    public void setNotifType(String v) { this.notifType = v; }

    public String getTitle() { return title; }
    public void setTitle(String v) { this.title = v; }

    public String getBody() { return body; }
    public void setBody(String v) { this.body = v; }

    public String getReferenceId() { return referenceId; }
    public void setReferenceId(String v) { this.referenceId = v; }

    public boolean isRead() { return read; }
    public void setRead(boolean v) { this.read = v; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime v) { this.createdAt = v; }
}
