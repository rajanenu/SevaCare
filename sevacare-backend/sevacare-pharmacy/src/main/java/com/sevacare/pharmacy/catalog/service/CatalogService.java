package com.sevacare.pharmacy.catalog.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

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
import com.sevacare.pharmacy.catalog.spi.CounterSku;
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

    /** Counter view: identity plus live on-hand and the FEFO batch's MRP. */
    private static final String COUNTER_COLUMNS =
            "s.sku_public_id, s.brand_name, s.manufacturer, s.strength, s.dosage_form, s.base_unit, " +
            "s.schedule_class, s.gst_rate_bp, s.rack_location, " +
            "COALESCE(oh.qty, 0) AS on_hand, COALESCE(mrp.mrp_paise, 0) AS mrp_paise";

    private static final RowMapper<CounterSku> COUNTER_MAPPER = (rs, i) -> new CounterSku(
            rs.getString("sku_public_id"),
            rs.getString("brand_name"),
            rs.getString("manufacturer"),
            rs.getString("strength"),
            rs.getString("dosage_form"),
            BaseUnit.parse(rs.getString("base_unit")),
            rs.getString("schedule_class"),
            rs.getInt("gst_rate_bp"),
            rs.getString("rack_location"),
            rs.getLong("on_hand"),
            rs.getLong("mrp_paise"));

    /**
     * The counter holds the whole catalog and searches it locally, so this list is
     * rebuilt only when the store's catalog or stock actually changes. What decides
     * that is a version stamp read from the data itself — the SKU count and newest
     * SKU edit, the highest ledger id, and the newest batch edit — not a clock and
     * not an in-process invalidation call.
     *
     * <p>It used to be a twelve-hour TTL dropped by an explicit invalidate. That was
     * wrong twice over. The invalidate was only wired to catalog writes, so selling a
     * strip never dropped it and the counter went on showing the pre-sale on-hand; and
     * even where it was wired, it only cleared the cache of the one JVM that served
     * the write, so on Cloud Run a second instance kept serving a stale shelf for the
     * rest of the twelve hours. A stamp read from the database is right on every
     * instance at once, which is the only kind of right that survives autoscaling.
     *
     * <p>The stamp costs four aggregates over small per-tenant tables — far less than
     * the join it guards, and it doubles as the HTTP ETag the client revalidates with.
     */
    private static final Map<String, CachedCounterList> COUNTER_CACHE = new ConcurrentHashMap<>();

    private record CachedCounterList(String version, List<CounterSku> items) {
    }

    /** A counter catalog and the stamp it was built at, for the client to cache against. */
    public record CounterCatalog(String version, List<CounterSku> items) {
    }

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
     * Edits the fields a pharmacist may correct after creation — GST (a rate
     * change lands in the market and the catalog must follow), HSN, rack,
     * schedule class and reorder levels. Identity fields (brand, strength,
     * base unit) stay immutable: changing what a SKU <em>is</em> would silently
     * re-label its entire ledger history.
     */
    @Transactional
    public SkuSummary updateSku(String skuPublicId, UpdateSkuCommand command) {
        MedicineSku sku = skuRepository.findById(skuPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Unknown SKU: " + skuPublicId));

        if (command.gstRateBp() != null) {
            if (command.gstRateBp() < 0 || command.gstRateBp() > 10000) {
                throw new IllegalArgumentException("GST rate must be between 0 and 100%");
            }
            sku.setGstRateBp(command.gstRateBp());
        }
        if (command.hsnCode() != null) {
            sku.setHsnCode(blankToNull(command.hsnCode()));
        }
        if (command.rackLocation() != null) {
            sku.setRackLocation(blankToNull(command.rackLocation()));
        }
        if (command.scheduleClass() != null) {
            sku.setScheduleClass(blankToNull(command.scheduleClass()));
        }
        if (command.reorderLevel() != null) {
            sku.setReorderLevel(command.reorderLevel() < 0 ? null : command.reorderLevel());
        }
        if (command.reorderQty() != null) {
            sku.setReorderQty(command.reorderQty() <= 0 ? null : command.reorderQty());
        }
        skuRepository.save(sku);
        return toSummary(sku);
    }

    /** Only the correctable fields; null means "leave as is", blank means "clear". */
    public record UpdateSkuCommand(
            Integer gstRateBp, String hsnCode, String rackLocation,
            String scheduleClass, Integer reorderLevel, Integer reorderQty) {
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

    /**
     * Every active product with its live on-hand and MRP, for the counter to hold
     * and search locally, plus the stamp it is current as of. Rebuilt only when that
     * stamp moves, so a keystroke costs nothing and a sale is visible at once.
     */
    @Transactional(readOnly = true)
    public CounterCatalog counterCatalog() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String version = counterVersion(schema);

        CachedCounterList cached = COUNTER_CACHE.get(schema);
        if (cached != null && cached.version().equals(version)) {
            return new CounterCatalog(version, cached.items());
        }
        List<CounterSku> items = List.copyOf(jdbcTemplate.query(
                "SELECT " + COUNTER_COLUMNS + counterFrom(schema) +
                " WHERE s.active ORDER BY lower(s.brand_name) LIMIT 5000",
                COUNTER_MAPPER));
        COUNTER_CACHE.put(schema, new CachedCounterList(version, items));
        return new CounterCatalog(version, items);
    }

    /**
     * What the counter's view of this store depends on, in one row: how many SKUs
     * exist and when one was last edited, how far the ledger has advanced, and when a
     * batch last changed. Any write that could move an on-hand, an MRP or a product's
     * details moves one of the four — the ledger is append-only, so its highest id is
     * a monotonic clock that no sale can leave behind.
     *
     * <p>The timestamps go in as epoch milliseconds, not as timestamps: this string is
     * served as an HTTP ETag, and a rendered timestamp carries a space, which RFC 7232
     * does not allow inside one. A client sent such a tag back truncated and never got
     * its 304.
     */
    private String counterVersion(String schema) {
        return jdbcTemplate.queryForObject(
                "SELECT (SELECT count(*) FROM " + schema + ".medicine_sku)" +
                " || '-' || (SELECT COALESCE(MAX(ledger_id), 0) FROM " + schema + ".stock_ledger)" +
                " || '-' || (SELECT COALESCE(MAX(EXTRACT(EPOCH FROM updated_at) * 1000), 0)::bigint" +
                "            FROM " + schema + ".medicine_sku)" +
                " || '-' || (SELECT COALESCE(MAX(EXTRACT(EPOCH FROM updated_at) * 1000), 0)::bigint" +
                "            FROM " + schema + ".batch)",
                String.class);
    }

    /** Live counter search (bypasses the cache) — on-hand and MRP as of now. */
    @Transactional(readOnly = true)
    public List<CounterSku> searchForCounter(String term, int limit) {
        if (term == null || term.isBlank()) {
            return List.of();
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String needle = term.trim().toLowerCase(Locale.ROOT);
        String prefix = escapeLike(needle) + "%";
        int cappedLimit = Math.min(Math.max(limit, 1), MAX_SEARCH_LIMIT);

        return jdbcTemplate.query(
                "WITH matched AS (" +
                "  SELECT sku_public_id, MIN(rank) AS rank FROM (" +
                "    SELECT sku_public_id, 0 AS rank FROM " + schema + ".sku_alias WHERE lower(alias) = ? " +
                "    UNION ALL " +
                "    SELECT sku_public_id, 1 FROM " + schema + ".medicine_sku WHERE lower(brand_name) LIKE ? ESCAPE '\\' " +
                "    UNION ALL " +
                "    SELECT sku_public_id, 2 FROM " + schema + ".sku_alias WHERE lower(alias) LIKE ? ESCAPE '\\' " +
                "  ) hits GROUP BY sku_public_id" +
                ") " +
                "SELECT " + COUNTER_COLUMNS + ", m.rank " +
                "FROM matched m " +
                "JOIN " + schema + ".medicine_sku s ON s.sku_public_id = m.sku_public_id " +
                "LEFT JOIN (SELECT sku_public_id, SUM(qty) AS qty FROM " + schema + ".batch_balance GROUP BY sku_public_id) oh " +
                "  ON oh.sku_public_id = s.sku_public_id " +
                "LEFT JOIN LATERAL (" +
                "  SELECT b.mrp_paise FROM " + schema + ".batch b " +
                "  JOIN " + schema + ".batch_balance bb ON bb.batch_public_id = b.batch_public_id " +
                "  WHERE b.sku_public_id = s.sku_public_id AND bb.qty > 0 " +
                "    AND b.batch_status IN ('ACTIVE', 'NEAR_EXPIRY') " +
                "  ORDER BY b.expiry_date NULLS LAST LIMIT 1" +
                ") mrp ON TRUE " +
                "WHERE s.active ORDER BY m.rank, lower(s.brand_name) LIMIT " + cappedLimit,
                COUNTER_MAPPER, needle, prefix, prefix);
    }

    private static String counterFrom(String schema) {
        return " FROM " + schema + ".medicine_sku s " +
               "LEFT JOIN (SELECT sku_public_id, SUM(qty) AS qty FROM " + schema + ".batch_balance GROUP BY sku_public_id) oh " +
               "  ON oh.sku_public_id = s.sku_public_id " +
               "LEFT JOIN LATERAL (" +
               "  SELECT b.mrp_paise FROM " + schema + ".batch b " +
               "  JOIN " + schema + ".batch_balance bb ON bb.batch_public_id = b.batch_public_id " +
               "  WHERE b.sku_public_id = s.sku_public_id AND bb.qty > 0 " +
               "    AND b.batch_status IN ('ACTIVE', 'NEAR_EXPIRY') " +
               "  ORDER BY b.expiry_date NULLS LAST LIMIT 1" +
               ") mrp ON TRUE ";
    }

    /**
     * Import a whole supplier catalog at once. Each row is a product; a row whose
     * brand (and strength) already exists is skipped, not duplicated, so re-running
     * the same file is safe. Rows that also carry a batch, quantity and MRP receive
     * opening stock through the given intake, so a new store can load its shelves in
     * one file instead of a hundred manual entries. Never partial-fails the batch: a
     * bad row is collected and reported, the good rows still land.
     */
    @Transactional
    public ImportOutcome bulkImport(List<ImportRow> rows, StockIntake intake, String actor) {
        if (rows == null || rows.isEmpty()) {
            return new ImportOutcome(0, 0, 0, 0, List.of());
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        int created = 0;
        int stocked = 0;
        int updated = 0;
        int skipped = 0;
        List<String> errors = new ArrayList<>();

        for (int i = 0; i < rows.size(); i++) {
            ImportRow row = rows.get(i);
            int lineNo = i + 1;
            try {
                if (row.brandName() == null || row.brandName().isBlank()) {
                    errors.add("Row " + lineNo + ": missing product name.");
                    continue;
                }
                String brand = row.brandName().trim();
                String strength = blankToNull(row.strength());
                String existingId = existingSkuId(schema, brand, strength);
                String skuId;
                if (existingId != null) {
                    // A refill file routinely re-lists what the store already
                    // carries — take the corrections it offers (a GST change,
                    // a new HSN or rack) instead of ignoring the whole row.
                    if (row.gstRateBp() != null || blankToNull(row.hsnCode()) != null
                            || blankToNull(row.rackLocation()) != null) {
                        updateSku(existingId, new UpdateSkuCommand(
                                row.gstRateBp(), blankToNull(row.hsnCode()),
                                blankToNull(row.rackLocation()), null, row.reorderLevel(), null));
                        updated++;
                    } else {
                        skipped++;
                    }
                    skuId = existingId;
                } else {
                    BaseUnit baseUnit = row.baseUnit() == null || row.baseUnit().isBlank()
                            ? BaseUnit.UNIT : BaseUnit.parse(row.baseUnit());
                    CreateSkuCommand command = new CreateSkuCommand(
                            brand, blankToNull(row.manufacturer()), blankToNull(row.dosageForm()), strength,
                            baseUnit, blankToNull(row.scheduleClass()), blankToNull(row.hsnCode()),
                            row.gstRateBp() == null ? 0 : row.gstRateBp(), blankToNull(row.rackLocation()),
                            row.reorderLevel(), null, null, List.of(), List.of());
                    skuId = createSku(command).skuPublicId();
                    created++;
                }
                if (intake != null && row.openingQty() != null && row.openingQty() > 0
                        && row.batchNo() != null && !row.batchNo().isBlank()) {
                    intake.receiveOpeningStock(skuId, row.batchNo().trim(), row.expiryDate(),
                            row.mrpPaise() == null ? 0 : row.mrpPaise(),
                            row.purchasePricePaise(), row.openingQty(), actor);
                    stocked++;
                }
            } catch (RuntimeException ex) {
                errors.add("Row " + lineNo + ": " + ex.getMessage());
            }
        }
        return new ImportOutcome(created, stocked, updated, skipped, List.copyOf(errors));
    }

    private String existingSkuId(String schema, String brand, String strength) {
        List<String> ids = jdbcTemplate.queryForList(
                "SELECT sku_public_id FROM " + schema + ".medicine_sku " +
                "WHERE lower(brand_name) = lower(?) " +
                "  AND (COALESCE(lower(strength), '') = COALESCE(lower(?), '')) LIMIT 1",
                String.class, brand, strength);
        return ids.isEmpty() ? null : ids.get(0);
    }

    /** One product from an imported catalog file, plus optional opening stock. */
    public record ImportRow(
            String brandName, String manufacturer, String dosageForm, String strength,
            String baseUnit, String scheduleClass, String hsnCode, Integer gstRateBp,
            String rackLocation, Integer reorderLevel,
            String batchNo, java.time.LocalDate expiryDate, Long mrpPaise, Long purchasePricePaise,
            Integer openingQty) {
    }

    public record ImportOutcome(int created, int stocked, int updated, int skipped, List<String> errors) {
    }

    /** How import puts opening stock in — a seam so catalog need not know inventory. */
    public interface StockIntake {
        void receiveOpeningStock(String skuPublicId, String batchNo, java.time.LocalDate expiryDate,
                                 long mrpPaise, Long purchasePricePaise, int qtyBaseUnits, String actor);
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
