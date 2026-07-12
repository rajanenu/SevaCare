package com.sevacare.pharmacy.billing.spi;

import java.time.Instant;
import java.time.LocalDate;

/**
 * The owner's day, in money (blueprint §11.2). Everything the day-close needs on
 * one object: the sales summary, the true cost of what left the shelf (batch
 * purchase cost, scheme-adjusted at GRN time), refunds that left the drawer, and
 * what cash should therefore be in it.
 *
 * <p>{@code marginPaise} is takings minus cost of goods for the day's sales.
 * {@code unknownCostLines} counts sale lines whose batch has no recorded
 * purchase price — margin is honest about what it doesn't know rather than
 * silently treating unknown cost as zero profit or full profit.
 */
public record MoneyView(
        DaySummary summary,
        long costPaise,
        long marginPaise,
        int unknownCostLines,
        long refundsPaise,
        long cashRefundsPaise,
        long expectedCashPaise,
        DayCloseInfo dayClose) {

    /** Present once the day has been closed; null while the drawer is open. */
    public record DayCloseInfo(
            LocalDate closeDate,
            long expectedCashPaise,
            long countedCashPaise,
            long variancePaise,
            String note,
            String closedBy,
            Instant closedAt) {
    }
}
