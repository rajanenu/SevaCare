/**
 * Supporting context: Capability.
 *
 * <p>Answers one question for every other context: "how strict are we about this,
 * here, today?" Resolution runs platform default → capability profile → tenant
 * override, most specific wins (blueprint §10.1). The location and role layers
 * arrive with multi-location in Phase 3; nothing below assumes they never will.
 *
 * <p>This is not a bounded context in the domain sense — it owns no business
 * nouns — but it is packaged as one so the {@code spi} boundary applies to it
 * too. Every context reads policy; none of them may read the config table.
 */
package com.sevacare.pharmacy.capability;
