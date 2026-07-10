package com.sevacare.pharmacy.capability.service;

import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sevacare.pharmacy.capability.spi.CapabilityPolicies;
import com.sevacare.pharmacy.capability.spi.PolicyKey;
import com.sevacare.pharmacy.capability.spi.PolicyMode;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.capability.TenantModuleService;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Resolves the three-layer policy chain of blueprint §10.1.
 *
 * <p><b>Deliberately uncached.</b> The blueprint calls for a per-tenant cache
 * invalidated by a {@code pharmacy.config.changed} event, and that will be right
 * eventually — but on Cloud Run a cache without that event means instance B
 * enforces a rule instance A was told to relax, and the bug it produces is
 * "sometimes the sale is blocked", which is the worst kind. Two indexed reads on
 * the sale path (once per sale, not once per line) cost less than that. The
 * cache lands when the invalidation event does.
 */
@Service
public class CapabilityPolicyService implements CapabilityPolicies {

    private static final Logger log = LoggerFactory.getLogger(CapabilityPolicyService.class);

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final TenantModuleService tenantModuleService;

    public CapabilityPolicyService(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper,
                                   TenantModuleService tenantModuleService) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
        this.tenantModuleService = tenantModuleService;
    }

    @Override
    @Transactional(readOnly = true)
    public PolicyMode modeOf(PolicyKey key) {
        PolicyMode tenantOverride = accept(key, tenantOverride(key));
        if (tenantOverride != null) {
            return tenantOverride;
        }
        PolicyMode profileDefault = accept(key, profileDefault(key));
        if (profileDefault != null) {
            return profileDefault;
        }
        return key.platformDefault();
    }

    @Override
    @Transactional(readOnly = true)
    public boolean pharmacyEnabled() {
        return profileKey() != null;
    }

    /**
     * Delegates rather than reading {@code tenant_registry} itself: "does this
     * tenant have a pharmacy?" is asked by the API gate, the client's navigation
     * and this policy engine, and two of them answering differently is exactly
     * the class of bug a single owner of the question prevents.
     */
    @Override
    @Transactional(readOnly = true)
    public String profileKey() {
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());
        return tenantModuleService.manifestOf(tenantPublicId).pharmacyProfileKey();
    }

    /**
     * Sets a tenant-level override. Writing a mode the key forbids — the only
     * live example being {@code expired_batch_dispense=OFF} — is refused here
     * rather than filtered on read, so the illegal row never reaches the table
     * and no later reader has to remember to distrust it.
     */
    @Transactional
    public void setTenantOverride(PolicyKey key, PolicyMode mode, String actor) {
        if (!key.allows(mode)) {
            throw new IllegalArgumentException(
                    "Policy " + key.storageKey() + " cannot be set to " + mode);
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        jdbcTemplate.update(
                "INSERT INTO " + schema + ".pharmacy_config (config_key, config_value, updated_by) " +
                "VALUES (?, ?, ?) " +
                "ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value, " +
                "  updated_at = CURRENT_TIMESTAMP, updated_by = EXCLUDED.updated_by",
                key.storageKey(), mode.name(), actor);
    }

    private PolicyMode tenantOverride(PolicyKey key) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        List<String> rows = jdbcTemplate.queryForList(
                "SELECT config_value FROM " + schema + ".pharmacy_config WHERE config_key = ?",
                String.class, key.storageKey());
        return rows.isEmpty() ? null : PolicyMode.parse(rows.get(0), null);
    }

    private PolicyMode profileDefault(PolicyKey key) {
        String profileKey = profileKey();
        if (profileKey == null) {
            return null;
        }
        List<String> rows = jdbcTemplate.queryForList(
                "SELECT policy_defaults::text FROM platform.capability_profile WHERE profile_key = ?",
                String.class, profileKey);
        if (rows.isEmpty()) {
            // A profile key that no longer exists: log loudly, fall through to the
            // platform default rather than fail the caller's sale.
            log.warn("pharmacy_profile_unknown profileKey={} tenantPublicId={}",
                    profileKey, TenantContext.tenantPublicId());
            return null;
        }
        return PolicyMode.parse(readDefaults(rows.get(0)).get(key.storageKey()), null);
    }

    private Map<String, String> readDefaults(String json) {
        if (json == null || json.isBlank()) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<Map<String, String>>() {});
        } catch (Exception e) {
            log.warn("pharmacy_profile_defaults_unreadable json={}", json, e);
            return Map.of();
        }
    }

    /** A resolved value the key forbids is treated as if the layer had said nothing. */
    private PolicyMode accept(PolicyKey key, PolicyMode mode) {
        if (mode == null) {
            return null;
        }
        if (!key.allows(mode)) {
            log.warn("pharmacy_policy_value_rejected key={} value={} tenantPublicId={}",
                    key.storageKey(), mode, TenantContext.tenantPublicId());
            return null;
        }
        return mode;
    }
}
