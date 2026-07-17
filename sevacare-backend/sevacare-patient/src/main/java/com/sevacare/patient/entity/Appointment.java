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

    // Intake vitals captured by IP-Staff at booking time (BP, sugar, pulse, …)
    @Column(name = "vitals_summary", length = 1000)
    private String vitalsSummary;

    // SLOT (fixed time grid) or TOKEN (unlimited, doctor-called-in-order) booking
    @Column(name = "booking_type", nullable = false, length = 16)
    private String bookingType = "SLOT";

    // Only set when bookingType == TOKEN — the patient's position in that session's queue
    @Column(name = "token_number")
    private Integer tokenNumber;

    // MORNING or EVENING — only set when bookingType == TOKEN
    @Column(name = "token_session", length = 16)
    private String tokenSession;

    // PATIENT_APP (default), QR_CODE, or IP_STAFF — how this appointment was created
    @Column(name = "booking_source", nullable = false, length = 20)
    private String bookingSource = "PATIENT_APP";

    // Stamped once when the consult completes; consecutive stamps for a doctor's
    // day are the measured consult pace behind queue ETAs.
    @Column(name = "completed_at")
    private java.time.LocalDateTime completedAt;

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

    public String getVitalsSummary() {
        return vitalsSummary;
    }

    public void setVitalsSummary(String vitalsSummary) {
        this.vitalsSummary = vitalsSummary;
    }

    public String getBookingType() {
        return bookingType;
    }

    public void setBookingType(String bookingType) {
        this.bookingType = bookingType;
    }

    public Integer getTokenNumber() {
        return tokenNumber;
    }

    public void setTokenNumber(Integer tokenNumber) {
        this.tokenNumber = tokenNumber;
    }

    public String getTokenSession() {
        return tokenSession;
    }

    public void setTokenSession(String tokenSession) {
        this.tokenSession = tokenSession;
    }

    public String getBookingSource() {
        return bookingSource;
    }

    public void setBookingSource(String bookingSource) {
        this.bookingSource = bookingSource;
    }

    public java.time.LocalDateTime getCompletedAt() {
        return completedAt;
    }

    public void setCompletedAt(java.time.LocalDateTime completedAt) {
        this.completedAt = completedAt;
    }
}
