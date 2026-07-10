package com.sevacare.tenant.service;

import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

import javax.sql.DataSource;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
     */
    public List<String> migrateAll(List<TenantRegistry> tenants) {
        return tenants.stream()
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
}
