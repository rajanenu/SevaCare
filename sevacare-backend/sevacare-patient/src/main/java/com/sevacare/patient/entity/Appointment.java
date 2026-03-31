package com.sevacare.patient.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "appointment")
public class Appointment {

    @Id
    @Column(name = "appointment_public_id", nullable = false, length = 16)
    private String appointmentPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "patient_public_id", nullable = false, length = 16)
    private String patientPublicId;

    @Column(name = "doctor_public_id", nullable = false, length = 16)
    private String doctorPublicId;

    @Column(name = "appointment_slot", nullable = false, length = 80)
    private String appointmentSlot;

    @Column(name = "appointment_status", nullable = false, length = 24)
    private String appointmentStatus;

    @Column(name = "notes", nullable = false, length = 300)
    private String notes;

    public String getAppointmentPublicId() {
        return appointmentPublicId;
    }

    public void setAppointmentPublicId(String appointmentPublicId) {
        this.appointmentPublicId = appointmentPublicId;
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

    public String getAppointmentSlot() {
        return appointmentSlot;
    }

    public void setAppointmentSlot(String appointmentSlot) {
        this.appointmentSlot = appointmentSlot;
    }

    public String getAppointmentStatus() {
        return appointmentStatus;
    }

    public void setAppointmentStatus(String appointmentStatus) {
        this.appointmentStatus = appointmentStatus;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }
}
