package com.sevacare.tenant.capability;

import java.util.List;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The one place that answers "does this tenant have a pharmacy?" and "does it
 * have a clinical side?". The API gate, the client's navigation and the pharmacy
 * policy engine all read it, so they cannot disagree.
 *
 * <p>Uncached, on purpose. The read is a primary-key lookup on a table with one
 * row per hospital, and it sits beside the several queries the request was going
 * to make anyway. A cache here would mean one Cloud Run instance still serving a
 * module the owner switched off on another — and the bug that produces ("the
 * pharmacy tab comes and goes") is far more expensive than the query.
 */
@Service
public class TenantModuleService {

    private static final Logger log = LoggerFactory.getLogger(TenantModuleService.class);

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public TenantModuleService(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @Transactional(readOnly = true)
    public TenantManifest manifestOf(String tenantPublicId) {
        TenantSchemas.requireTenantId(tenantPublicId);

        List<TenantManifest> rows = jdbcTemplate.query(
                "SELECT tenant_public_id, tenant_name, clinical_enabled, pharmacy_profile_key " +
                "FROM public.tenant_registry WHERE tenant_public_id = ?",
                (rs, i) -> {
                    String profileKey = rs.getString("pharmacy_profile_key");
                    return new TenantManifest(
                            rs.getString("tenant_public_id"),
                            rs.getString("tenant_name"),
                            rs.getBoolean("clinical_enabled"),
                            profileKey,
                            featuresOf(profileKey));
                },
                tenantPublicId);

        if (rows.isEmpty()) {
            // An authenticated token for a tenant that no longer exists. Grant
            // nothing rather than guessing; the caller turns this into a 404.
            return new TenantManifest(tenantPublicId, null, false, null, Set.of());
        }
        return rows.get(0);
    }

    /**
     * Turns the tenant's answer to "what are you?" into the two switches, once,
     * at onboarding. A pharmacy profile passed explicitly wins over the kind's
     * default, so a chain can onboard as {@code PHARMACY_CHAIN} rather than being
     * forced through {@code MEDICAL_STORE} and upgraded afterwards.
     */
    @Transactional
    public void applyKind(String tenantPublicId, TenantKind kind, String pharmacyProfileKeyOverride) {
        String profileKey = pharmacyProfileKeyOverride != null && !pharmacyProfileKeyOverride.isBlank()
                ? pharmacyProfileKeyOverride.trim()
                : kind.pharmacyProfileKey();

        if (!kind.clinicalEnabled() && profileKey == null) {
            throw new IllegalArgumentException(
                    "A tenant with no clinical side must have a pharmacy profile");
        }
        jdbcTemplate.update(
                "UPDATE public.tenant_registry SET clinical_enabled = ?, pharmacy_profile_key = ? " +
                "WHERE tenant_public_id = ?",
                kind.clinicalEnabled(), profileKey, tenantPublicId);

        log.info("tenant_modules_set tenantPublicId={} clinical={} pharmacyProfile={}",
                tenantPublicId, kind.clinicalEnabled(), profileKey);
    }

    /** The fine-grained flags: wards, rx_queue, transfers… Empty when no pharmacy. */
    private Set<String> featuresOf(String profileKey) {
        if (profileKey == null || profileKey.isBlank()) {
            return Set.of();
        }
        List<String> json = jdbcTemplate.queryForList(
                "SELECT enabled_modules::text FROM platform.capability_profile WHERE profile_key = ?",
                String.class, profileKey);
        if (json.isEmpty()) {
            log.warn("pharmacy_profile_unknown profileKey={}", profileKey);
            return Set.of();
        }
        try {
            return Set.copyOf(objectMapper.readValue(json.get(0), new TypeReference<List<String>>() {}));
        } catch (Exception e) {
            log.warn("pharmacy_profile_modules_unreadable profileKey={}", profileKey, e);
            return Set.of();
        }
    }
}
