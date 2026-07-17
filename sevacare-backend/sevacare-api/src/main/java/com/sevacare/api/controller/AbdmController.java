package com.sevacare.api.controller;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.databind.JsonNode;
import com.sevacare.api.service.AbdmService;

/**
 * The ABDM gateway's webhook surface. Tenant-free by design (the gateway knows
 * facilities, not tenants — {@link AbdmService} does the mapping), so the path
 * lives in {@code TenantHeaderFilter}'s skip list and Security's permit list,
 * and the whole prefix rides the public-POST rate-limit bucket.
 *
 * <p>Follows the internal-jobs pattern for exposure: until ABDM credentials are
 * configured, every endpoint answers 404 — an unregistered deployment exposes
 * nothing to probe.
 */
@RestController
@RequestMapping("/api/v1/abdm")
public class AbdmController {

    private final AbdmService abdmService;

    public AbdmController(AbdmService abdmService) {
        this.abdmService = abdmService;
    }

    /**
     * Profile share (Scan &amp; Share). Registered with ABDM as this facility's
     * callback; also reachable at the gateway's documented v0.5 path below.
     */
    @PostMapping({"/share", "/v0.5/patients/profile/share"})
    public ResponseEntity<Map<String, Object>> profileShare(@RequestBody JsonNode payload) {
        if (!abdmService.isConfigured()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        AbdmService.ShareAck ack = abdmService.handleProfileShare(payload);
        return ResponseEntity.ok(Map.of(
                "acknowledgement", Map.of(
                        "status", ack.status(),
                        "healthId", ack.healthId() == null ? "" : ack.healthId(),
                        "tokenNumber", ack.tokenNumber() == null ? "" : ack.tokenNumber()),
                "response", Map.of(
                        "requestId", payload.path("requestId").asText("")),
                "message", ack.message()));
    }

    /** Ops probe: is this deployment ABDM-registered? Reveals nothing else. */
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> status() {
        if (!abdmService.isConfigured()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        return ResponseEntity.ok(Map.of("configured", true));
    }
}
