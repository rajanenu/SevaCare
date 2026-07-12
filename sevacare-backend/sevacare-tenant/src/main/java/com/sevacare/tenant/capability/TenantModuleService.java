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
     * Turns the tenant's answer to "what are you?" into the two switches. A
     * pharmacy profile passed explicitly wins over the kind's default, so a chain
     * onboards as {@code PHARMACY_CHAIN} rather than being forced through
     * {@code MEDICAL_STORE} and upgraded afterwards.
     *
     * <p>Switching a module <b>on</b> is always safe — its tables exist and are
     * empty. Switching one <b>off</b> is guarded: see
     * {@link #assertSafeToDisable}.
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

        TenantManifest before = manifestOf(tenantPublicId);
        if (before.tenantName() != null) {
            assertSafeToDisable(tenantPublicId, before, kind.clinicalEnabled(), profileKey != null);
        }

        jdbcTemplate.update(
                "UPDATE public.tenant_registry SET clinical_enabled = ?, pharmacy_profile_key = ? " +
                "WHERE tenant_public_id = ?",
                kind.clinicalEnabled(), profileKey, tenantPublicId);

        log.info("tenant_modules_set tenantPublicId={} clinical={} pharmacyProfile={}",
                tenantPublicId, kind.clinicalEnabled(), profileKey);
    }

    /**
     * A module that holds records cannot be switched off.
     *
     * <p>This is not a data-safety nicety, it is Indian law and basic commercial
     * sense. A pharmacy's stock ledger and its Schedule H/H1 register are retained
     * documents that an inspector may ask for years later; a hospital's patient
     * records likewise. "Untick pharmacy" must never become the way a stock
     * ledger disappears from every screen in the product while the rows sit in
     * the schema, unreachable and unaudited.
     *
     * <p>Turning a module off before it has been used is fine — that is someone
     * fixing an onboarding mistake, and there is nothing to lose.
     */
    @Transactional(readOnly = true)
    public void assertSafeToDisable(String tenantPublicId, TenantManifest current,
                                    boolean clinicalWanted, boolean pharmacyWanted) {
        String schema = schemaOf(tenantPublicId);
        if (schema == null) {
            return;
        }

        if (current.clinicalEnabled() && !clinicalWanted) {
            long records = countIn(schema, "patient") + countIn(schema, "appointment");
            if (records > 0) {
                throw new IllegalStateException(
                        "This hospital already has " + records + " patient and appointment records. "
                        + "Turning the hospital module off would hide them. Deactivate the tenant instead.");
            }
        }

        if (current.pharmacyEnabled() && !pharmacyWanted) {
            long movements = countLedgerMovements(schema);
            if (movements > 0) {
                throw new IllegalStateException(
                        "This pharmacy already has " + movements + " stock movements on its ledger, which is a "
                        + "retained record. Turning the pharmacy module off would hide it. Deactivate the tenant instead.");
            }
        }
    }

    /** Every profile a platform admin may pick, in the words a customer understands. */
    @Transactional(readOnly = true)
    public List<PharmacyProfileOption> pharmacyProfiles() {
        return jdbcTemplate.query(
                "SELECT profile_key, display_name, description FROM platform.capability_profile ORDER BY sort_order",
                (rs, i) -> new PharmacyProfileOption(
                        rs.getString("profile_key"),
                        rs.getString("display_name"),
                        rs.getString("description")));
    }

    public record PharmacyProfileOption(String profileKey, String displayName, String description) {
    }

    private String schemaOf(String tenantPublicId) {
        List<String> rows = jdbcTemplate.queryForList(
                "SELECT tenant_schema_name FROM public.tenant_registry WHERE tenant_public_id = ?",
                String.class, tenantPublicId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private long countIn(String schema, String table) {
        TenantSchemas.require(schema);
        Long count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + "." + table, Long.class);
        return count == null ? 0L : count;
    }

    /**
     * Excludes rows the platform itself seeded — a starter catalog's opening stock.
     * Those are demo data, reproducible by re-running onboarding, not a business
     * record an inspector could ask for. A pharmacy that has only ever held seed data
     * is exactly as "unused" as one with an empty ledger, and must stay as easy to
     * switch back off.
     *
     * <p>Two markers, because the seed has had two homes. {@code SEED} is what
     * PharmacyCatalogSeeder writes; {@code MIGRATION} is what tenant migration V6
     * wrote for the handful of stores it reached before seeding moved out of Flyway.
     * Both are the platform stocking a shelf, and neither is a sale.
     */
    private long countLedgerMovements(String schema) {
        String safeSchema = TenantSchemas.require(schema);
        Long count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + safeSchema + ".stock_ledger "
                + "WHERE ref_type NOT IN ('SEED', 'MIGRATION') OR ref_type IS NULL",
                Long.class);
        return count == null ? 0L : count;
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
