package com.sevacare.api.pharmacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.catalog.spi.CounterSku;
import com.sevacare.pharmacy.inventory.service.CreateBatchCommand;
import com.sevacare.pharmacy.inventory.service.InventoryService;
import com.sevacare.pharmacy.inventory.service.StockLedgerService;
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.shared.dto.PlatformAdminDtos;
import com.sevacare.shared.dto.TermsDtos;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.service.PlatformAdminService;
import com.sevacare.tenant.terms.TermsService;

/**
 * Onboarding as a platform admin actually experiences it: two checkboxes, and a
 * pharmacy that is never switched on by accident.
 */
class PlatformOnboardingIntegrationTest extends PharmacyIntegrationTestBase {

    @Autowired
    private PlatformAdminService platformAdmin;

    @Autowired
    private CatalogService catalog;

    @Autowired
    private InventoryService inventory;

    @Autowired
    private StockLedgerService stockLedger;

    @Autowired
    private TermsService termsService;

    private final List<PlatformAdminDtos.PlatformTenantView> provisioned = new ArrayList<>();

    @AfterEach
    void dropProvisionedTenants() {
        TenantContext.clear();
        for (PlatformAdminDtos.PlatformTenantView tenant : provisioned) {
            jdbcTemplate.execute("DROP SCHEMA IF EXISTS " + tenant.schemaName() + " CASCADE");
            jdbcTemplate.update("DELETE FROM public.tenant_registry WHERE tenant_public_id = ?",
                    tenant.tenantPublicId());
        }
        provisioned.clear();
    }

    private PlatformAdminDtos.PlatformTenantView onboard(String name, Boolean clinical, Boolean pharmacy, String profile) {
        PlatformAdminDtos.PlatformTenantView view = platformAdmin.createTenant(
                new PlatformAdminDtos.PlatformTenantUpsertRequest(
                        name, "Hyderabad", "500001", "default", "Owner", "9000000098",
                        "owner@example.com", "active", clinical, pharmacy, profile, true));
        provisioned.add(view);
        return view;
    }

    /** The default, and the one that must not change: a hospital gets no pharmacy. */
    @Test
    void a_hospital_onboarded_without_ticking_pharmacy_has_none() {
        PlatformAdminDtos.PlatformTenantView view = onboard("City Hospital", true, false, null);

        assertThat(view.clinicalEnabled()).isTrue();
        assertThat(view.pharmacyProfileKey()).isNull();
        assertThat(view.kindLabel()).isEqualTo("Hospital only");
    }

    /** Absent flags mean "hospital, no pharmacy" — every pre-existing caller is safe. */
    @Test
    void an_older_client_that_sends_no_flags_still_onboards_a_plain_hospital() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Legacy Hospital", null, null, null);

        assertThat(view.clinicalEnabled()).isTrue();
        assertThat(view.pharmacyProfileKey()).isNull();
    }

    @Test
    void ticking_pharmacy_beside_a_hospital_gives_a_clinic_dispensary() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Care Clinic", true, true, null);

        assertThat(view.clinicalEnabled()).isTrue();
        assertThat(view.pharmacyProfileKey()).isEqualTo("CLINIC_DISPENSARY");
        assertThat(view.kindLabel()).isEqualTo("Hospital + Pharmacy");
    }

    @Test
    void a_pharmacy_can_be_onboarded_with_no_hospital_at_all() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Sri Balaji Medicals", false, true, null);

        assertThat(view.clinicalEnabled()).isFalse();
        assertThat(view.pharmacyProfileKey()).isEqualTo("MEDICAL_STORE");
        assertThat(view.kindLabel()).isEqualTo("Pharmacy only");
    }

    @Test
    void a_platform_admin_may_choose_a_bigger_pharmacy_profile() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Apollo Chain", false, true, "PHARMACY_CHAIN");

        assertThat(view.pharmacyProfileKey()).isEqualTo("PHARMACY_CHAIN");
    }

    @Test
    void unticking_both_boxes_is_refused_with_words_a_human_can_act_on() {
        assertThatThrownBy(() -> onboard("Nothing At All", false, false, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("at least one");
    }

    /** Adding a pharmacy to a hospital a year later is the expected growth path. */
    @Test
    void a_hospital_can_gain_a_pharmacy_later() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Growing Hospital", true, false, null);

        PlatformAdminDtos.PlatformTenantView updated = platformAdmin.updateTenant(
                view.tenantPublicId(),
                new PlatformAdminDtos.PlatformTenantUpsertRequest(
                        "Growing Hospital", "Hyderabad", "500001", "default", "Owner", "9000000098",
                        "owner@example.com", "active", true, true, null, true));

        assertThat(updated.pharmacyProfileKey()).isEqualTo("CLINIC_DISPENSARY");
        assertThat(updated.kindLabel()).isEqualTo("Hospital + Pharmacy");
    }

    /** An onboarding mistake, caught before anyone used the module, is just a fix. */
    @Test
    void an_unused_pharmacy_can_be_switched_back_off() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Oops Hospital", true, true, null);

        PlatformAdminDtos.PlatformTenantView updated = platformAdmin.updateTenant(
                view.tenantPublicId(), upsert("Oops Hospital", true, false, null));

        assertThat(updated.pharmacyProfileKey()).isNull();
        assertThat(updated.kindLabel()).isEqualTo("Hospital only");
    }

    /**
     * The guard that matters. A stock ledger is a retained record an inspector may
     * ask for years later; unticking a checkbox must never be how it disappears.
     */
    @Test
    void a_pharmacy_that_has_moved_stock_cannot_be_switched_off() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Busy Clinic", true, true, null);

        TenantContext.set(view.tenantPublicId(), view.schemaName());
        String sku = catalog.createSku(new CreateSkuCommand(
                "Dolo 650", null, "TABLET", "650mg", BaseUnit.TABLET, null, null, 1200,
                null, null, null, null, List.of(), List.of())).skuPublicId();
        String batch = inventory.findOrCreateBatch(
                new CreateBatchCommand(sku, "B1", LocalDate.now().plusYears(1), 200L, null, null));
        stockLedger.append(StockMovement.of(sku, batch, "COUNTER", 10, MovementReason.GRN, "GRN", "G-1", "owner"));
        TenantContext.clear();

        assertThatThrownBy(() -> platformAdmin.updateTenant(
                view.tenantPublicId(), upsert("Busy Clinic", true, false, null)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("retained record")
                .hasMessageContaining("Deactivate the tenant instead");
    }

    /**
     * The one that would have caught the empty shelf. A store onboarded through the
     * app must be able to search for a medicine the moment its owner signs in — the
     * starter catalog is not a nicety, it is the difference between a working counter
     * and a search box that answers nothing.
     *
     * <p>Seeding used to be tenant migration V6, gated on {@code tenant_registry}
     * reporting pharmacy enabled. Onboarding migrates the schema before it commits
     * that row, so the gate read nothing and the seed never once ran for a real
     * customer. It is a service now, and it runs after the commit.
     */
    @Test
    void a_newly_onboarded_pharmacy_can_search_for_medicines_on_day_one() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Fresh Medicals", false, true, null);

        TenantContext.set(view.tenantPublicId(), view.schemaName());
        try {
            assertThat(catalog.counterCatalog().items()).isNotEmpty();
            assertThat(catalog.searchForCounter("paracetamol", 10))
                    .extracting(CounterSku::brandName)
                    .anyMatch(brand -> brand.toLowerCase().startsWith("paracetamol"));
        } finally {
            TenantContext.clear();
        }
    }

    /** A hospital that never bought a pharmacy gets no pharmacy stock, seeded or otherwise. */
    @Test
    void a_hospital_without_pharmacy_gets_no_starter_catalog() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Bare Hospital", true, false, null);

        Long skus = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + view.schemaName() + ".medicine_sku", Long.class);
        assertThat(skus).isZero();
    }

    /** Editing a tenant's city must not silently demote its pharmacy profile. */
    @Test
    void editing_a_tenant_keeps_the_pharmacy_profile_it_already_had() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Chain HQ", false, true, "PHARMACY_CHAIN");

        PlatformAdminDtos.PlatformTenantView updated = platformAdmin.updateTenant(
                view.tenantPublicId(),
                new PlatformAdminDtos.PlatformTenantUpsertRequest(
                        "Chain HQ", "Chennai", "600001", "default", "Owner", "9000000098",
                        "owner@example.com", "active", false, true, null, true));

        assertThat(updated.pharmacyProfileKey()).isEqualTo("PHARMACY_CHAIN");
        assertThat(updated.city()).isEqualTo("Chennai");
    }

    @Test
    void the_profile_dropdown_is_filled_from_the_database() {
        assertThat(platformAdmin.pharmacyProfiles().profiles())
                .extracting(PlatformAdminDtos.PharmacyProfileOptionView::profileKey)
                .containsExactly("MEDICAL_STORE", "CLINIC_DISPENSARY", "HOSPITAL_PHARMACY",
                        "PHARMACY_CHAIN", "CORPORATE_ENTERPRISE");
        assertThat(platformAdmin.pharmacyProfiles().profiles().get(0).displayName())
                .isEqualTo("Medical store");
    }

    // ── Terms of service ───────────────────────────────────────────────────────
    //
    // Consent is a record, not a form field: whichever way it is given, we must be
    // able to say afterwards what was agreed and when.

    @Test
    void terms_agreed_at_onboarding_are_recorded_against_the_tenant() {
        PlatformAdminDtos.PlatformTenantView view = onboard("Consenting Clinic", true, false, null);

        TermsDtos.TermsAcceptanceView terms = termsService.acceptance(view.tenantPublicId());

        assertThat(terms.upToDate()).isTrue();
        assertThat(terms.acceptedVersion()).isEqualTo(TermsService.CURRENT_VERSION);
        assertThat(terms.acceptedAt()).isNotNull();
        assertThat(terms.acceptedBy()).contains("at onboarding");
    }

    /** Nobody is assumed to have agreed to words they were never shown — the app asks. */
    @Test
    void a_tenant_onboarded_without_consent_is_asked_in_the_app() {
        PlatformAdminDtos.PlatformTenantView view = platformAdmin.createTenant(
                new PlatformAdminDtos.PlatformTenantUpsertRequest(
                        "Silent Store", "Hyderabad", "500001", "default", "Owner", "9000000097",
                        "owner@example.com", "active", false, true, "MEDICAL_STORE", null));
        provisioned.add(view);

        assertThat(termsService.acceptance(view.tenantPublicId()).upToDate()).isFalse();

        TermsDtos.TermsAcceptanceView accepted = termsService.accept(view.tenantPublicId(), "Suresh (owner)");

        assertThat(accepted.upToDate()).isTrue();
        assertThat(accepted.acceptedBy()).isEqualTo("Suresh (owner)");
        assertThat(termsService.document().sections()).isNotEmpty();
    }

    private PlatformAdminDtos.PlatformTenantUpsertRequest upsert(
            String name, Boolean clinical, Boolean pharmacy, String profile) {
        return new PlatformAdminDtos.PlatformTenantUpsertRequest(
                name, "Hyderabad", "500001", "default", "Owner", "9000000098",
                "owner@example.com", "active", clinical, pharmacy, profile, true);
    }
}
