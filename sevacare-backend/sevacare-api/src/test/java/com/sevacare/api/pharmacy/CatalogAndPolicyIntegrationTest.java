package com.sevacare.api.pharmacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import com.sevacare.pharmacy.capability.service.CapabilityPolicyService;
import com.sevacare.pharmacy.capability.spi.PolicyKey;
import com.sevacare.pharmacy.capability.spi.PolicyMode;
import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.catalog.spi.SkuSummary;

class CatalogAndPolicyIntegrationTest extends PharmacyIntegrationTestBase {

    @Autowired
    private CatalogService catalog;

    @Autowired
    private CapabilityPolicyService policies;

    @Test
    void a_sku_gets_a_base_pack_it_was_never_asked_for() {
        String sku = catalog.createSku(command("Dolo 650", BaseUnit.TABLET,
                List.of(new CreateSkuCommand.PackLevel("STRIP", 10, true),
                        new CreateSkuCommand.PackLevel("BOX", 150, false))))
                .skuPublicId();

        // Pack sizes are in BASE units at every level: a box of 15 strips is 150
        // tablets, not 15 of something whose size might later be corrected.
        assertThat(catalog.packsOf(sku))
                .extracting("packName", "unitsInPack", "base")
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("TABLET", 1, true),
                        org.assertj.core.groups.Tuple.tuple("STRIP", 10, false),
                        org.assertj.core.groups.Tuple.tuple("BOX", 150, false));
    }

    @Test
    void the_scanner_beats_the_typist() {
        String paracetamol = catalog.createSku(command("Paracetamol 650", BaseUnit.TABLET, List.of())).skuPublicId();
        String dolo = catalog.createSku(command("Dolo 650", BaseUnit.TABLET, List.of())).skuPublicId();

        catalog.addAlias(dolo, "8901234567890", "BARCODE");
        catalog.addAlias(paracetamol, "8901234567890x", "BARCODE");

        // An exact alias match outranks a brand prefix, so a scanned barcode lands
        // on one row rather than opening a dropdown.
        List<SkuSummary> hits = catalog.search("8901234567890", 10);
        assertThat(hits).extracting(SkuSummary::skuPublicId).containsExactly(dolo, paracetamol);

        assertThat(catalog.findByBarcode("8901234567890"))
                .map(SkuSummary::skuPublicId)
                .contains(dolo);
    }

    @Test
    void a_learned_scrawl_finds_the_sku_and_relearning_it_does_not_fail() {
        String dolo = catalog.createSku(command("Dolo 650", BaseUnit.TABLET, List.of())).skuPublicId();

        catalog.addAlias(dolo, "PCM 650", "LEARNED");
        // The same confirmation on a busy counter, twice. The second is a hit
        // count bump, not a constraint violation.
        catalog.addAlias(dolo, "pcm 650", "LEARNED");

        assertThat(catalog.search("pcm", 10)).extracting(SkuSummary::skuPublicId).containsExactly(dolo);
        assertThat(catalog.aliasesOf(dolo)).hasSize(1);
        assertThat(catalog.aliasesOf(dolo).get(0).getHitCount()).isEqualTo(2);
    }

    @Test
    void a_wildcard_typed_into_search_is_a_character_not_a_command() {
        catalog.createSku(command("Dolo 650", BaseUnit.TABLET, List.of()));
        catalog.createSku(command("Crocin", BaseUnit.TABLET, List.of()));

        assertThat(catalog.search("%", 10)).isEmpty();
        assertThat(catalog.search("_", 10)).isEmpty();
    }

    @Test
    void an_unstocked_scrawl_returns_nothing_rather_than_failing() {
        assertThat(catalog.search("zzz-nonexistent", 10)).isEmpty();
        assertThat(catalog.findByBarcode("nope")).isEmpty();
    }

    @Test
    void the_profile_supplies_a_default_and_the_tenant_may_override_it() {
        // MEDICAL_STORE's seeded default, from platform.capability_profile.
        assertThat(policies.profileKey()).isEqualTo("MEDICAL_STORE");
        assertThat(policies.pharmacyEnabled()).isTrue();
        assertThat(policies.modeOf(PolicyKey.BATCH_ON_SALE_LINE)).isEqualTo(PolicyMode.SUGGEST);

        policies.setTenantOverride(PolicyKey.BATCH_ON_SALE_LINE, PolicyMode.ENFORCE, "owner");
        assertThat(policies.modeOf(PolicyKey.BATCH_ON_SALE_LINE)).isEqualTo(PolicyMode.ENFORCE);
    }

    @Test
    void a_knob_no_profile_mentions_falls_back_to_the_platform_default() {
        // MEDICAL_STORE says nothing about negative stock; the platform does.
        assertThat(policies.modeOf(PolicyKey.NEGATIVE_STOCK)).isEqualTo(PolicyMode.SUGGEST);
    }

    /**
     * The one rule that is not a preference. Neither an API caller nor a row
     * hand-edited into the config table can turn it off.
     */
    @Test
    void dispensing_from_an_expired_batch_can_never_be_switched_off() {
        assertThat(policies.modeOf(PolicyKey.EXPIRED_BATCH_DISPENSE)).isEqualTo(PolicyMode.ENFORCE);

        assertThatThrownBy(() -> policies.setTenantOverride(PolicyKey.EXPIRED_BATCH_DISPENSE, PolicyMode.OFF, "owner"))
                .isInstanceOf(IllegalArgumentException.class);

        jdbcTemplate.update(
                "INSERT INTO " + TENANT_SCHEMA + ".pharmacy_config (config_key, config_value) VALUES ('expired_batch_dispense', 'OFF')");

        assertThat(policies.modeOf(PolicyKey.EXPIRED_BATCH_DISPENSE)).isEqualTo(PolicyMode.ENFORCE);
    }

    @Test
    void a_tenant_without_a_profile_has_no_pharmacy() {
        jdbcTemplate.update(
                "UPDATE public.tenant_registry SET pharmacy_profile_key = NULL WHERE tenant_public_id = ?",
                TENANT_PUBLIC_ID);

        assertThat(policies.pharmacyEnabled()).isFalse();
        // Policies still resolve, to platform defaults, so nothing NPEs on the way
        // to the "pharmacy is not enabled" answer.
        assertThat(policies.modeOf(PolicyKey.BATCH_ON_SALE_LINE)).isEqualTo(PolicyMode.SUGGEST);
    }

    private CreateSkuCommand command(String brandName, BaseUnit baseUnit, List<CreateSkuCommand.PackLevel> packs) {
        return new CreateSkuCommand(brandName, "Acme", "TABLET", "650mg", baseUnit,
                null, "3004", 1200, "R1", null, null, null, packs, List.of());
    }
}
