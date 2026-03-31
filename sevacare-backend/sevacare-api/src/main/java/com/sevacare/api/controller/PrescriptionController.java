package com.sevacare.api.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.patient.service.PatientDomainService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.shared.tenant.TenantContext;

@RestController
@RequestMapping("/api/v1/prescriptions")
public class PrescriptionController {

    private final PatientDomainService patientDomainService;

    public PrescriptionController(PatientDomainService patientDomainService) {
        this.patientDomainService = patientDomainService;
    }

    @GetMapping("/{tenantPublicId}/{prescriptionPublicId}/detail")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<PatientDtos.PrescriptionDetailView> getPrescriptionDetail(
            @PathVariable String tenantPublicId,
            @PathVariable String prescriptionPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.getPrescriptionDetail(tenantPublicId, prescriptionPublicId));
    }

    @GetMapping("/{tenantPublicId}/{prescriptionPublicId}/download")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR','ADMIN')")
    public ContractResponse<String> downloadPrescription(
            @PathVariable String tenantPublicId,
            @PathVariable String prescriptionPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(patientDomainService.downloadPrescription(tenantPublicId, prescriptionPublicId));
    }
}
