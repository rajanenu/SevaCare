package com.sevacare.tenant.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;

/**
 * Boot-time sweep: brings every already-active tenant schema up to the latest
 * {@code db/tenant} version. Tenants provisioned while the server keeps running
 * are migrated immediately by {@link TenantRegistryService#provisionTenant}
 * instead of waiting for the next restart.
 *
 * <p>Runs after the public-schema Flyway, which Spring Boot's auto-configuration
 * completes during context refresh — {@code tenant_registry} is therefore
 * readable by the time this runner fires.
 */
@Component
public class TenantMigrationInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(TenantMigrationInitializer.class);

    private final TenantRegistryRepository tenantRegistryRepository;
    private final TenantMigrationService tenantMigrationService;

    public TenantMigrationInitializer(
            TenantRegistryRepository tenantRegistryRepository,
            TenantMigrationService tenantMigrationService
    ) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.tenantMigrationService = tenantMigrationService;
    }

    @Override
    public void run(ApplicationArguments args) {
        List<TenantRegistry> tenants = tenantRegistryRepository.findByTenantStatus("active");
        List<String> failed = tenantMigrationService.migrateAll(tenants);

        if (failed.isEmpty()) {
            log.info("tenant_schema_migrations_complete tenants={}", tenants.size());
        } else {
            log.error("tenant_schema_migrations_incomplete tenants={} failed={} failedTenants={}",
                    tenants.size(), failed.size(), failed);
        }
    }
}
