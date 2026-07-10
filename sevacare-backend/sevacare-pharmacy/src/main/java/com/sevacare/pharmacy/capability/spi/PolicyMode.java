package com.sevacare.pharmacy.capability.spi;

/**
 * Every rule in the pharmacy is one of these three, and never a boolean.
 *
 * <p>The middle value is the reason the model exists. A hospital that switches a
 * rule on before its staff are ready gets paper workarounds, and paper logs
 * nothing. {@code SUGGEST} lets the work continue, records the skip, and turns
 * "are they following the rule?" into a number the owner can watch fall. Real
 * digitisation ratchets OFF → SUGGEST → ENFORCE; software that only offers the
 * ends of that range gets switched off at the first busy afternoon.
 */
public enum PolicyMode {

    /** The rule does not exist. Nothing is checked, nothing is recorded. */
    OFF,

    /** The rule is advice. The user may proceed with one keystroke; the skip is recorded. */
    SUGGEST,

    /** The rule is a gate. The action fails. */
    ENFORCE;

    public boolean isEnforced() {
        return this == ENFORCE;
    }

    /** Lenient by design: an unreadable stored value must not decide a money path. */
    public static PolicyMode parse(String raw, PolicyMode fallback) {
        if (raw == null) {
            return fallback;
        }
        try {
            return valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return fallback;
        }
    }
}
