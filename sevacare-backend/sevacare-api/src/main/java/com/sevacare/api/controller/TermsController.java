package com.sevacare.api.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.TermsDtos;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.terms.TermsService;

/**
 * The terms a hospital or a medical store works under.
 *
 * <p>The document itself is public — a business considering SevaCare can read it
 * before it has a login, and a customer can read it from Help at any time.
 * Accepting is the tenant's own act, so it is authenticated and it is the owner's
 * to make: the admin of a hospital, or the owner of a store.
 */
@RestController
public class TermsController {

    private final TermsService termsService;

    public TermsController(TermsService termsService) {
        this.termsService = termsService;
    }

    /** Readable by anyone, signed in or not. */
    @GetMapping("/api/v1/public/terms")
    public ContractResponse<TermsDtos.TermsDocument> document() {
        return ContractResponse.of(termsService.document());
    }

    /** Has this tenant accepted the version now in force, and if so, who and when. */
    @GetMapping("/api/v1/terms/acceptance")
    public ContractResponse<TermsDtos.TermsAcceptanceView> acceptance() {
        return ContractResponse.of(termsService.acceptance(requireTenant()));
    }

    @PostMapping("/api/v1/terms/accept")
    @PreAuthorize("hasAnyRole('ADMIN', 'STAFF')")
    public ContractResponse<TermsDtos.TermsAcceptanceView> accept(
            @RequestBody(required = false) TermsDtos.TermsAcceptRequest request) {
        String acceptedBy = request == null ? null : request.acceptedBy();
        return ContractResponse.of(termsService.accept(requireTenant(), acceptedBy));
    }

    private String requireTenant() {
        String tenantPublicId = TenantContext.tenantPublicId();
        if (tenantPublicId == null || tenantPublicId.isBlank()) {
            throw new IllegalArgumentException("No tenant on this request");
        }
        return tenantPublicId;
    }
}
