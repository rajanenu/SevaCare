package com.sevacare.api.controller;

import java.time.LocalDate;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.api.service.MediaService;
import com.sevacare.api.service.ScribeService;
import com.sevacare.doctor.service.DoctorAvailabilityService;
import com.sevacare.doctor.service.DoctorDomainService;
import com.sevacare.doctor.service.SlotBlockService;
import com.sevacare.patient.service.PatientDomainService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.DoctorDtos;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.shared.tenant.TenantContext;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/doctors")
public class DoctorController {

    private final DoctorDomainService doctorDomainService;
    private final PatientDomainService patientDomainService;
    private final SlotBlockService slotBlockService;
    private final DoctorAvailabilityService doctorAvailabilityService;
    private final ScribeService scribeService;
    private final MediaService mediaService;

    public DoctorController(
            DoctorDomainService doctorDomainService,
            PatientDomainService patientDomainService,
            SlotBlockService slotBlockService,
            DoctorAvailabilityService doctorAvailabilityService,
            ScribeService scribeService,
            MediaService mediaService
    ) {
        this.doctorDomainService = doctorDomainService;
        this.patientDomainService = patientDomainService;
        this.slotBlockService = slotBlockService;
        this.doctorAvailabilityService = doctorAvailabilityService;
        this.scribeService = scribeService;
        this.mediaService = mediaService;
    }

    /**
     * Voice scribe: a dictated consult transcript in, a structured prescription
     * draft out — pre-filled into the consultation form for the doctor to review.
     * Nothing is saved or sent by this endpoint; the doctor stays the author.
     */
    @PostMapping("/{tenantPublicId}/scribe")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<ScribeService.ScribeDraft> scribe(
            @PathVariable String tenantPublicId,
            @RequestBody ScribeService.ScribeRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(scribeService.draft(request.transcript(), request.patientContext()));
    }

    @GetMapping("/{tenantPublicId}/{doctorPublicId}/dashboard")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<DoctorDtos.DoctorDashboardView> dashboard(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.dashboard(tenantPublicId, doctorPublicId));
    }

    // Tagged with a version of the queue's actual state (bookings, statuses,
    // completions). The app polls this on a short interval and sends the version
    // back as If-None-Match; an unchanged queue is a 304 with no body, so the
    // board can refresh far more often than the old timer for near-zero cost.
    @GetMapping("/{tenantPublicId}/{doctorPublicId}/queue")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<ContractResponse<PatientDtos.DoctorQueueDayView>> queueByDate(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @RequestParam String date,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        PatientDtos.DoctorQueueDayView view =
                doctorDomainService.queueForDate(tenantPublicId, doctorPublicId, LocalDate.parse(date));
        String etag = "\"" + view.version() + "\"";
        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
        }
        return ResponseEntity.ok().eTag(etag).body(ContractResponse.of(view));
    }

    @PostMapping("/{tenantPublicId}/{doctorPublicId}/patients/{patientPublicId}/disable")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<DoctorDtos.DisablePatientResult> disablePatient(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @PathVariable String patientPublicId,
            @RequestBody(required = false) DoctorDtos.DisablePatientRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.disablePatient(tenantPublicId, patientPublicId, request));
    }

    @GetMapping("/{tenantPublicId}/records")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<DoctorDtos.DoctorCollection> listDoctors(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.listDoctorRecords(tenantPublicId));
    }

    @GetMapping("/{tenantPublicId}/records/{doctorPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<DoctorDtos.DoctorView> getDoctor(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.getDoctorRecord(tenantPublicId, doctorPublicId));
    }

    @PutMapping("/{tenantPublicId}/records/{doctorPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<DoctorDtos.DoctorView> upsertDoctor(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @Valid @RequestBody DoctorDtos.DoctorUpsertRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.upsertDoctorRecord(tenantPublicId, doctorPublicId, request));
    }

    @PostMapping("/{tenantPublicId}/records")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<DoctorDtos.DoctorView> createDoctor(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody DoctorDtos.DoctorUpsertRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.createDoctorRecord(tenantPublicId, request));
    }

    @GetMapping("/{tenantPublicId}/records/next-public-id")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<String> nextDoctorPublicId(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.nextDoctorPublicIdForTenant(tenantPublicId));
    }

    @DeleteMapping("/{tenantPublicId}/records/{doctorPublicId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<String> deleteDoctor(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        doctorDomainService.deleteDoctorRecord(tenantPublicId, doctorPublicId);
        return ContractResponse.of("deleted");
    }

    // Self-service account deletion — disables login only; appointments,
    // prescriptions and history tied to this doctorPublicId are untouched.
    @DeleteMapping("/{tenantPublicId}/{doctorPublicId}/account")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<String> deleteMyAccount(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        doctorDomainService.requestAccountDeletion(tenantPublicId, doctorPublicId);
        return ContractResponse.of("deleted");
    }

    @GetMapping("/{tenantPublicId}/{doctorPublicId}/photo")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.PhotoView> getPhoto(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.getDoctorPhoto(tenantPublicId, doctorPublicId));
    }

    @PutMapping("/{tenantPublicId}/{doctorPublicId}/photo")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<String> updatePhoto(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @RequestBody PatientDtos.PhotoUpdateRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        String mediaSha = mediaService.putBase64(request.photoBase64());
        doctorDomainService.updateDoctorPhoto(tenantPublicId, doctorPublicId, mediaSha);
        return ContractResponse.of("saved");
    }

    // Prescription Upload - Doctors issue prescriptions to patients
    @PostMapping("/{tenantPublicId}/{doctorPublicId}/prescriptions")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.PrescriptionUploadResult> uploadPrescription(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @Valid @RequestBody PatientDtos.PrescriptionUploadRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        if (!doctorPublicId.equals(request.doctorPublicId())) {
            throw new IllegalArgumentException("Doctor mismatch");
        }
        return ContractResponse.of(patientDomainService.uploadPrescription(tenantPublicId, request.patientPublicId(), request));
    }

    // Complete a consultation (marks appointment as completed)
    @PatchMapping("/{tenantPublicId}/{doctorPublicId}/appointments/{appointmentPublicId}/complete")
    @PreAuthorize("hasRole('DOCTOR')")
    public ContractResponse<String> completeAppointment(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @PathVariable String appointmentPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        patientDomainService.completeAppointment(tenantPublicId, doctorPublicId, appointmentPublicId);
        return ContractResponse.of("completed");
    }

    // Doctor's patient list (derived from appointments)
    @GetMapping("/{tenantPublicId}/{doctorPublicId}/patients")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.DoctorPatientCollection> getDoctorPatients(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getDoctorPatients(tenantPublicId, doctorPublicId));
    }

    // ── Slot blocking — partial-day unavailability windows ──────────────────

    @PostMapping("/{tenantPublicId}/{doctorPublicId}/slot-blocks")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<DoctorDtos.SlotBlockView> createSlotBlock(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @Valid @RequestBody DoctorDtos.SlotBlockCreateRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(slotBlockService.createBlock(tenantPublicId, doctorPublicId, request));
    }

    @GetMapping("/{tenantPublicId}/{doctorPublicId}/slot-blocks")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<DoctorDtos.SlotBlockCollection> listSlotBlocks(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(slotBlockService.listBlocks(tenantPublicId, doctorPublicId));
    }

    @DeleteMapping("/{tenantPublicId}/{doctorPublicId}/slot-blocks/{blockPublicId}")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<String> deleteSlotBlock(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @PathVariable String blockPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        slotBlockService.deleteBlock(tenantPublicId, doctorPublicId, blockPublicId);
        return ContractResponse.of("deleted");
    }

    // Availability overview for a date (leave + blocked windows) — used by IP-Staff before booking
    @GetMapping("/{tenantPublicId}/availability")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN','PATIENT')")
    public ContractResponse<DoctorDtos.DoctorAvailabilityCollection> availability(
            @PathVariable String tenantPublicId,
            @RequestParam String date
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(slotBlockService.availabilityForDate(tenantPublicId, date));
    }

    // ── Working hours — doctor-controlled schedule used for real slot generation ──
    // Distinct from the /availability endpoint above (that's a per-date leave+blocks
    // overview); this is the recurring day-scoped schedule a doctor/admin configures.

    @GetMapping("/{tenantPublicId}/{doctorPublicId}/working-hours")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<DoctorDtos.DoctorWorkingHoursView> getWorkingHours(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorAvailabilityService.getWorkingHours(tenantPublicId, doctorPublicId));
    }

    @PutMapping("/{tenantPublicId}/{doctorPublicId}/working-hours")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<DoctorDtos.DoctorWorkingHoursView> updateWorkingHours(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @Valid @RequestBody DoctorDtos.DoctorWorkingHoursUpdateRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorAvailabilityService.replaceWorkingHours(tenantPublicId, doctorPublicId, request));
    }

    // Doctor's prescription history
    @GetMapping("/{tenantPublicId}/{doctorPublicId}/prescriptions/list")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.DoctorPrescriptionCollection> getDoctorPrescriptions(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getDoctorPrescriptions(tenantPublicId, doctorPublicId));
    }
}
