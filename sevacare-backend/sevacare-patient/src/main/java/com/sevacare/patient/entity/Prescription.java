package com.sevacare.patient.entity;

import java.time.LocalDate;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "prescription")
public class Prescription {

    @Id
    @Column(name = "prescription_public_id", nullable = false, length = 16)
    private String prescriptionPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "patient_public_id", nullable = false, length = 16)
    private String patientPublicId;

    @Column(name = "doctor_public_id", nullable = false, length = 16)
    private String doctorPublicId;

    @Column(name = "doctor_name", nullable = false, length = 120)
    private String doctorName;

    @Column(name = "appointment_public_id", length = 16)
    private String appointmentPublicId;

    @Column(name = "issued_on", nullable = false, length = 20)
    private String issuedOn;

    @Column(name = "valid_until")
    private LocalDate validUntil;

    @Column(name = "notes", columnDefinition = "TEXT", length = 2000)
    private String notes;

    @Column(name = "file_url", length = 500)
    private String fileUrl;

    @Column(name = "status", length = 20)
    private String status = "active";

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    public String getPrescriptionPublicId() {
        return prescriptionPublicId;
    }

    public void setPrescriptionPublicId(String prescriptionPublicId) {
        this.prescriptionPublicId = prescriptionPublicId;
    }

    public String getTenantPublicId() {
        return tenantPublicId;
    }

    public void setTenantPublicId(String tenantPublicId) {
        this.tenantPublicId = tenantPublicId;
    }

    public String getPatientPublicId() {
        return patientPublicId;
    }

    public void setPatientPublicId(String patientPublicId) {
        this.patientPublicId = patientPublicId;
    }

    public String getDoctorPublicId() {
        return doctorPublicId;
    }

    public void setDoctorPublicId(String doctorPublicId) {
        this.doctorPublicId = doctorPublicId;
    }

    public String getDoctorName() {
        return doctorName;
    }

    public void setDoctorName(String doctorName) {
        this.doctorName = doctorName;
    }

    public String getAppointmentPublicId() {
        return appointmentPublicId;
    }

    public void setAppointmentPublicId(String appointmentPublicId) {
        this.appointmentPublicId = appointmentPublicId;
    }

    public String getIssuedOn() {
        return issuedOn;
    }

    public void setIssuedOn(String issuedOn) {
        this.issuedOn = issuedOn;
    }

    public LocalDate getValidUntil() {
        return validUntil;
    }

    public void setValidUntil(LocalDate validUntil) {
        this.validUntil = validUntil;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public String getFileUrl() {
        return fileUrl;
    }

    public void setFileUrl(String fileUrl) {
        this.fileUrl = fileUrl;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
