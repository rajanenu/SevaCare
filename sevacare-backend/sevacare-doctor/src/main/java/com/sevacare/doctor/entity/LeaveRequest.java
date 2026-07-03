package com.sevacare.doctor.entity;

import java.time.LocalDate;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "leave_request")
public class LeaveRequest {

    @Id
    @Column(name = "request_public_id", nullable = false, length = 32)
    private String requestPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "doctor_public_id", nullable = false, length = 16)
    private String doctorPublicId;

    @Column(name = "doctor_name", nullable = false, length = 160)
    private String doctorName;

    @Column(name = "leave_type", nullable = false, length = 32)
    private String leaveType;

    @Column(name = "from_date")
    private LocalDate fromDate;

    @Column(name = "to_date")
    private LocalDate toDate;

    @Column(name = "message", columnDefinition = "TEXT")
    private String message;

    // PENDING | APPROVED | DECLINED | AUTO_APPROVED
    @Column(name = "status", nullable = false, length = 24)
    private String status;

    @Column(name = "admin_response", columnDefinition = "TEXT")
    private String adminResponse;

    @Column(name = "submitted_at")
    private LocalDateTime submittedAt;

    @Column(name = "responded_at")
    private LocalDateTime respondedAt;

    @Column(name = "notified_at")
    private LocalDateTime notifiedAt;

    // HH:mm — set only for partial-day (hourly) leave; null = full day
    @Column(name = "start_time", length = 5)
    private String startTime;

    @Column(name = "end_time", length = 5)
    private String endTime;

    // DOCTOR | STAFF — who raised the request (doctorPublicId holds the requester id)
    @Column(name = "requester_type", nullable = false, length = 16)
    private String requesterType = "DOCTOR";

    public String getRequestPublicId() { return requestPublicId; }
    public void setRequestPublicId(String v) { this.requestPublicId = v; }

    public String getTenantPublicId() { return tenantPublicId; }
    public void setTenantPublicId(String v) { this.tenantPublicId = v; }

    public String getDoctorPublicId() { return doctorPublicId; }
    public void setDoctorPublicId(String v) { this.doctorPublicId = v; }

    public String getDoctorName() { return doctorName; }
    public void setDoctorName(String v) { this.doctorName = v; }

    public String getLeaveType() { return leaveType; }
    public void setLeaveType(String v) { this.leaveType = v; }

    public LocalDate getFromDate() { return fromDate; }
    public void setFromDate(LocalDate v) { this.fromDate = v; }

    public LocalDate getToDate() { return toDate; }
    public void setToDate(LocalDate v) { this.toDate = v; }

    public String getMessage() { return message; }
    public void setMessage(String v) { this.message = v; }

    public String getStatus() { return status; }
    public void setStatus(String v) { this.status = v; }

    public String getAdminResponse() { return adminResponse; }
    public void setAdminResponse(String v) { this.adminResponse = v; }

    public LocalDateTime getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(LocalDateTime v) { this.submittedAt = v; }

    public LocalDateTime getRespondedAt() { return respondedAt; }
    public void setRespondedAt(LocalDateTime v) { this.respondedAt = v; }

    public LocalDateTime getNotifiedAt() { return notifiedAt; }
    public void setNotifiedAt(LocalDateTime v) { this.notifiedAt = v; }

    public String getStartTime() { return startTime; }
    public void setStartTime(String v) { this.startTime = v; }

    public String getEndTime() { return endTime; }
    public void setEndTime(String v) { this.endTime = v; }

    public String getRequesterType() { return requesterType; }
    public void setRequesterType(String v) { this.requesterType = v; }
}
