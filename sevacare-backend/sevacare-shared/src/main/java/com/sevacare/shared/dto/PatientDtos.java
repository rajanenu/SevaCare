package com.sevacare.shared.dto;

import java.util.List;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public final class PatientDtos {

    private PatientDtos() {
    }

    public record AppointmentView(String appointmentPublicId, String doctorPublicId, String doctorName, String slot, String status, String note) {
    }

    public record PrescriptionView(String prescriptionPublicId, String doctorPublicId, String doctorName, String issuedOn, List<String> lines) {
    }

    public record PatientHomeView(String patientPublicId, String tenantPublicId, List<AppointmentView> appointments, List<PrescriptionView> prescriptions) {
    }

        public record BookingSetupView(String tenantPublicId, int slotIntervalMinutes, List<String> specialties, List<String> availableDates, List<String> morningSlots, List<String> eveningSlots) {
        }

        public record AppointmentBookingRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String patientPublicId,
            @NotBlank String patientName,
            @NotBlank String gender,
            @Min(0) int age,
            @NotBlank String mobileNumber,
            @NotBlank String address,
            @NotBlank String specialty,
            @NotBlank String doctorPublicId,
            @NotBlank String slot
        ) {
        }

        public record AppointmentBookingResult(
            String appointmentPublicId,
            String tenantPublicId,
            String doctorPublicId,
            String patientPublicId,
            String slot,
            String status
        ) {
        }

            public record PatientUpsertRequest(
                @NotBlank String fullName,
                @NotBlank String mobileNumber,
                @NotBlank String status,
                String email,
                String gender,
                Integer age,
                String address
            ) {
            }

            public record PatientView(
                String patientPublicId,
                String tenantPublicId,
                String fullName,
                String mobileNumber,
                String status,
                String email,
                String gender,
                Integer age,
                String address
            ) {
            }

            public record PatientCollection(String tenantPublicId, List<PatientView> patients) {
            }

            public record AppointmentUpsertRequest(
                @NotBlank String patientPublicId,
                @NotBlank String doctorPublicId,
                @NotBlank String slot,
                @NotBlank String status,
                @NotBlank String note
            ) {
            }

            public record AppointmentEntityView(
                String appointmentPublicId,
                String patientPublicId,
                String doctorPublicId,
                String slot,
                String status,
                String note
            ) {
            }

            public record AppointmentCollection(String tenantPublicId, List<AppointmentEntityView> appointments) {
            }

            // Prescription DTOs
            public record MedicineView(
                String medicineName,
                String strength,
                String frequency,
                String duration,
                String instructions
            ) {
            }

            public record PrescriptionDetailView(
                String prescriptionPublicId,
                String doctorPublicId,
                String doctorName,
                String issuedOn,
                String validUntil,
                String notes,
                String status,
                List<MedicineView> medicines
            ) {
            }

            public record PatientPrescriptionsWrapper(
                String tenantPublicId,
                String patientPublicId,
                List<PrescriptionDetailView> prescriptions
            ) {
            }

            public record MedicineUploadRequest(
                @NotBlank String medicineName,
                String strength,
                @NotBlank String frequency,
                String duration,
                String instructions
            ) {
            }

            public record PrescriptionUploadRequest(
                @NotBlank String patientPublicId,
                @NotBlank String doctorPublicId,
                @NotBlank String doctorName,
                List<MedicineUploadRequest> medicines,
                String notes
            ) {
            }

            public record PrescriptionUploadResult(
                String prescriptionPublicId,
                String patientPublicId,
                String doctorPublicId,
                String issuedOn,
                int medicineCount,
                String status
            ) {
            }

            // Medical History DTOs
            public record MedicalHistoryRecordView(
                String recordType,
                String recordValue,
                String notes,
                String recordDate
            ) {
            }

            public record MedicalHistoryView(
                String patientPublicId,
                List<MedicalHistoryRecordView> allergies,
                List<MedicalHistoryRecordView> conditions,
                List<MedicalHistoryRecordView> records,
                List<MedicalHistoryRecordView> followUps,
                List<AppointmentEntityView> appointments,
                List<PrescriptionDetailView> prescriptions
            ) {
            }

            // Doctor-scoped views
            public record DoctorPatientView(
                String patientPublicId,
                String fullName,
                String mobileNumber,
                String status,
                String lastAppointmentSlot
            ) {
            }

            public record DoctorPatientCollection(
                String tenantPublicId,
                String doctorPublicId,
                List<DoctorPatientView> patients
            ) {
            }

            public record DoctorPrescriptionCollection(
                String tenantPublicId,
                String doctorPublicId,
                List<PrescriptionDetailView> prescriptions
            ) {
            }

            // Appointment cancel/reschedule
            public record AppointmentCancelRequest(
                String reason
            ) {
            }

            public record AppointmentRescheduleRequest(
                @NotBlank String newSlot
            ) {
            }

            public record AppointmentActionResult(
                String appointmentPublicId,
                String status,
                String message
            ) {
            }

            public record DoctorQueueFacetView(
                String appointmentPublicId,
                String patientPublicId,
                String patientName,
                String slot,
                String status,
                boolean followUp,
                String symptoms,
                String diagnosis,
                List<MedicineView> medicines,
                String rxNotes
            ) {
            }

            public record DoctorQueueDayView(
                String tenantPublicId,
                String doctorPublicId,
                String date,
                int totalAppointments,
                int pendingNotes,
                int avgConsultMinutes,
                List<DoctorQueueFacetView> facets
            ) {
            }
}
