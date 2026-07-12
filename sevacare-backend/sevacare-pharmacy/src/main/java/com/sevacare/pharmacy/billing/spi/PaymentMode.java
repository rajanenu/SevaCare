package com.sevacare.pharmacy.billing.spi;

/**
 * How a sale was tendered. {@code CREDIT} is a real answer at an Indian counter —
 * the regular customer who "will pay at month-end" — and recording it is what
 * keeps the day-close honest instead of hiding an IOU inside the cash figure.
 */
public enum PaymentMode {
    CASH,
    UPI,
    CARD,
    CREDIT,
    OTHER;

    public static PaymentMode parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return CASH;
        }
        try {
            return valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return OTHER;
        }
    }
}
