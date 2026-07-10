package com.sevacare.pharmacy.catalog.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.catalog.entity.MedicineSku;
import com.sevacare.pharmacy.catalog.entity.SkuAlias;
import com.sevacare.pharmacy.catalog.entity.SkuPack;
import com.sevacare.pharmacy.catalog.repository.MedicineSkuRepository;
import com.sevacare.pharmacy.catalog.repository.SkuAliasRepository;
import com.sevacare.pharmacy.catalog.repository.SkuPackRepository;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.catalog.spi.CatalogLookup;
import com.sevacare.pharmacy.catalog.spi.SkuSummary;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Owns what a product is. Search is native SQL rather than JPA because the
 * ranking — a scanned barcode must beat a brand prefix, which must beat an alias
 * prefix — is the whole feature, and expressing it in Criteria would obscure it.
 */
@Service
public class CatalogService implements CatalogLookup {

    /** Enough for the counter's dropdown; a longer list is a slower decision. */
    private static final int MAX_SEARCH_LIMIT = 25;

    private static final String SKU_COLUMNS =
            "s.sku_public_id, s.brand_name, s.manufacturer, s.strength, s.dosage_form, " +
            "s.base_unit, s.schedule_class, s.hsn_code, s.gst_rate_bp, s.rack_location, s.active";

    private static final RowMapper<SkuSummary> SKU_MAPPER = (rs, i) -> new SkuSummary(
            rs.getString("sku_public_id"),
            rs.getString("brand_name"),
            rs.getString("manufacturer"),
            rs.getString("strength"),
            rs.getString("dosage_form"),
            BaseUnit.parse(rs.getString("base_unit")),
            rs.getString("schedule_class"),
            rs.getString("hsn_code"),
            rs.getInt("gst_rate_bp"),
            rs.getString("rack_location"),
            rs.getBoolean("active"));

    private final MedicineSkuRepository skuRepository;
    private final SkuAliasRepository aliasRepository;
    private final SkuPackRepository packRepository;
    private final JdbcTemplate jdbcTemplate;

    public CatalogService(MedicineSkuRepository skuRepository,
                          SkuAliasRepository aliasRepository,
                          SkuPackRepository packRepository,
                          JdbcTemplate jdbcTemplate) {
        this.skuRepository = skuRepository;
        this.aliasRepository = aliasRepository;
        this.packRepository = packRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public SkuSummary createSku(CreateSkuCommand command) {
        if (command.brandName() == null || command.brandName().isBlank()) {
            throw new IllegalArgumentException("A SKU needs a brand name");
        }

        BaseUnit baseUnit = command.baseUnit() == null ? BaseUnit.UNIT : command.baseUnit();

        MedicineSku sku = new MedicineSku();
        sku.setSkuPublicId(nextSkuPublicId());
        sku.setTenantPublicId(TenantSchemas.requireTenantId(TenantContext.tenantPublicId()));
        sku.setDrugPublicId(blankToNull(command.drugPublicId()));
        sku.setBrandName(command.brandName().trim());
        sku.setManufacturer(blankToNull(command.manufacturer()));
        sku.setDosageForm(blankToNull(command.dosageForm()));
        sku.setStrength(blankToNull(command.strength()));
        sku.setBaseUnit(baseUnit.name());
        sku.setScheduleClass(blankToNull(command.scheduleClass()));
        sku.setHsnCode(blankToNull(command.hsnCode()));
        sku.setGstRateBp(command.gstRateBp() == null ? 0 : command.gstRateBp());
        sku.setRackLocation(blankToNull(command.rackLocation()));
        sku.setReorderLevel(command.reorderLevel());
        sku.setReorderQty(command.reorderQty());
        skuRepository.save(sku);

        savePackHierarchy(sku.getSkuPublicId(), baseUnit, command.packs());

        if (command.aliases() != null) {
            for (String alias : command.aliases()) {
                addAlias(sku.getSkuPublicId(), alias, "MANUAL");
            }
        }
        return toSummary(sku);
    }

    /**
     * The base level always exists and always contains one unit — it is the thing
     * the ledger counts. Levels above it are stored in base units too, so a strip
     * of 10 stores 10 and a box of 10 strips stores 100.
     */
    private void savePackHierarchy(String skuPublicId, BaseUnit baseUnit, List<CreateSkuCommand.PackLevel> levels) {
        List<SkuPack> packs = new ArrayList<>();

        SkuPack basePack = new SkuPack();
        basePack.setSkuPublicId(skuPublicId);
        basePack.setPackName(baseUnit.name());
        basePack.setUnitsInPack(1);
        basePack.setSellable(true);
        basePack.setBase(true);
        basePack.setSortOrder((short) 0);
        packs.add(basePack);

        short order = 1;
        for (CreateSkuCommand.PackLevel level : levels == null ? List.<CreateSkuCommand.PackLevel>of() : levels) {
            if (level.unitsInPack() <= 1) {
                // The base level, restated. Not an error; just already present.
                continue;
            }
            if (level.packName() == null || level.packName().isBlank()) {
                throw new IllegalArgumentException("A pack level needs a name");
            }
            SkuPack pack = new SkuPack();
            pack.setSkuPublicId(skuPublicId);
            pack.setPackName(level.packName().trim().toUpperCase(Locale.ROOT));
            pack.setUnitsInPack(level.unitsInPack());
            pack.setSellable(level.sellable());
            pack.setBase(false);
            pack.setSortOrder(order++);
            packs.add(pack);
        }
        packRepository.saveAll(packs);
    }

    /**
     * Idempotent by (sku, alias): re-learning a scrawl the pharmacy already knows
     * bumps its hit count instead of failing, because the caller is a resolution
     * confirmation on a busy counter, not a form with validation.
     */
    @Transactional
    public void addAlias(String skuPublicId, String alias, String aliasKind) {
        if (alias == null || alias.isBlank()) {
            return;
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        jdbcTemplate.update(
                "INSERT INTO " + schema + ".sku_alias (sku_public_id, alias, alias_kind, hit_count) " +
                "VALUES (?, ?, ?, 1) " +
                "ON CONFLICT (sku_public_id, lower(alias)) " +
                "DO UPDATE SET hit_count = " + schema + ".sku_alias.hit_count + 1",
                skuPublicId, alias.trim(), aliasKind);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<SkuSummary> findSku(String skuPublicId) {
        return skuRepository.findById(skuPublicId).map(this::toSummary);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<SkuSummary> findByBarcode(String barcode) {
        if (barcode == null || barcode.isBlank()) {
            return Optional.empty();
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        List<SkuSummary> rows = jdbcTemplate.query(
                "SELECT " + SKU_COLUMNS + " FROM " + schema + ".sku_alias a " +
                "JOIN " + schema + ".medicine_sku s ON s.sku_public_id = a.sku_public_id " +
                "WHERE a.alias_kind = 'BARCODE' AND lower(a.alias) = lower(?) AND s.active LIMIT 1",
                SKU_MAPPER, barcode.trim());
        return rows.stream().findFirst();
    }

    @Override
    @Transactional(readOnly = true)
    public List<SkuSummary> search(String term, int limit) {
        if (term == null || term.isBlank()) {
            return List.of();
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String needle = term.trim().toLowerCase(Locale.ROOT);
        String prefix = escapeLike(needle) + "%";
        int cappedLimit = Math.min(Math.max(limit, 1), MAX_SEARCH_LIMIT);

        // rank 0: the barcode or alias was matched exactly -- the scanner won.
        // rank 1: brand prefix, what the pharmacist is typing.
        // rank 2: alias prefix, the learned shorthand.
        return jdbcTemplate.query(
                "WITH matched AS (" +
                "  SELECT sku_public_id, MIN(rank) AS rank FROM (" +
                "    SELECT sku_public_id, 0 AS rank FROM " + schema + ".sku_alias " +
                "      WHERE lower(alias) = ? " +
                "    UNION ALL " +
                "    SELECT sku_public_id, 1 FROM " + schema + ".medicine_sku " +
                "      WHERE lower(brand_name) LIKE ? ESCAPE '\\' " +
                "    UNION ALL " +
                "    SELECT sku_public_id, 2 FROM " + schema + ".sku_alias " +
                "      WHERE lower(alias) LIKE ? ESCAPE '\\' " +
                "  ) hits GROUP BY sku_public_id" +
                ") " +
                "SELECT " + SKU_COLUMNS + " FROM matched m " +
                "JOIN " + schema + ".medicine_sku s ON s.sku_public_id = m.sku_public_id " +
                "WHERE s.active " +
                "ORDER BY m.rank, lower(s.brand_name) " +
                "LIMIT " + cappedLimit,
                SKU_MAPPER, needle, prefix, prefix);
    }

    @Transactional(readOnly = true)
    public List<SkuPack> packsOf(String skuPublicId) {
        return packRepository.findBySkuPublicIdOrderBySortOrderAsc(skuPublicId);
    }

    @Transactional(readOnly = true)
    public List<SkuAlias> aliasesOf(String skuPublicId) {
        return aliasRepository.findBySkuPublicId(skuPublicId);
    }

    private String nextSkuPublicId() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        Long value = jdbcTemplate.queryForObject(
                "SELECT nextval('" + schema + ".sku_public_id_seq')", Long.class);
        if (value == null) {
            throw new IllegalStateException("Could not generate a SKU id");
        }
        return "SKU-" + String.format("%05d", value);
    }

    private SkuSummary toSummary(MedicineSku sku) {
        return new SkuSummary(
                sku.getSkuPublicId(), sku.getBrandName(), sku.getManufacturer(), sku.getStrength(),
                sku.getDosageForm(), BaseUnit.parse(sku.getBaseUnit()), sku.getScheduleClass(),
                sku.getHsnCode(), sku.getGstRateBp(), sku.getRackLocation(), sku.isActive());
    }

    /**
     * A pharmacist searching for "vitamin b_12" means an underscore, and a
     * pharmacist who types "%" deserves no results rather than all of them.
     */
    private static String escapeLike(String value) {
        return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
