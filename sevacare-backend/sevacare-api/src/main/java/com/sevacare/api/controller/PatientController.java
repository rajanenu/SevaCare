package com.sevacare.api.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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

    public PatientController(PatientDomainService patientDomainService, ReferenceDataService referenceDataService) {
        this.patientDomainService = patientDomainService;
        this.referenceDataService = referenceDataService;
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

    @PostMapping("/{tenantPublicId}/{patientPublicId}/appointments")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.AppointmentBookingResult> bookAppointment(
            @PathVariable String tenantPublicId,
            @PathVariable String patientPublicId,
            @Valid @RequestBody PatientDtos.AppointmentBookingRequest request
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.bookAppointment(tenantPublicId, patientPublicId, request));
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
