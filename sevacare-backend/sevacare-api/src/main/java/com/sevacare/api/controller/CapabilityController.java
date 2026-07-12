package com.sevacare.api.controller;

import java.util.Set;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.capability.TenantManifest;
import com.sevacare.tenant.capability.TenantModuleService;

/**
 * "What is this tenant?" — asked once, right after login, by every client.
 *
 * <p>The app builds its navigation from the answer rather than from the user's
 * role, which is what makes a medical store's app contain no Doctors tab at all
 * instead of a tab that 404s when tapped. Serving the manifest from the same
 * service the API gate consults means the screen a user sees and the endpoints
 * they can reach can never disagree.
 */
@RestController
@RequestMapping("/api/v1/capabilities")
public class CapabilityController {

    private final TenantModuleService tenantModuleService;

    public CapabilityController(TenantModuleService tenantModuleService) {
        this.tenantModuleService = tenantModuleService;
    }

    public record CapabilityResponse(
            String tenantPublicId,
            String tenantName,
            Set<String> modules,
            String pharmacyProfileKey,
            Set<String> pharmacyFeatures) {
    }

    @GetMapping
    public ResponseEntity<ContractResponse<CapabilityResponse>> current() {
        String tenantPublicId = TenantContext.tenantPublicId();
        if (tenantPublicId == null || tenantPublicId.isBlank()) {
            return ResponseEntity.notFound().build();
        }
        TenantManifest manifest = tenantModuleService.manifestOf(tenantPublicId);
        return ResponseEntity.ok(ContractResponse.of(new CapabilityResponse(
                manifest.tenantPublicId(),
                manifest.tenantName(),
                manifest.enabledModules(),
                manifest.pharmacyProfileKey(),
                manifest.pharmacyFeatures())));
    }
}
