package com.sevacare.api.pharmacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import com.sevacare.pharmacy.billing.service.CounterSaleService;
import com.sevacare.pharmacy.billing.service.CreateSaleCommand;
import com.sevacare.pharmacy.billing.service.SaleQueryService;
import com.sevacare.pharmacy.billing.spi.DaySummary;
import com.sevacare.pharmacy.billing.spi.PaymentMode;
import com.sevacare.pharmacy.billing.spi.SaleReceipt;
import com.sevacare.pharmacy.capability.service.CapabilityPolicyService;
import com.sevacare.pharmacy.capability.spi.PolicyKey;
import com.sevacare.pharmacy.capability.spi.PolicyMode;
import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.inventory.service.CreateBatchCommand;
import com.sevacare.pharmacy.inventory.service.InventoryService;
import com.sevacare.pharmacy.inventory.spi.StockLedger;

/**
 * The counter sale, proven against real Postgres: MRP-inclusive GST maths, FEFO
 * across batches, the policy knobs that decide whether a sale warns or refuses,
 * and the day-close. What these assert is that the receipt the customer is handed
 * and the stock that left the shelf are the same transaction — never one without
 * the other.
 */
class CounterSaleIntegrationTest extends PharmacyIntegrationTestBase {

    @Autowired private CounterSaleService counterSale;
    @Autowired private SaleQueryService saleQuery;
    @Autowired private CatalogService catalog;
    @Autowired private InventoryService inventory;
    @Autowired private StockLedger stockLedger;
    @Autowired private CapabilityPolicyService policies;

    @Test
    void gst_is_backed_out_of_the_mrp_not_added_to_it() {
        // ₹105.00 inclusive at 5% is ₹100.00 taxable + ₹5.00 GST.
        assertThat(CounterSaleService.taxableFromInclusive(10_500L, 500)).isEqualTo(10_000L);
        // 12% on a ₹56.00 line: 5000 taxable + 600 gst reconstruct the 5600 exactly.
        assertThat(CounterSaleService.taxableFromInclusive(5_600L, 1200)).isEqualTo(5_000L);
        // Zero-rated goods: the whole amount is taxable value, no GST.
        assertThat(CounterSaleService.taxableFromInclusive(9_999L, 0)).isEqualTo(9_999L);
    }

    @Test
    void a_sale_draws_stock_and_the_receipt_totals_reconcile() {
        String sku = newSku("Dolo 650", 1200, null);   // 12% GST
        String batch = newBatch(sku, "B1", LocalDate.now().plusYears(1), 500L); // MRP ₹5.00/tablet
        inventory.receiveStock(new CreateBatchCommand(sku, "B1", LocalDate.now().plusYears(1), 500L, 400L, null),
                100, "tester");

        SaleReceipt receipt = counterSale.sell(sale(line(sku, 10)));

        assertThat(receipt.invoiceNo()).isEqualTo("INV-000001");
        assertThat(receipt.grossPaise()).isEqualTo(5_000L);           // 10 * ₹5.00
        assertThat(receipt.totalPaise()).isEqualTo(5_000L);
        assertThat(receipt.taxablePaise() + receipt.gstPaise()).isEqualTo(receipt.grossPaise());
        assertThat(receipt.gstPaise()).isEqualTo(536L);               // 12% backed out of 5000
        assertThat(receipt.lines()).hasSize(1);
        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isEqualTo(90);
    }

    @Test
    void fefo_spends_the_earliest_expiry_first_and_splits_across_batches() {
        String sku = newSku("Azithral 500", 500, null);
        String soon = newBatch(sku, "SOON", LocalDate.now().plusMonths(2), 1000L);
        String later = newBatch(sku, "LATER", LocalDate.now().plusMonths(9), 1000L);
        inventory.receiveStock(new CreateBatchCommand(sku, "SOON", LocalDate.now().plusMonths(2), 1000L, null, null), 6, "t");
        inventory.receiveStock(new CreateBatchCommand(sku, "LATER", LocalDate.now().plusMonths(9), 1000L, null, null), 10, "t");

        SaleReceipt receipt = counterSale.sell(sale(line(sku, 8)));

        // Two batch lines: the soon-to-expire batch emptied first, remainder from later.
        assertThat(receipt.lines()).hasSize(2);
        assertThat(stockLedger.balanceOfBatch(soon, COUNTER)).isEqualTo(0);
        assertThat(stockLedger.balanceOfBatch(later, COUNTER)).isEqualTo(8);
    }

    @Test
    void a_schedule_h_medicine_without_a_prescriber_warns_but_sells_at_the_default() {
        String sku = newSku("Augmentin 625", 1200, "H");
        inventory.receiveStock(new CreateBatchCommand(sku, "H1", LocalDate.now().plusYears(1), 20000L, null, null), 30, "t");

        SaleReceipt receipt = counterSale.sell(sale(line(sku, 10)));

        assertThat(receipt.warnings()).anyMatch(w -> w.contains("Schedule H"));
        assertThat(receipt.totalPaise()).isEqualTo(200_000L);
    }

    @Test
    void a_schedule_h_medicine_is_refused_without_a_prescriber_under_enforce() {
        policies.setTenantOverride(PolicyKey.RX_REQUIRED_FOR_SCHEDULE_H, PolicyMode.ENFORCE, "owner");
        String sku = newSku("Augmentin 625", 1200, "H");
        inventory.receiveStock(new CreateBatchCommand(sku, "H1", LocalDate.now().plusYears(1), 20000L, null, null), 30, "t");

        assertThatThrownBy(() -> counterSale.sell(sale(line(sku, 5))))
                .hasMessageContaining("prescriber");
        // Nothing left the shelf: the refusal took the whole transaction down.
        assertThat(saleQuery.recentSales(10)).isEmpty();
    }

    @Test
    void an_expired_batch_can_never_be_dispensed_even_when_named() {
        String sku = newSku("Old Syrup", 500, null);
        // Received already expired: it lands as EXPIRED and is unsellable from arrival.
        inventory.receiveStock(new CreateBatchCommand(sku, "X1", LocalDate.now().minusDays(1), 1000L, null, null), 10, "t");
        String expiredBatch = "BAT-000001";

        assertThatThrownBy(() -> counterSale.sell(sale(
                new CreateSaleCommand.LineRequest(sku, 2, expiredBatch, null, null, null, null))))
                .hasMessageContaining("cannot be dispensed");
    }

    @Test
    void selling_beyond_stock_warns_and_goes_negative_at_suggest_but_refuses_at_enforce() {
        String sku = newSku("Limited", 500, null);
        String batch = newBatch(sku, "L1", LocalDate.now().plusYears(1), 500L);
        inventory.receiveStock(new CreateBatchCommand(sku, "L1", LocalDate.now().plusYears(1), 500L, null, null), 3, "t");

        SaleReceipt receipt = counterSale.sell(sale(line(sku, 5)));
        assertThat(receipt.warnings()).anyMatch(w -> w.contains("beyond recorded stock"));
        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isEqualTo(-2);

        policies.setTenantOverride(PolicyKey.NEGATIVE_STOCK, PolicyMode.ENFORCE, "owner");
        // Put real stock on the shelf (-2 + 5 = 3), then ask for far more: the
        // shortfall is now a genuine oversell of stock that exists, and ENFORCE
        // refuses it rather than let the balance go negative.
        inventory.receiveStock(new CreateBatchCommand(sku, "L1", LocalDate.now().plusYears(1), 500L, null, null), 5, "t");
        assertThatThrownBy(() -> counterSale.sell(sale(line(sku, 100))))
                .hasMessageContaining("in stock");
    }

    @Test
    void the_day_close_splits_takings_by_tender() {
        String sku = newSku("Paracetamol", 500, null);
        inventory.receiveStock(new CreateBatchCommand(sku, "P1", LocalDate.now().plusYears(1), 1000L, null, null), 100, "t");

        counterSale.sell(sale(PaymentMode.CASH, line(sku, 5)));   // ₹50.00
        counterSale.sell(sale(PaymentMode.UPI, line(sku, 3)));    // ₹30.00
        counterSale.sell(sale(PaymentMode.CASH, line(sku, 2)));   // ₹20.00

        DaySummary summary = saleQuery.daySummary(LocalDate.now());
        assertThat(summary.saleCount()).isEqualTo(3);
        assertThat(summary.totalPaise()).isEqualTo(10_000L);

        long cash = summary.byPaymentMode().stream()
                .filter(p -> p.paymentMode() == PaymentMode.CASH).mapToLong(DaySummary.PaymentTotal::totalPaise).sum();
        long upi = summary.byPaymentMode().stream()
                .filter(p -> p.paymentMode() == PaymentMode.UPI).mapToLong(DaySummary.PaymentTotal::totalPaise).sum();
        assertThat(cash).isEqualTo(7_000L);
        assertThat(upi).isEqualTo(3_000L);
    }

    // ---- helpers --------------------------------------------------------

    private String newSku(String brand, int gstBp, String scheduleClass) {
        return catalog.createSku(new CreateSkuCommand(
                brand, "Acme", "TABLET", "500mg", BaseUnit.TABLET, scheduleClass, "3004", gstBp,
                "R1", null, null, null,
                List.of(new CreateSkuCommand.PackLevel("STRIP", 10, true)), List.of()))
                .skuPublicId();
    }

    private String newBatch(String sku, String batchNo, LocalDate expiry, long mrpPaise) {
        return inventory.findOrCreateBatch(new CreateBatchCommand(sku, batchNo, expiry, mrpPaise, null, null));
    }

    private CreateSaleCommand.LineRequest line(String sku, int qty) {
        return new CreateSaleCommand.LineRequest(sku, qty, null, null, null, null, null);
    }

    private CreateSaleCommand sale(CreateSaleCommand.LineRequest... lines) {
        return sale(PaymentMode.CASH, lines);
    }

    private CreateSaleCommand sale(PaymentMode mode, CreateSaleCommand.LineRequest... lines) {
        return new CreateSaleCommand(null, null, null, mode, "tester", null, List.of(lines));
    }
}
