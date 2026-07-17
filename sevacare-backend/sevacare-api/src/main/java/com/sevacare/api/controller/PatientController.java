package com.sevacare.api.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.api.service.IdempotencyService;
import com.sevacare.doctor.service.DoctorAvailabilityService;
import com.sevacare.patient.service.PatientDomainService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.service.ReferenceDataService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {

    private final PatientDomainService patientDomainService;
    private final ReferenceDataService referenceDataService;
    private final DoctorAvailabilityService doctorAvailabilityService;
    private final IdempotencyService idempotencyService;

    public PatientController(
            PatientDomainService patientDomainService,
            ReferenceDataService referenceDataService,
            DoctorAvailabilityService doctorAvailabilityService,
            IdempotencyService idempotencyService
    ) {
        this.patientDomainService = patientDomainService;
        this.referenceDataService = referenceDataService;
        this.doctorAvailabilityService = doctorAvailabilityService;
        this.idempotencyService = idempotencyService;
    }

    @GetMapping("/{tenantPublicId}/{patientPublicId}/home")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.PatientHomeView> home(@PathVariable String tenantPublicId, @PathVariable String patientPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.home(tenantPublicId, patientPublicId));
    }

    @GetMapping("/{tenantPublicId}/{patientPublicId}/booking/setup")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.BookingSetupView> bookingSetup(@PathVariable String tenantPublicId, @PathVariable String patientPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        List<String> specialties = referenceDataService.listSpecializations();
        return ContractResponse.of(patientDomainService.bookingSetup(tenantPublicId, specialties));
    }

    @GetMapping("/{tenantPublicId}/booking/booked-slots")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<List<String>> bookedSlots(
            @PathVariable String tenantPublicId,
            @RequestParam String doctorId,
            @RequestParam String date
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getBookedSlots(tenantPublicId, doctorId, date));
    }

    // This doctor's actual bookable morning/evening windows for one date, derived
    // from their own working-hours rules (see DoctorController.getWorkingHours) —
    // replaces the tenant-wide morningSlots/eveningSlots from booking/setup once a
    // specific doctor is selected.
    @GetMapping("/{tenantPublicId}/booking/doctor-slots")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.DoctorSlotsView> doctorSlots(
            @PathVariable String tenantPublicId,
            @RequestParam String doctorId,
            @RequestParam String date
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorAvailabilityService.slotsForDate(tenantPublicId, doctorId, date));
    }

    // Per-date availability flags for the booking screen's date strip — one call
    // for the whole strip instead of one doctor-slots call per date.
    @GetMapping("/{tenantPublicId}/booking/doctor-available-dates")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.DoctorAvailableDatesView> doctorAvailableDates(
            @PathVariable String tenantPublicId,
            @RequestParam String doctorId,
            @RequestParam String from,
            @RequestParam(defaultValue = "15") int days
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorAvailabilityService.availableDates(tenantPublicId, doctorId, from, days));
    }

    // Richer availability: booked + doctor-blocked windows + leave status in one call
    @GetMapping("/{tenantPublicId}/booking/slot-status")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.SlotStatusView> slotStatus(
            @PathVariable String tenantPublicId,
            @RequestParam String doctorId,
            @RequestParam String date
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getSlotStatus(tenantPublicId, doctorId, date));
    }

    // Read-only peek at the next token number for a doctor/date/session — does not reserve it
    @GetMapping("/{tenantPublicId}/booking/token-preview")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.TokenPreviewView> tokenPreview(
            @PathVariable String tenantPublicId,
            @RequestParam String doctorId,
            @RequestParam String date,
            @RequestParam String session
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.tokenPreview(tenantPublicId, doctorId, date, session));
    }

    // IP-Staff/Admin resets a doctor's token counter for a given date/session back to zero
    @PostMapping("/{tenantPublicId}/booking/token-reset")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<String> resetTokenCounter(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody PatientDtos.TokenResetRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId()) || !tenantPublicId.equals(request.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        patientDomainService.resetTokenCounter(tenantPublicId, request.doctorPublicId(), request.date(), request.session());
        return ContractResponse.of("reset");
    }

    @PostMapping("/{tenantPublicId}/{patientPublicId}/appointments")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.AppointmentBookingResult> bookAppointment(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
            @Valid @RequestBody PatientDtos.AppointmentBookingRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        // A booking retried on a flaky network must not become two tokens in the
        // queue — the key makes the retry return the first booking's result.
        return ContractResponse.of(idempotencyService.execute(
                tenantPublicId, idempotencyKey, "book-appointment",
                PatientDtos.AppointmentBookingResult.class,
                () -> patientDomainService.bookAppointment(tenantPublicId, patientPublicId, request)));
    }

    @GetMapping("/{tenantPublicId}/records")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<PatientDtos.PatientCollection> listPatients(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.listPatientRecords(tenantPublicId));
    }

    @GetMapping("/{tenantPublicId}/records/{patientPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR','PATIENT')")
    public ContractResponse<PatientDtos.PatientView> getPatient(@PathVariable String tenantPublicId, @PathVariable String patientPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getPatientRecord(tenantPublicId, patientPublicId));
    }

    @PutMapping("/{tenantPublicId}/records/{patientPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR','PATIENT')")
    public ContractResponse<PatientDtos.PatientView> upsertPatient(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @Valid @RequestBody PatientDtos.PatientUpsertRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.upsertPatientRecord(tenantPublicId, patientPublicId, request));
    }

    @DeleteMapping("/{tenantPublicId}/records/{patientPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<String> deletePatient(@PathVariable String tenantPublicId, @PathVariable String patientPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        patientDomainService.deletePatientRecord(tenantPublicId, patientPublicId);
        return ContractResponse.of("deleted");
    }

    @GetMapping("/{tenantPublicId}/appointments")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<PatientDtos.AppointmentCollection> listAppointments(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.listAppointmentRecords(tenantPublicId));
    }

    @GetMapping("/{tenantPublicId}/appointments/{appointmentPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR','PATIENT')")
    public ContractResponse<PatientDtos.AppointmentEntityView> getAppointment(@PathVariable String tenantPublicId, @PathVariable String appointmentPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getAppointmentRecord(tenantPublicId, appointmentPublicId));
    }

    @PutMapping("/{tenantPublicId}/appointments/{appointmentPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<PatientDtos.AppointmentEntityView> upsertAppointment(
            @PathVariable String tenantPublicId,
            @PathVariable String appointmentPublicId,
            @Valid @RequestBody PatientDtos.AppointmentUpsertRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.upsertAppointmentRecord(tenantPublicId, appointmentPublicId, request));
    }

    @DeleteMapping("/{tenantPublicId}/appointments/{appointmentPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<String> deleteAppointment(@PathVariable String tenantPublicId, @PathVariable String appointmentPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        patientDomainService.deleteAppointmentRecord(tenantPublicId, appointmentPublicId);
        return ContractResponse.of("deleted");
    }

    // Cancel appointment (soft delete - status change)
    @PutMapping("/{tenantPublicId}/{patientPublicId}/appointments/{appointmentPublicId}/cancel")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.AppointmentActionResult> cancelAppointment(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @PathVariable String appointmentPublicId,
            @RequestBody(required = false) PatientDtos.AppointmentCancelRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.cancelAppointment(tenantPublicId, patientPublicId, appointmentPublicId, request));
    }

    // Reschedule appointment
    @PutMapping("/{tenantPublicId}/{patientPublicId}/appointments/{appointmentPublicId}/reschedule")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.AppointmentActionResult> rescheduleAppointment(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @PathVariable String appointmentPublicId,
            @Valid @RequestBody PatientDtos.AppointmentRescheduleRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.rescheduleAppointment(tenantPublicId, patientPublicId, appointmentPublicId, request));
    }

    // Delete appointment for patient (cancels first, then deletes record)
    @DeleteMapping("/{tenantPublicId}/{patientPublicId}/appointments/{appointmentPublicId}")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.AppointmentActionResult> deleteAppointmentForPatient(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @PathVariable String appointmentPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.deleteAppointmentForPatient(tenantPublicId, patientPublicId, appointmentPublicId));
    }

    // Self-service account deletion — disables login only; appointments,
    // prescriptions and history tied to this patientPublicId are untouched.
    @DeleteMapping("/{tenantPublicId}/{patientPublicId}/account")
    @PreAuthorize("hasAnyRole('PATIENT','ADMIN')")
    public ContractResponse<String> deleteMyAccount(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        patientDomainService.requestAccountDeletion(tenantPublicId, patientPublicId);
        return ContractResponse.of("deleted");
    }

    @GetMapping("/{tenantPublicId}/{patientPublicId}/photo")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.PhotoView> getPhoto(@PathVariable String tenantPublicId, @PathVariable String patientPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getPatientPhoto(tenantPublicId, patientPublicId));
    }

    @PutMapping("/{tenantPublicId}/{patientPublicId}/photo")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<String> updatePhoto(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @RequestBody PatientDtos.PhotoUpdateRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        patientDomainService.updatePatientPhoto(tenantPublicId, patientPublicId, request.photoBase64());
        return ContractResponse.of("saved");
    }

    // Prescription Endpoints (patient-scoped)
    @GetMapping("/{tenantPublicId}/{patientPublicId}/prescriptions")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.PatientPrescriptionsWrapper> getPatientPrescriptions(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getPatientPrescriptions(tenantPublicId, patientPublicId));
    }

    // Patient submits a 5-star rating (+ optional comment) for a completed appointment
    @PostMapping("/{tenantPublicId}/{patientPublicId}/appointments/{appointmentPublicId}/review")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.ReviewSubmitResult> submitReview(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @PathVariable String appointmentPublicId,
            @Valid @RequestBody PatientDtos.ReviewSubmitRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.submitReview(tenantPublicId, patientPublicId, appointmentPublicId, request));
    }

    // Live queue position for a patient's own TOKEN appointment — powers the "your turn is near" banner
    @GetMapping("/{tenantPublicId}/{patientPublicId}/appointments/{appointmentPublicId}/queue-status")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.QueueStatusView> getQueueStatus(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @PathVariable String appointmentPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getQueueStatus(tenantPublicId, patientPublicId, appointmentPublicId));
    }

    // A single patient-uploaded attachment's bytes, fetched on demand. The doctor's
    // day queue ships attachment metadata only (no base64), so this is the one call
    // that pulls the image — made once, when the doctor actually opens it.
    @GetMapping("/{tenantPublicId}/attachments/{attachmentPublicId}")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.AttachmentView> getAttachment(
            @PathVariable String tenantPublicId,
            @PathVariable String attachmentPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getAppointmentAttachment(tenantPublicId, attachmentPublicId));
    }

    @GetMapping("/{tenantPublicId}/{patientPublicId}/medical-history")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.MedicalHistoryView> getMedicalHistory(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getPatientMedicalHistory(tenantPublicId, patientPublicId));
    }
}
