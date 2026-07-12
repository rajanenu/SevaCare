package com.sevacare.api.pharmacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import com.sevacare.pharmacy.billing.service.CounterSaleService;
import com.sevacare.pharmacy.billing.service.CreateSaleCommand;
import com.sevacare.pharmacy.billing.service.CreditService;
import com.sevacare.pharmacy.billing.spi.CreditOutstanding;
import com.sevacare.pharmacy.billing.spi.PaymentMode;
import com.sevacare.pharmacy.billing.spi.SaleReceipt;
import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.inventory.service.CreateBatchCommand;
import com.sevacare.pharmacy.inventory.service.InventoryService;
import com.sevacare.pharmacy.inventory.spi.StockLedger;
import com.sevacare.pharmacy.procurement.service.GrnService;
import com.sevacare.pharmacy.procurement.service.PostGrnCommand;
import com.sevacare.pharmacy.returns.service.CustomerReturnService;
import com.sevacare.pharmacy.returns.service.PostReturnCommand;

/**
 * The khata's arithmetic proven against real Postgres — outstanding must equal
 * credit sales minus refunds minus repayments, with nothing stored — and the
 * refill-file import path: a re-listed medicine gets its corrections and its
 * stock, not a silent skip.
 */
class CreditAndImportIntegrationTest extends PharmacyIntegrationTestBase {

    private static final String MOBILE = "9888877665";

    @Autowired private CounterSaleService counterSale;
    @Autowired private CreditService credit;
    @Autowired private CustomerReturnService returns;
    @Autowired private CatalogService catalog;
    @Autowired private GrnService grn;
    @Autowired private InventoryService inventory;
    @Autowired private StockLedger stockLedger;

    // ---- Khata --------------------------------------------------------------

    @Test
    void outstanding_is_credit_sales_minus_refunds_minus_payments() {
        String sku = newSku("Dolo 650", 1200);
        receive(sku, "B1", 100, 500L);

        SaleReceipt bill = counterSale.sell(creditSale(sku, 20)); // 20 × ₹5 = ₹100
        long total = bill.totalPaise();
        assertThat(total).isEqualTo(10_000L);

        CreditOutstanding owes = credit.outstandingFor(MOBILE);
        assertThat(owes.outstandingPaise()).isEqualTo(total);
        assertThat(owes.customerName()).isEqualTo("Ravi");

        // Part-payment at the counter.
        credit.recordPayment(MOBILE, 3_000L, "UPI", null, "tester");

        // A return against the credit bill also reduces what is owed.
        String batch = bill.lines().get(0).batchPublicId();
        returns.post(new PostReturnCommand(bill.salePublicId(), "CASH", null, "tester",
                List.of(new PostReturnCommand.LineRequest(sku, batch, 4, "RESTOCK")))); // ₹20 back

        owes = credit.outstandingFor(MOBILE);
        assertThat(owes.outstandingPaise()).isEqualTo(10_000L - 3_000L - 2_000L);
        assertThat(credit.outstanding()).extracting(CreditOutstanding::customerMobile).contains(MOBILE);

        // Paying more than the dues is a typo, not a tip.
        assertThatThrownBy(() -> credit.recordPayment(MOBILE, 5_001L, "CASH", null, "tester"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("owes");

        // Settling exactly clears the khata.
        credit.recordPayment(MOBILE, 5_000L, "CASH", null, "tester");
        assertThat(credit.outstanding()).isEmpty();
    }

    @Test
    void a_voided_credit_sale_never_reaches_the_khata() {
        String sku = newSku("Pantop 40", 1200);
        receive(sku, "P1", 50, 300L);

        SaleReceipt bill = counterSale.sell(creditSale(sku, 10));
        assertThat(credit.outstandingFor(MOBILE).outstandingPaise()).isEqualTo(bill.totalPaise());

        counterSale.voidSale(bill.salePublicId(), "owner");
        assertThat(credit.outstanding()).isEmpty();
    }

    // ---- Refill-file import -------------------------------------------------

    @Test
    void importing_an_existing_medicine_updates_gst_and_receives_stock() {
        CatalogService.StockIntake intake = (skuId, batchNo, expiry, mrpPaise, cost, qty, actor) ->
                inventory.receiveStock(new CreateBatchCommand(skuId, batchNo, expiry, mrpPaise, cost, null), qty, actor);

        // First file creates the medicine at 5% GST with opening stock.
        CatalogService.ImportOutcome first = catalog.bulkImport(List.of(
                new CatalogService.ImportRow("Cetiriz 10", null, "TABLET", "10mg", "TABLET",
                        null, null, 500, null, null, "C1", LocalDate.now().plusYears(1), 200L, null, 30)),
                intake, "tester");
        assertThat(first.created()).isEqualTo(1);
        assertThat(first.stocked()).isEqualTo(1);
        assertThat(first.updated()).isZero();

        String skuId = jdbcTemplate.queryForObject(
                "SELECT sku_public_id FROM " + TENANT_SCHEMA + ".medicine_sku WHERE brand_name = 'Cetiriz 10'",
                String.class);
        assertThat(stockLedger.balanceOf(skuId, COUNTER)).isEqualTo(30);

        // The supplier's next file re-lists it — GST corrected to 12%, more stock.
        CatalogService.ImportOutcome second = catalog.bulkImport(List.of(
                new CatalogService.ImportRow("cetiriz 10", null, "TABLET", "10mg", "TABLET",
                        null, "3004", 1200, null, null, "C2", LocalDate.now().plusYears(1), 220L, null, 50)),
                intake, "tester");
        assertThat(second.created()).isZero();
        assertThat(second.updated()).isEqualTo(1);
        assertThat(second.stocked()).isEqualTo(1);
        assertThat(second.errors()).isEmpty();

        Integer gst = jdbcTemplate.queryForObject(
                "SELECT gst_rate_bp FROM " + TENANT_SCHEMA + ".medicine_sku WHERE sku_public_id = ?",
                Integer.class, skuId);
        assertThat(gst).isEqualTo(1200);
        assertThat(stockLedger.balanceOf(skuId, COUNTER)).isEqualTo(80);
    }

    // ---- helpers -----------------------------------------------------------

    private String newSku(String brand, int gstBp) {
        return catalog.createSku(new CreateSkuCommand(
                brand, "Acme", "TABLET", "500mg", BaseUnit.TABLET, null, "3004", gstBp,
                "R1", null, null, null,
                List.of(new CreateSkuCommand.PackLevel("STRIP", 10, true)), List.of()))
                .skuPublicId();
    }

    private void receive(String sku, String batchNo, int qty, long mrpPaise) {
        grn.post(new PostGrnCommand(null, null, null, null, "tester",
                List.of(new PostGrnCommand.LineRequest(
                        sku, batchNo, LocalDate.now().plusYears(1), qty, 0, mrpPaise, null))));
    }

    private CreateSaleCommand creditSale(String sku, int qty) {
        return new CreateSaleCommand("Ravi", MOBILE, null, PaymentMode.CREDIT, "tester", null,
                List.of(new CreateSaleCommand.LineRequest(sku, qty, null, null, null, null, null)));
    }
}
