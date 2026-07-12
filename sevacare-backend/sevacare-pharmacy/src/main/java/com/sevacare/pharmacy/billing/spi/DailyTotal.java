package com.sevacare.pharmacy.billing.spi;

import java.time.LocalDate;

/** One point on the sales-trend line chart: a calendar day's takings and bill count. */
public record DailyTotal(LocalDate saleDate, long totalPaise, int saleCount) {
}
