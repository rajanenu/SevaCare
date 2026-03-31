package com.sevacare.api.controller;

import java.io.IOException;
import java.nio.file.Files;
import java.util.Collections;
import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sevacare.api.service.OnboardingDocumentService;
import com.sevacare.doctor.service.DoctorDomainService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.DiscoveryDtos;
import com.sevacare.shared.dto.DoctorDtos;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.service.ReferenceDataService;
import com.sevacare.tenant.service.TenantRegistryService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/public")
public class DiscoveryController {

    private final TenantRegistryService tenantRegistryService;
    private final DoctorDomainService doctorDomainService;
    private final ReferenceDataService referenceDataService;
    private final OnboardingDocumentService onboardingDocumentService;
    private final ObjectMapper objectMapper;

    public DiscoveryController(
            TenantRegistryService tenantRegistryService,
            DoctorDomainService doctorDomainService,
            ReferenceDataService referenceDataService,
            OnboardingDocumentService onboardingDocumentService,
            ObjectMapper objectMapper
    ) {
        this.tenantRegistryService = tenantRegistryService;
        this.doctorDomainService = doctorDomainService;
        this.referenceDataService = referenceDataService;
        this.onboardingDocumentService = onboardingDocumentService;
        this.objectMapper = objectMapper;
    }

    @GetMapping("/tenants")
    public ContractResponse<DiscoveryDtos.TenantDirectory> listTenants() {
        return ContractResponse.of(new DiscoveryDtos.TenantDirectory(tenantRegistryService.listTenantSummaries()));
    }

    @GetMapping("/tenants/{tenantPublicId}/doctors")
    public ContractResponse<DiscoveryDtos.DoctorDirectory> listDoctors(@PathVariable String tenantPublicId) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        try {
            TenantContext.set(tenantPublicId, schema);
            return ContractResponse.of(doctorDomainService.listDoctors(tenantPublicId));
        } finally {
            TenantContext.clear();
        }
    }

    @GetMapping("/lookups")
    public ContractResponse<DiscoveryDtos.ReferenceLookups> getLookups() {
        return ContractResponse.of(new DiscoveryDtos.ReferenceLookups(
                referenceDataService.listSpecializations(),
                referenceDataService.listCities()
        ));
    }

    @PostMapping("/onboarding/request")
    public ContractResponse<DiscoveryDtos.TenantOnboardingAccepted> submitOnboarding(@Valid @RequestBody DiscoveryDtos.TenantOnboardingRequest request) {
        String requestPublicId = tenantRegistryService.submitOnboardingRequest(
                request.hospitalName(),
                request.licenseNumber(),
                request.state(),
                request.city(),
                request.address(),
                request.country(),
                request.contactName(),
                request.contactMobile(),
                request.contactEmail(),
                request.supportingDocs(),
                request.facilityType()
        );
            return ContractResponse.of(new DiscoveryDtos.TenantOnboardingAccepted(requestPublicId, "submitted", "Onboarding request submitted", Collections.emptyList()));
            }

            @PostMapping(value = "/onboarding/request-multipart", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
            public ContractResponse<DiscoveryDtos.TenantOnboardingAccepted> submitOnboardingMultipart(
                    @RequestPart("payload") String payload,
                @RequestPart(value = "files", required = false) List<MultipartFile> files
            ) {
                DiscoveryDtos.TenantOnboardingRequest request = parseOnboardingPayload(payload);
            String requestPublicId = tenantRegistryService.submitOnboardingRequest(
                request.hospitalName(),
                request.licenseNumber(),
                request.state(),
                request.city(),
                request.address(),
                request.country(),
                request.contactName(),
                request.contactMobile(),
                request.contactEmail(),
                request.supportingDocs(),
                request.facilityType()
            );

            List<DiscoveryDtos.OnboardingDocumentView> documents = onboardingDocumentService.storeDocuments(
                requestPublicId,
                files == null ? Collections.emptyList() : files
            );

            return ContractResponse.of(new DiscoveryDtos.TenantOnboardingAccepted(
                requestPublicId,
                "submitted",
                "Onboarding request submitted",
                documents
            ));
            }

            @GetMapping("/onboarding/request/{requestPublicId}/documents")
            public ContractResponse<List<DiscoveryDtos.OnboardingDocumentView>> listOnboardingDocuments(@PathVariable String requestPublicId) {
            return ContractResponse.of(onboardingDocumentService.listDocuments(requestPublicId));
            }

            @GetMapping("/onboarding/request/{requestPublicId}/documents/{documentPublicId}/download")
            public ResponseEntity<Resource> downloadOnboardingDocument(
                @PathVariable String requestPublicId,
                @PathVariable String documentPublicId
            ) throws IOException {
            OnboardingDocumentService.StoredDocument document = onboardingDocumentService.mustGetDocument(requestPublicId, documentPublicId);
            Resource resource = new UrlResource(document.storagePath().toUri());
            if (!resource.exists() || !resource.isReadable()) {
                throw new IllegalArgumentException("Document not found: " + documentPublicId);
            }

            MediaType mediaType = MediaType.parseMediaType(document.contentType());
            long contentLength = Files.size(document.storagePath());

            return ResponseEntity.ok()
                .contentType(mediaType)
                .contentLength(contentLength)
                .header(
                    HttpHeaders.CONTENT_DISPOSITION,
                    ContentDisposition.attachment().filename(document.originalFileName()).build().toString()
                )
                .body(resource);
    }

    private DiscoveryDtos.TenantOnboardingRequest parseOnboardingPayload(String payload) {
        try {
            return objectMapper.readValue(payload, DiscoveryDtos.TenantOnboardingRequest.class);
        } catch (IOException exception) {
            throw new IllegalArgumentException("Invalid onboarding payload", exception);
        }
    }

    @PostMapping("/tenants/{tenantPublicId}/doctors/register")
    public ContractResponse<DoctorDtos.DoctorOnboardingResult> registerDoctor(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody DoctorDtos.DoctorOnboardingRequest request
    ) {
        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        try {
            TenantContext.set(tenantPublicId, schema);
            return ContractResponse.of(doctorDomainService.registerDoctor(tenantPublicId, request));
        } finally {
            TenantContext.clear();
        }
    }
}
