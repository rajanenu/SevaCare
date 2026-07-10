package com.sevacare.api.pharmacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

import com.sevacare.pharmacy.capability.spi.CapabilityPolicies;
import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.inventory.service.CreateBatchCommand;
import com.sevacare.pharmacy.inventory.service.InventoryService;
import com.sevacare.pharmacy.inventory.service.StockLedgerService;
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.capability.TenantKind;
import com.sevacare.tenant.capability.TenantManifest;
import com.sevacare.tenant.capability.TenantModuleService;
import com.sevacare.tenant.service.TenantRegistryService;

/**
 * The blueprint's load-bearing commercial claim: "the pharmacy must be fully
 * valuable with zero other SevaCare modules active." A medical store is not a
 * hospital with the doctors deleted — it is a customer that never had any.
 */
class StandalonePharmacyIntegrationTest extends PharmacyIntegrationTestBase {

    private static final String STORE_ID = "T-9002";
    private static final String STORE_SCHEMA = "tenant_t_9002";

    @Autowired
    private TenantRegistryService tenantRegistryService;

    @Autowired
    private TenantModuleService tenantModuleService;

    @Autowired
    private CatalogService catalog;

    @Autowired
    private InventoryService inventory;

    @Autowired
    private StockLedgerService stockLedger;

    @Autowired
    private CapabilityPolicies policies;

    @AfterEach
    void dropStore() {
        TenantContext.clear();
        jdbcTemplate.execute("DROP SCHEMA IF EXISTS " + STORE_SCHEMA + " CASCADE");
        jdbcTemplate.update("DELETE FROM public.tenant_registry WHERE tenant_public_id = ?", STORE_ID);
    }

    private void onboardStore() {
        jdbcTemplate.update("DELETE FROM public.tenant_registry WHERE tenant_public_id = ?", STORE_ID);
        jdbcTemplate.execute("DROP SCHEMA IF EXISTS " + STORE_SCHEMA + " CASCADE");
        tenantRegistryService.provisionTenant(
                STORE_ID, "Sri Balaji Medicals", "default", "Owner", "9000000099",
                "owner@example.com", "Hyderabad", "500001", TenantKind.MEDICAL_STORE, null);
        TenantContext.set(STORE_ID, STORE_SCHEMA);
    }

    @Test
    void a_medical_store_onboards_with_one_answer_and_gets_only_a_pharmacy() {
        onboardStore();

        TenantManifest manifest = tenantModuleService.manifestOf(STORE_ID);
        assertThat(manifest.clinicalEnabled()).isFalse();
        assertThat(manifest.pharmacyEnabled()).isTrue();
        assertThat(manifest.pharmacyProfileKey()).isEqualTo("MEDICAL_STORE");
        assertThat(manifest.enabledModules()).containsExactly("pharmacy");

        // A store never sees ward UI: the feature is absent from its profile, not
        // merely disabled in it.
        assertThat(manifest.hasPharmacyFeature("inventory")).isTrue();
        assertThat(manifest.hasPharmacyFeature("wards")).isFalse();
        assertThat(manifest.hasPharmacyFeature("rx_queue")).isFalse();
    }

    /**
     * The whole point. Stock is received and sold without a doctor, a patient, an
     * appointment or a prescription existing anywhere in this tenant.
     */
    @Test
    void a_store_receives_and_sells_stock_with_no_clinical_records_at_all() {
        onboardStore();

        String sku = catalog.createSku(new CreateSkuCommand(
                "Dolo 650", "Micro Labs", "TABLET", "650mg", BaseUnit.TABLET, null, "3004", 1200,
                "R1", null, null, null,
                List.of(new CreateSkuCommand.PackLevel("STRIP", 15, true)), List.of("PCM"))).skuPublicId();

        String batch = inventory.findOrCreateBatch(
                new CreateBatchCommand(sku, "DL2401", LocalDate.now().plusYears(1), 200L, 150L, null));

        stockLedger.append(StockMovement.of(sku, batch, "COUNTER", 150, MovementReason.GRN, "GRN", "G-1", "owner"));
        stockLedger.append(StockMovement.of(sku, batch, "COUNTER", -4, MovementReason.SALE, "SALE", "S-1", "counter"));

        assertThat(stockLedger.balanceOfBatch(batch, "COUNTER")).isEqualTo(146);
        assertThat(policies.pharmacyEnabled()).isTrue();
        assertThat(policies.profileKey()).isEqualTo("MEDICAL_STORE");

        assertThat(clinicalRowCount("doctor")).isZero();
        assertThat(clinicalRowCount("patient")).isZero();
        assertThat(clinicalRowCount("appointment")).isZero();
        assertThat(clinicalRowCount("prescription")).isZero();
    }

    /**
     * A store that opens a clinic keeps its stock, its ledger and its customers.
     * Growing into the full product is one column, not a migration.
     */
    @Test
    void a_store_becomes_a_clinic_dispensary_by_flipping_one_switch() {
        onboardStore();
        tenantModuleService.applyKind(STORE_ID, TenantKind.HOSPITAL_WITH_PHARMACY, null);

        TenantManifest manifest = tenantModuleService.manifestOf(STORE_ID);
        assertThat(manifest.clinicalEnabled()).isTrue();
        assertThat(manifest.pharmacyProfileKey()).isEqualTo("CLINIC_DISPENSARY");
        assertThat(manifest.enabledModules()).containsExactlyInAnyOrder("clinical", "pharmacy");
        assertThat(manifest.hasPharmacyFeature("rx_queue")).isTrue();
    }

    /** The hospital side is untouched: our three real tenants still have no pharmacy. */
    @Test
    void an_existing_hospital_is_unaffected_and_has_no_pharmacy() {
        TenantManifest hospital = tenantModuleService.manifestOf(TENANT_PUBLIC_ID);
        assertThat(hospital.clinicalEnabled()).isTrue();

        jdbcTemplate.update(
                "UPDATE public.tenant_registry SET pharmacy_profile_key = NULL WHERE tenant_public_id = ?",
                TENANT_PUBLIC_ID);
        TenantManifest withoutPharmacy = tenantModuleService.manifestOf(TENANT_PUBLIC_ID);
        assertThat(withoutPharmacy.pharmacyEnabled()).isFalse();
        assertThat(withoutPharmacy.enabledModules()).containsExactly("clinical");
        assertThat(withoutPharmacy.pharmacyFeatures()).isEmpty();
    }

    @Test
    void a_tenant_with_no_modules_at_all_cannot_be_stored() {
        assertThatThrownBy(() -> jdbcTemplate.update(
                "UPDATE public.tenant_registry SET clinical_enabled = false, pharmacy_profile_key = NULL " +
                "WHERE tenant_public_id = ?", TENANT_PUBLIC_ID))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    /** A chain onboards as a chain rather than being upgraded out of MEDICAL_STORE. */
    @Test
    void an_explicit_profile_overrides_the_kinds_default() {
        onboardStore();
        tenantModuleService.applyKind(STORE_ID, TenantKind.MEDICAL_STORE, "PHARMACY_CHAIN");

        TenantManifest manifest = tenantModuleService.manifestOf(STORE_ID);
        assertThat(manifest.clinicalEnabled()).isFalse();
        assertThat(manifest.pharmacyProfileKey()).isEqualTo("PHARMACY_CHAIN");
        assertThat(manifest.hasPharmacyFeature("transfers")).isTrue();
    }

    private int clinicalRowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + STORE_SCHEMA + "." + table, Integer.class);
        return count == null ? 0 : count;
    }
}
