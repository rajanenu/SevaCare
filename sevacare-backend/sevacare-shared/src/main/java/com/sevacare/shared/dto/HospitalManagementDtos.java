package com.sevacare.shared.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public final class HospitalManagementDtos {

    private HospitalManagementDtos() {
    }

    // ==================== Hospital Admin Enrollment ====================
    public record HospitalAdminEnrollRequest(
            @NotBlank String hospitalAdminMobile,
            String hospitalAdminName,
            @NotNull Boolean active
    ) {
    }

    public record HospitalAdminEnrollView(
            String adminEnrollmentPublicId,
            String tenantPublicId,
            String hospitalAdminMobile,
            String hospitalAdminName,
            boolean active,
            LocalDateTime enrolledAt
    ) {
    }

    public record HospitalAdminEnrollCollection(
            String tenantPublicId,
            List<HospitalAdminEnrollView> admins
    ) {
    }

    // ==================== Doctor Enrollment ====================
    public record DoctorEnrollRequest(
            @NotBlank String doctorMobile,
            @NotBlank String doctorName,
            @NotBlank String specialty,
            @NotNull Boolean active
    ) {
    }

    public record DoctorEnrollView(
            String doctorEnrollmentPublicId,
            String tenantPublicId,
            String doctorMobile,
            String doctorName,
            String specialty,
            boolean active,
            LocalDateTime enrolledAt
    ) {
    }

    public record DoctorEnrollCollection(
            String tenantPublicId,
            List<DoctorEnrollView> doctors
    ) {
    }

    // ==================== Hospital QR Code ====================
    public record HospitalQRCodeView(
            String qrcodePublicId,
            String tenantPublicId,
            String qrcodeUuid,
            String qrcodeUrl,
            LocalDateTime createdAt
    ) {
    }

    public record HospitalQRCodeGenerateResponse(
            String qrcodePublicId,
            String tenantPublicId,
            String qrcodeUuid
    ) {
    }

    // ==================== Appointment Request (QR-based flow) ====================
    public record AppointmentRequestSubmitRequest(
            @NotBlank String patientName,
            @Min(1) int patientAge,
            @NotBlank String symptoms,
            @NotBlank String doctorPublicId,
            @NotBlank String specialty,
            @NotNull LocalDate preferredDate
    ) {
    }

    public record AppointmentRequestView(
            String requestPublicId,
            String patientMobile,
            String patientName,
            int patientAge,
            String symptoms,
            String doctorPublicId,
            String specialty,
            LocalDate preferredDate,
            String requestStatus,
            String assignedSlot,
            String notes,
            LocalDateTime createdAt,
            LocalDateTime updatedAt
    ) {
    }

    public record AppointmentRequestCollection(
            String tenantPublicId,
            String doctorPublicId,
            List<AppointmentRequestView> requests
    ) {
    }

    public record AppointmentRequestConfirmRequest(
            @NotBlank String assignedSlot,
            String notes
    ) {
    }

    public record AppointmentRequestConfirmResponse(
            String requestPublicId,
            String appointmentPublicId,
            String requestStatus,
            String assignedSlot,
            LocalDateTime updatedAt
    ) {
    }

    // ==================== QR Code Pre-filled Form Data ====================
    public record QRCodeFormDataRequest(
            @NotBlank String qrcodeUuid
    ) {
    }

    public record QRCodeFormDataResponse(
            String tenantPublicId,
            String tenantName,
            List<DoctorOption> availableDoctors
    ) {
        public record DoctorOption(
                String doctorPublicId,
                String doctorName,
                String specialty
        ) {
        }
    }
}
