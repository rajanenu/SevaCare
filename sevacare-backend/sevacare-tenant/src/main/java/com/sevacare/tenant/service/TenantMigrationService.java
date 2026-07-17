package com.sevacare.tenant.service;

import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.sql.DataSource;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.sevacare.tenant.entity.TenantRegistry;

/**
 * Runs versioned Flyway migrations against a single tenant schema.
 *
 * <p>Tenant DDL used to live in two places — {@code createTenantSchema()} for
 * fresh schemas and {@code ensureSchemaShape()} re-run on every boot to repair
 * drift. Neither was versioned, so schemas provisioned by different generations
 * of that code diverged, and every statement touching a tenant table had to be
 * defensively guarded. Tenant tables are now versioned like public ones: the
 * migrations in {@code db/tenant} run per schema, tracked in that schema's own
 * {@code flyway_tenant_history} table.
 *
 * <p>Called from two places, so a schema can never miss a migration:
 * {@link TenantMigrationInitializer} at boot for every already-active tenant,
 * and {@link TenantRegistryService#provisionTenant} for a hospital onboarded
 * while the server keeps running.
 */
@Component
public class TenantMigrationService {

    private static final Logger log = LoggerFactory.getLogger(TenantMigrationService.class);

    private static final String MIGRATION_LOCATION = "classpath:db/tenant";
    private static final String HISTORY_TABLE = "flyway_tenant_history";

    /** Schema and tenant ids are interpolated into DDL as placeholders, never bound. */
    private static final Pattern SAFE_SCHEMA = Pattern.compile("^[a-z][a-z0-9_]{0,62}$");
    private static final Pattern SAFE_TENANT_ID = Pattern.compile("^[A-Za-z0-9_-]{1,24}$");

    private final DataSource dataSource;
    private final JdbcTemplate jdbcTemplate;

    public TenantMigrationService(DataSource dataSource, JdbcTemplate jdbcTemplate) {
        this.dataSource = dataSource;
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean hasSchema(String schemaName) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = ?",
                Integer.class,
                schemaName
        );
        return count != null && count > 0;
    }

    /**
     * Brings one tenant schema up to the latest version, creating the schema if
     * it does not exist yet. Idempotent; concurrent callers (two Cloud Run
     * instances booting at once) serialise on Flyway's own lock.
     */
    public void migrate(TenantRegistry tenant) {
        String schemaName = tenant.getTenantSchemaName();
        String tenantPublicId = tenant.getTenantPublicId();

        if (schemaName == null || !SAFE_SCHEMA.matcher(schemaName).matches()) {
            throw new IllegalArgumentException("Refusing to migrate unsafe schema name: " + schemaName);
        }
        if (tenantPublicId == null || !SAFE_TENANT_ID.matcher(tenantPublicId).matches()) {
            throw new IllegalArgumentException("Refusing to migrate unsafe tenant id: " + tenantPublicId);
        }

        Flyway flyway = Flyway.configure()
                .dataSource(dataSource)
                .locations(MIGRATION_LOCATION)
                .schemas(schemaName)
                .defaultSchema(schemaName)
                .createSchemas(true)
                .table(HISTORY_TABLE)
                // Existing tenant schemas are full of tables but have no history
                // table, and Flyway refuses to migrate into that. Baseline them --
                // but at version 0, not Flyway's default of 1. At 1, Flyway would
                // record V1 as already applied and skip it, leaving every schema
                // provisioned before this runner permanently unconverged. V1 is
                // written to converge any pre-existing schema, so it must run.
                .baselineOnMigrate(true)
                .baselineVersion("0")
                // A tenant schema is a hospital's entire records. Nothing may clean it.
                .cleanDisabled(true)
                .placeholders(Map.of(
                        "tenantSchema", schemaName,
                        "tenantPublicId", tenantPublicId
                ))
                .load();

        MigrateResult result = flyway.migrate();
        if (result.migrationsExecuted > 0) {
            log.info("tenant_schema_migrated schemaName={} tenantPublicId={} executed={} targetVersion={}",
                    schemaName, tenantPublicId, result.migrationsExecuted, result.targetSchemaVersion);
        } else {
            log.debug("tenant_schema_current schemaName={} tenantPublicId={}", schemaName, tenantPublicId);
        }
    }

    /**
     * Migrates every tenant, returning the ids that failed.
     *
     * <p>A tenant whose schema cannot be migrated must not take the whole
     * deployment down with it — on Cloud Run that would turn one broken hospital
     * into a total outage. Failures are logged at ERROR and reported to the
     * caller; healthy tenants keep serving.
     *
     * <p>Schemas already at the latest version are skipped on a one-query probe
     * instead of paying a full Flyway load each: boot cost was one Flyway
     * (connection, lock, validation) per tenant on <em>every</em> instance start,
     * which turns a scale-out during a traffic spike into minutes of cold start
     * once tenants number in the hundreds. Anything the probe cannot vouch for —
     * missing schema, missing history table, stale version — takes the full,
     * lock-protected path exactly as before.
     */
    public List<String> migrateAll(List<TenantRegistry> tenants) {
        int latest = latestAvailableVersion();
        List<TenantRegistry> stale = tenants.stream()
                .filter(tenant -> !isAtVersion(tenant, latest))
                .toList();
        if (stale.size() < tenants.size()) {
            log.info("tenant_schema_sweep current={} stale={}", tenants.size() - stale.size(), stale.size());
        }
        return stale.stream()
                .filter(tenant -> {
                    try {
                        migrate(tenant);
                        return false;
                    } catch (RuntimeException e) {
                        log.error("tenant_schema_migration_failed schemaName={} tenantPublicId={}",
                                tenant.getTenantSchemaName(), tenant.getTenantPublicId(), e);
                        return true;
                    }
                })
                .map(TenantRegistry::getTenantPublicId)
                .toList();
    }

    /**
     * Cheap probe: is this schema's history already at {@code latest}? False on
     * any doubt (no schema, no history table, unparseable versions) so the full
     * Flyway path decides. The probe trades Flyway's checksum validation for
     * boot speed — a hand-edited old migration file will not be caught here, but
     * it would only have been caught by a boot that then failed anyway.
     */
    private boolean isAtVersion(TenantRegistry tenant, int latest) {
        String schemaName = tenant.getTenantSchemaName();
        if (schemaName == null || !SAFE_SCHEMA.matcher(schemaName).matches()) {
            return false;
        }
        try {
            Integer applied = jdbcTemplate.queryForObject(
                    "SELECT MAX(CAST(version AS INTEGER)) FROM " + schemaName + "." + HISTORY_TABLE +
                            " WHERE success AND version ~ '^[0-9]+$'",
                    Integer.class);
            return applied != null && applied >= latest;
        } catch (DataAccessException e) {
            return false;
        }
    }

    /** Highest V<n> on the classpath; versions in db/tenant are plain integers. */
    private int latestAvailableVersion() {
        Pattern versioned = Pattern.compile("^V(\\d+)__.+\\.sql$");
        try {
            int latest = 0;
            for (Resource resource : new PathMatchingResourcePatternResolver()
                    .getResources("classpath*:db/tenant/V*.sql")) {
                String name = resource.getFilename();
                if (name == null) {
                    continue;
                }
                Matcher matcher = versioned.matcher(name);
                if (matcher.matches()) {
                    latest = Math.max(latest, Integer.parseInt(matcher.group(1)));
                }
            }
            if (latest == 0) {
                throw new IllegalStateException("No versioned tenant migrations found on classpath");
            }
            return latest;
        } catch (java.io.IOException e) {
            throw new IllegalStateException("Could not scan tenant migrations", e);
        }
    }
}
