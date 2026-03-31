package com.sevacare.patient.entity;

import java.time.LocalDate;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "medical_history")
public class MedicalHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "patient_public_id", nullable = false, length = 16)
    private String patientPublicId;

    @Column(name = "record_type", length = 50)
    private String recordType;

    @Column(name = "record_value", nullable = false, length = 255)
    private String recordValue;

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    @Column(name = "record_date")
    private LocalDate recordDate;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
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

    public String getRecordType() {
        return recordType;
    }

    public void setRecordType(String recordType) {
        this.recordType = recordType;
    }

    public String getRecordValue() {
        return recordValue;
    }

    public void setRecordValue(String recordValue) {
        this.recordValue = recordValue;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public LocalDate getRecordDate() {
        return recordDate;
    }

    public void setRecordDate(LocalDate recordDate) {
        this.recordDate = recordDate;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
