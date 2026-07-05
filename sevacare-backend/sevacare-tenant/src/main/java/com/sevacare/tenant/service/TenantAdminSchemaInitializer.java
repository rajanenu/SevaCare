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
 * Boot-time sweep: repairs schema drift for every tenant that was already
 * active before this process started. Brand-new tenants provisioned while
 * the server keeps running are repaired immediately by
 * {@link TenantRegistryService#provisionTenant} instead of waiting for the
 * next restart — see {@link TenantSchemaMaintenanceService}.
 */
@Component
public class TenantAdminSchemaInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(TenantAdminSchemaInitializer.class);

    private final TenantRegistryRepository tenantRegistryRepository;
    private final TenantSchemaMaintenanceService schemaMaintenanceService;

    public TenantAdminSchemaInitializer(
            TenantRegistryRepository tenantRegistryRepository,
            TenantSchemaMaintenanceService schemaMaintenanceService
    ) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.schemaMaintenanceService = schemaMaintenanceService;
    }

    @Override
    public void run(ApplicationArguments args) {
        List<TenantRegistry> tenants = tenantRegistryRepository.findByTenantStatus("active");
        for (TenantRegistry tenant : tenants) {
            String schemaName = tenant.getTenantSchemaName();
            if (!schemaMaintenanceService.hasSchema(schemaName)) {
                log.warn("tenant_schema_missing_skip schemaName={} tenantPublicId={}", schemaName, tenant.getTenantPublicId());
                continue;
            }
            schemaMaintenanceService.ensureSchemaShape(tenant, schemaName);
        }
    }
}
