package com.sevacare.pharmacy.catalog.service;

import java.nio.charset.StandardCharsets;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.support.EncodedResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.FileCopyUtils;

import com.sevacare.tenant.support.TenantSchemas;

/**
 * Gives a newly opened pharmacy a shelf to sell from.
 *
 * <p>This used to be tenant migration V6, and it never once ran for a tenant
 * onboarded through the app. V6 gated every insert on {@code public.tenant_registry}
 * reporting the tenant as pharmacy-enabled, but {@code provisionTenant} migrates the
 * schema on Flyway's own connection <em>before</em> it commits the registry row — so
 * the gate read no row, coalesced to false, and seeded nothing. The three stores that
 * do have a catalog only got one because they already existed when V6 was written and
 * the boot sweep migrated them. Whether a tenant has pharmacy is knowable only after
 * the tenant is committed, which makes seeding a service's job and not a migration's.
 *
 * <p>Two guards make it safe to call on any schema at any time. A store with even one
 * SKU has a catalog of its own and is left alone. A store whose ledger has ever moved
 * is a store that has traded, and dropping 75 OPENING rows into its history would
 * falsify its stock — so an untouched ledger, the one signal that a pharmacy is
 * genuinely new, is required too. Everything else is idempotent {@code ON CONFLICT DO
 * NOTHING} on top of that.
 */
@Service
public class PharmacyCatalogSeeder {

    private static final Logger log = LoggerFactory.getLogger(PharmacyCatalogSeeder.class);
    private static final String SCRIPT = "pharmacy/starter_catalog.sql";

    /** Why a seed attempt did or did not put medicines on the shelf. */
    public enum Outcome {
        SEEDED,
        SKIPPED_HAS_CATALOG,
        SKIPPED_LEDGER_MOVED
    }

    private final JdbcTemplate jdbcTemplate;

    public PharmacyCatalogSeeder(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Seeds the starter catalog into a pharmacy-enabled tenant's schema, unless that
     * store already has a catalog or has already traded.
     *
     * <p>Runs in its own transaction: the ledger triggers only accept an append while
     * {@code sevacare.ledger_append} is set for the current transaction, and one
     * transaction per tenant also means a schema that fails to seed cannot take a
     * boot-time sweep over every other tenant down with it.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Outcome seedIfEmpty(String tenantPublicId, String tenantSchema) {
        // Both are interpolated into DDL-shaped SQL below, so both are validated
        // against the identifier grammar rather than trusted.
        String schema = TenantSchemas.require(tenantSchema);
        String tenantId = TenantSchemas.requireTenantId(tenantPublicId);

        if (count(schema, "medicine_sku") > 0) {
            return Outcome.SKIPPED_HAS_CATALOG;
        }
        if (count(schema, "stock_ledger") > 0) {
            return Outcome.SKIPPED_LEDGER_MOVED;
        }

        String sql = script()
                .replace("${tenantSchema}", schema)
                .replace("${tenantPublicId}", tenantId);

        jdbcTemplate.execute((java.sql.Connection connection) -> {
            ScriptUtils.executeSqlScript(connection, new EncodedResource(
                    new ByteArrayResource(sql.getBytes(StandardCharsets.UTF_8)), StandardCharsets.UTF_8));
            return null;
        });

        log.info("pharmacy_starter_catalog_seeded tenantPublicId={} schema={} skus={}",
                tenantId, schema, count(schema, "medicine_sku"));
        return Outcome.SEEDED;
    }

    private long count(String schema, String table) {
        Long value = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + schema + "." + table, Long.class);
        return value == null ? 0 : value;
    }

    private static String script() {
        try (var in = new ClassPathResource(SCRIPT).getInputStream()) {
            return new String(FileCopyUtils.copyToByteArray(in), StandardCharsets.UTF_8);
        } catch (java.io.IOException e) {
            throw new IllegalStateException("Starter catalog script is missing: " + SCRIPT, e);
        }
    }
}
