package com.sevacare.api.controller;

import java.time.LocalDate;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.doctor.service.DoctorDomainService;
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

    public DoctorController(DoctorDomainService doctorDomainService, PatientDomainService patientDomainService) {
        this.doctorDomainService = doctorDomainService;
        this.patientDomainService = patientDomainService;
    }

    @GetMapping("/{tenantPublicId}/{doctorPublicId}/dashboard")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<DoctorDtos.DoctorDashboardView> dashboard(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.dashboard(tenantPublicId, doctorPublicId));
    }

    @GetMapping("/{tenantPublicId}/{doctorPublicId}/queue")
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.DoctorQueueDayView> queueByDate(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @RequestParam String date
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.queueForDate(tenantPublicId, doctorPublicId, LocalDate.parse(date)));
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
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
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
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
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
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<String> nextDoctorPublicId(@PathVariable String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(doctorDomainService.nextDoctorPublicIdForTenant(tenantPublicId));
    }

    @DeleteMapping("/{tenantPublicId}/records/{doctorPublicId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ContractResponse<String> deleteDoctor(@PathVariable String tenantPublicId, @PathVariable String doctorPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        doctorDomainService.deleteDoctorRecord(tenantPublicId, doctorPublicId);
        return ContractResponse.of("deleted");
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
