package com.sevacare.pharmacy.catalog.spi;

/**
 * The atom the stock ledger counts for a SKU. Everything above it — strip, box —
 * is a multiple held in {@code sku_pack} and used only for display and entry.
 *
 * <p>Counting in base units is what makes selling four tablets out of a strip of
 * ten ordinary arithmetic. Systems that count strips end up with 0.4 of a strip
 * in a numeric column, and then with 0.39999999999999997.
 */
public enum BaseUnit {
    TABLET,
    CAPSULE,
    ML,
    GM,
    /** Surgical items, devices, anything counted by the piece. */
    UNIT;

    public static BaseUnit parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return UNIT;
        }
        try {
            return valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return UNIT;
        }
    }
}
