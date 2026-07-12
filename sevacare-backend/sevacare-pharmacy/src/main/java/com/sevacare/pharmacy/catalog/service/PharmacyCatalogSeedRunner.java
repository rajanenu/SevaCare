package com.sevacare.pharmacy.catalog.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

import com.sevacare.shared.event.PharmacyEnabledEvent;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;

/**
 * Makes sure every pharmacy-enabled tenant actually has medicines to sell — the
 * store that opens tomorrow, and the ones already open with an empty shelf.
 *
 * <p>A new store is seeded the moment its onboarding transaction commits, so the
 * owner who signs in a second later can search and sell. A store onboarded before
 * this existed is healed by the boot sweep, which is the only route open to it: its
 * schema migrated long ago, and the seed it should have had was a migration that
 * silently did nothing (see {@link PharmacyCatalogSeeder}).
 *
 * <p>The sweep runs after {@code TenantMigrationInitializer}, because a schema has
 * to have the pharmacy tables before it can have pharmacy rows.
 */
@Component
@Order(PharmacyCatalogSeedRunner.ORDER)
public class PharmacyCatalogSeedRunner implements ApplicationRunner {

    /** After TenantMigrationInitializer, which claims 0. */
    public static final int ORDER = 100;

    private static final Logger log = LoggerFactory.getLogger(PharmacyCatalogSeedRunner.class);

    private final TenantRegistryRepository tenantRegistryRepository;
    private final PharmacyCatalogSeeder seeder;

    public PharmacyCatalogSeedRunner(TenantRegistryRepository tenantRegistryRepository,
                                     PharmacyCatalogSeeder seeder) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.seeder = seeder;
    }

    /**
     * A tenant just turned pharmacy on. Fires only after the registry row is
     * committed — before that, nothing can even tell that this tenant has a pharmacy.
     */
    @TransactionalEventListener
    public void onPharmacyEnabled(PharmacyEnabledEvent event) {
        seedQuietly(event.tenantPublicId(), event.tenantSchema());
    }

    @Override
    public void run(ApplicationArguments args) {
        List<TenantRegistry> tenants = tenantRegistryRepository.findByTenantStatus("active").stream()
                .filter(t -> t.getPharmacyProfileKey() != null)
                .toList();

        int seeded = 0;
        for (TenantRegistry tenant : tenants) {
            if (seedQuietly(tenant.getTenantPublicId(), tenant.getTenantSchemaName())) {
                seeded++;
            }
        }
        log.info("pharmacy_catalog_seed_sweep pharmacies={} seeded={}", tenants.size(), seeded);
    }

    /**
     * One store failing to seed must not cost the others their shelf, nor take the
     * deployment down — an empty catalog is a bad day, a crash loop is an outage.
     *
     * @return whether this store actually gained a starter catalog
     */
    private boolean seedQuietly(String tenantPublicId, String tenantSchema) {
        try {
            return seeder.seedIfEmpty(tenantPublicId, tenantSchema) == PharmacyCatalogSeeder.Outcome.SEEDED;
        } catch (RuntimeException e) {
            log.error("pharmacy_catalog_seed_failed tenantPublicId={} schema={}",
                    tenantPublicId, tenantSchema, e);
            return false;
        }
    }
}
