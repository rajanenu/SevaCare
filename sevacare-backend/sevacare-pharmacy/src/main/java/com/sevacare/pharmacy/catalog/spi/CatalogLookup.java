package com.sevacare.pharmacy.catalog.spi;

import java.util.List;
import java.util.Optional;

/**
 * Read-only catalog access for other contexts. Writes happen in Catalog, in
 * response to a user or to a domain event — never by a sibling reaching in.
 */
public interface CatalogLookup {

    Optional<SkuSummary> findSku(String skuPublicId);

    /**
     * The counter's search: brand name or learned alias, prefix-matched. Ranked
     * exact-alias first (a scanned barcode must win), then brand prefix.
     *
     * <p>Free text that resolves to nothing is not an error — it is a SKU this
     * pharmacy does not stock, which is a fact worth capturing rather than a
     * validation failure.
     */
    List<SkuSummary> search(String term, int limit);

    /** Resolves a scanned barcode, which is stored as an alias of kind BARCODE. */
    Optional<SkuSummary> findByBarcode(String barcode);
}
