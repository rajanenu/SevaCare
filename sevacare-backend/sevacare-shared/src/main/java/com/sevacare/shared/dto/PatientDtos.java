package com.sevacare.shared.dto;

import java.util.List;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public final class PatientDtos {

    private PatientDtos() {
    }

    public record AppointmentView(String appointmentPublicId, String doctorPublicId, String doctorName, String slot, String status, String note,
            String bookingType, Integer tokenNumber, String tokenSession) {
    }

    public record PrescriptionView(String prescriptionPublicId, String doctorPublicId, String doctorName, String issuedOn, List<String> lines) {
    }

    public record PatientHomeView(String patientPublicId, String tenantPublicId, List<AppointmentView> appointments, List<PrescriptionView> prescriptions) {
    }

        public record BookingSetupView(String tenantPublicId, int slotIntervalMinutes, List<String> specialties, List<String> availableDates, List<String> morningSlots, List<String> eveningSlots) {
        }

        // Per-doctor slot windows derived from that doctor's own working-hours rules
        // (see DoctorDtos.DoctorWorkingHoursView) for one date, replacing the generic
        // tenant-wide morningSlots/eveningSlots above once a specific doctor is picked.
        public record DoctorDateAvailability(String date, boolean available) {
        }

        /** Per-date availability flags over a date span — powers the booking date strip. */
        public record DoctorAvailableDatesView(String tenantPublicId, String doctorPublicId, List<DoctorDateAvailability> dates) {
        }

        public record DoctorSlotsView(String tenantPublicId, String doctorPublicId, String date, List<String> morningSlots, List<String> eveningSlots) {
        }

        public record AppointmentBookingRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String patientPublicId,
            @NotBlank String patientName,
            @NotBlank String gender,
            @Min(0) int age,
            @NotBlank String mobileNumber,
            String address,
            @NotBlank String specialty,
            @NotBlank String doctorPublicId,
            // "yyyy-MM-dd HH:mm" when bookingType is SLOT, or just "yyyy-MM-dd" when bookingType is TOKEN.
            @NotBlank String slot,
            // "SLOT" (default, fixed time grid) or "TOKEN" (unlimited, queue-order). Null treated as SLOT.
            String bookingType,
            // Required when bookingType is TOKEN: "MORNING" or "EVENING".
            String tokenSession,
            String note,
            String vitals,
            List<AttachmentUploadRequest> attachments,
            // "PATIENT_APP" (default when blank), "QR_CODE", or "IP_STAFF" — how this booking was created.
            String bookingSource
        ) {
        }

        public record AttachmentUploadRequest(
            @NotBlank String fileName,
            @NotBlank String mimeType,
            @NotBlank String dataBase64
        ) {
        }

        public record AttachmentView(
            String attachmentPublicId,
            String fileName,
            String mimeType,
            String dataBase64,
            String uploadedBy
        ) {
        }

        public record AppointmentBookingResult(
            String appointmentPublicId,
            String tenantPublicId,
            String doctorPublicId,
            String patientPublicId,
            String slot,
            String status,
            String bookingType,
            Integer tokenNumber,
            String tokenSession
        ) {
        }

        /** Read-only peek at the next token number that would be issued — does not reserve it. */
        public record TokenPreviewView(
            String doctorPublicId,
            String date,
            String session,
            int nextTokenNumber
        ) {
        }

        public record TokenResetRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String doctorPublicId,
            @NotBlank String date,
            @NotBlank String session
        ) {
        }

        /** Per-doctor per-date slot availability: booked by others, blocked by the doctor, or fully on leave. */
        public record SlotStatusView(
            String doctorPublicId,
            String date,
            List<String> bookedSlots,
            List<String> blockedSlots,
            boolean doctorOnLeave
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
                String note,
                String bookingType,
                Integer tokenNumber,
                String tokenSession
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
                String doctorSpecialty,
                String patientPublicId,
                String patientName,
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
                String notes,
                // When set, a follow_up medical-history record is created for
                // today + this many days.
                Integer followUpDays,
                // The doctor's per-consult choice to WhatsApp the prescription (and
                // schedule the follow-up reminder). Absent means opted in.
                Boolean sendWhatsapp
            ) {
            }

            public record PrescriptionUploadResult(
                String prescriptionPublicId,
                String patientPublicId,
                String doctorPublicId,
                String issuedOn,
                int medicineCount,
                String status,
                // True when the prescription was queued for WhatsApp delivery.
                boolean whatsappQueued
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
                String rxNotes,
                String vitals,
                List<AttachmentView> attachments,
                String bookingType,
                Integer tokenNumber,
                String tokenSession,
                String bookingSource
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

            /** Patient's rating + optional comment for a completed appointment. One per appointment. */
            public record ReviewSubmitRequest(
                @jakarta.validation.constraints.Min(1) @jakarta.validation.constraints.Max(5) int rating,
                String comment
            ) {
            }

            public record ReviewSubmitResult(
                String appointmentPublicId,
                String doctorPublicId,
                int rating,
                String comment
            ) {
            }

            /** Live queue position for a patient's own TOKEN-type appointment, for in-app "your turn is near" alerts. */
            public record QueueStatusView(
                String doctorPublicId,
                String date,
                String tokenSession,
                Integer yourToken,
                Integer nowServingToken,
                int tokensAhead,
                int estimatedWaitMinutes,
                boolean alreadyServed
            ) {
            }

            /** Profile photo — base64 payload, null when none uploaded. */
            public record PhotoView(String photoBase64) {
            }

            public record PhotoUpdateRequest(String photoBase64) {
            }
}
