package com.sevacare.api.pharmacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import com.sevacare.pharmacy.billing.service.CounterSaleService;
import com.sevacare.pharmacy.billing.service.CreateSaleCommand;
import com.sevacare.pharmacy.billing.service.DayCloseService;
import com.sevacare.pharmacy.billing.spi.MoneyView;
import com.sevacare.pharmacy.billing.spi.PaymentMode;
import com.sevacare.pharmacy.billing.spi.SaleReceipt;
import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.inventory.spi.StockLedger;
import com.sevacare.pharmacy.procurement.service.GrnService;
import com.sevacare.pharmacy.procurement.service.PostGrnCommand;
import com.sevacare.pharmacy.procurement.service.SupplierService;
import com.sevacare.pharmacy.procurement.spi.PostedGrn;
import com.sevacare.pharmacy.procurement.spi.SupplierInfo;
import com.sevacare.pharmacy.returns.service.CustomerReturnService;
import com.sevacare.pharmacy.returns.service.PostReturnCommand;
import com.sevacare.pharmacy.returns.spi.PostedReturn;
import com.sevacare.pharmacy.returns.spi.ReturnableLine;

/**
 * The rest of the store's day, proven against real Postgres: a delivery posted
 * as one GRN document (scheme quantities included), a customer return that puts
 * stock back — or quarantines it — against the original bill, and the day-close
 * that counts the drawer against what the system expected.
 */
class StoreOperationsIntegrationTest extends PharmacyIntegrationTestBase {

    @Autowired private SupplierService suppliers;
    @Autowired private GrnService grn;
    @Autowired private CustomerReturnService returns;
    @Autowired private DayCloseService dayClose;
    @Autowired private CounterSaleService counterSale;
    @Autowired private CatalogService catalog;
    @Autowired private StockLedger stockLedger;

    // ---- Suppliers --------------------------------------------------------

    @Test
    void adding_the_same_supplier_twice_returns_one_record() {
        SupplierInfo first = suppliers.createOrGet("Sri Balaji Agencies", "9000000001", null, null, "Kadapa", 60);
        SupplierInfo second = suppliers.createOrGet("  sri balaji agencies ", null, null, null, null, null);

        assertThat(second.supplierPublicId()).isEqualTo(first.supplierPublicId());
        assertThat(suppliers.listActive()).hasSize(1);
    }

    // ---- GRN ---------------------------------------------------------------

    @Test
    void a_grn_posts_batches_ledger_rows_and_the_document_together() {
        String sku1 = newSku("Dolo 650", 1200);
        String sku2 = newSku("Azithral 500", 1200);
        SupplierInfo supplier = suppliers.createOrGet("MedPlus Distributors", null, null, null, null, 90);

        PostedGrn posted = grn.post(new PostGrnCommand(
                supplier.supplierPublicId(), "INV-4711", LocalDate.now(), null, "tester",
                List.of(
                        new PostGrnCommand.LineRequest(sku1, "D1", LocalDate.now().plusYears(1), 100, 10, 200L, 150L),
                        new PostGrnCommand.LineRequest(sku2, "A7", LocalDate.now().plusMonths(8), 30, 0, 900L, 700L))));

        assertThat(posted.grnPublicId()).startsWith("GRN-");
        assertThat(posted.lineCount()).isEqualTo(2);
        assertThat(posted.totalQtyBase()).isEqualTo(140);           // 100+10 free + 30
        assertThat(posted.totalCostPaise()).isEqualTo(100 * 150L + 30 * 700L);

        // Stock landed through the ledger: 110 units of sku1, 30 of sku2.
        assertThat(stockLedger.balanceOf(sku1, COUNTER)).isEqualTo(110);
        assertThat(stockLedger.balanceOf(sku2, COUNTER)).isEqualTo(30);

        // The "10+1" scheme lowered the effective unit cost below the invoice price.
        Long effectiveCost = jdbcTemplate.queryForObject(
                "SELECT purchase_price_paise FROM " + TENANT_SCHEMA + ".batch WHERE batch_public_id = ?",
                Long.class, posted.lines().get(0).batchPublicId());
        assertThat(effectiveCost).isEqualTo((100 * 150L + 55) / 110);
    }

    @Test
    void a_grn_with_no_supplier_and_no_invoice_still_posts() {
        String sku = newSku("Loose Carton", 500);
        PostedGrn posted = grn.post(new PostGrnCommand(null, null, null, null, "tester",
                List.of(new PostGrnCommand.LineRequest(sku, "L1", LocalDate.now().plusYears(1), 20, 0, 100L, null))));

        assertThat(posted.lineCount()).isEqualTo(1);
        assertThat(stockLedger.balanceOf(sku, COUNTER)).isEqualTo(20);
        assertThat(grn.recentGrns(10)).hasSize(1);
    }

    // ---- Customer returns --------------------------------------------------

    @Test
    void a_full_line_return_refunds_exactly_what_was_paid_and_restocks() {
        String sku = newSku("Pantop 40", 1200);
        receive(sku, "P1", 50, 300L, 200L);

        SaleReceipt sale = counterSale.sell(sale(PaymentMode.CASH, line(sku, 10)));
        long paid = sale.totalPaise();
        assertThat(stockLedger.balanceOf(sku, COUNTER)).isEqualTo(40);

        List<ReturnableLine> returnable = returns.returnableLines(sale.salePublicId());
        assertThat(returnable).hasSize(1);
        assertThat(returnable.get(0).qtyReturnable()).isEqualTo(10);

        PostedReturn posted = returns.post(new PostReturnCommand(
                sale.salePublicId(), "CASH", "customer changed mind", "tester",
                List.of(new PostReturnCommand.LineRequest(
                        sku, returnable.get(0).batchPublicId(), 10, "RESTOCK"))));

        assertThat(posted.refundPaise()).isEqualTo(paid);
        assertThat(stockLedger.balanceOf(sku, COUNTER)).isEqualTo(50);
        // And the bill can not be returned twice.
        assertThat(returns.returnableLines(sale.salePublicId()).get(0).qtyReturnable()).isZero();
    }

    @Test
    void a_quarantined_return_never_lands_back_on_the_counter() {
        String sku = newSku("ColdChain Amp", 1200);
        receive(sku, "C1", 10, 5000L, null);
        SaleReceipt sale = counterSale.sell(sale(PaymentMode.UPI, line(sku, 2)));

        String batch = returns.returnableLines(sale.salePublicId()).get(0).batchPublicId();
        returns.post(new PostReturnCommand(sale.salePublicId(), "UPI", "opened", "tester",
                List.of(new PostReturnCommand.LineRequest(sku, batch, 2, "QUARANTINE"))));

        assertThat(stockLedger.balanceOf(sku, COUNTER)).isEqualTo(8);
        assertThat(stockLedger.balanceOf(sku, "QUARANTINE")).isEqualTo(2);
    }

    @Test
    void over_returning_a_line_is_refused() {
        String sku = newSku("Limitest", 500);
        receive(sku, "L1", 20, 100L, null);
        SaleReceipt sale = counterSale.sell(sale(PaymentMode.CASH, line(sku, 3)));
        String batch = returns.returnableLines(sale.salePublicId()).get(0).batchPublicId();

        assertThatThrownBy(() -> returns.post(new PostReturnCommand(
                sale.salePublicId(), "CASH", null, "tester",
                List.of(new PostReturnCommand.LineRequest(sku, batch, 4, "RESTOCK")))))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("only 3");
    }

    // ---- Money view & day-close --------------------------------------------

    @Test
    void the_money_view_knows_margin_refunds_and_expected_cash() {
        String sku = newSku("Marginal 10", 0);           // GST 0 keeps the arithmetic visible
        receive(sku, "M1", 100, 1000L, 600L);            // sells at ₹10, costs ₹6

        counterSale.sell(sale(PaymentMode.CASH, line(sku, 10)));   // ₹100 cash
        SaleReceipt upiSale = counterSale.sell(sale(PaymentMode.UPI, line(sku, 5))); // ₹50 UPI

        String batch = returns.returnableLines(upiSale.salePublicId()).get(0).batchPublicId();
        returns.post(new PostReturnCommand(upiSale.salePublicId(), "CASH", null, "tester",
                List.of(new PostReturnCommand.LineRequest(sku, batch, 1, "RESTOCK")))); // ₹10 cash out

        MoneyView view = dayClose.moneyView(LocalDate.now());
        assertThat(view.summary().totalPaise()).isEqualTo(15_000L);
        assertThat(view.costPaise()).isEqualTo(15 * 600L);
        assertThat(view.refundsPaise()).isEqualTo(1_000L);
        assertThat(view.cashRefundsPaise()).isEqualTo(1_000L);
        // Drawer: ₹100 cash in, ₹10 cash refund out.
        assertThat(view.expectedCashPaise()).isEqualTo(9_000L);
        // Margin: takings 150 − refunds 10 − cost 90 = ₹50.
        assertThat(view.marginPaise()).isEqualTo(5_000L);
        assertThat(view.unknownCostLines()).isZero();
        assertThat(view.dayClose()).isNull();
    }

    @Test
    void closing_the_day_records_the_variance_and_refuses_a_second_close() {
        String sku = newSku("Closer", 0);
        receive(sku, "C1", 10, 500L, null);
        counterSale.sell(sale(PaymentMode.CASH, line(sku, 4)));    // ₹20 expected in drawer

        MoneyView closed = dayClose.close(LocalDate.now(), 1_900L, "one coin short", "owner");

        assertThat(closed.dayClose()).isNotNull();
        assertThat(closed.dayClose().expectedCashPaise()).isEqualTo(2_000L);
        assertThat(closed.dayClose().countedCashPaise()).isEqualTo(1_900L);
        assertThat(closed.dayClose().variancePaise()).isEqualTo(-100L);
        assertThat(closed.dayClose().closedBy()).isEqualTo("owner");

        assertThatThrownBy(() -> dayClose.close(LocalDate.now(), 2_000L, null, "owner"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("already closed");
    }

    // ---- helpers -----------------------------------------------------------

    private String newSku(String brand, int gstBp) {
        return catalog.createSku(new CreateSkuCommand(
                brand, "Acme", "TABLET", "500mg", BaseUnit.TABLET, null, "3004", gstBp,
                "R1", null, null, null,
                List.of(new CreateSkuCommand.PackLevel("STRIP", 10, true)), List.of()))
                .skuPublicId();
    }

    private void receive(String sku, String batchNo, int qty, long mrpPaise, Long costPaise) {
        grn.post(new PostGrnCommand(null, null, null, null, "tester",
                List.of(new PostGrnCommand.LineRequest(
                        sku, batchNo, LocalDate.now().plusYears(1), qty, 0, mrpPaise, costPaise))));
    }

    private CreateSaleCommand.LineRequest line(String sku, int qty) {
        return new CreateSaleCommand.LineRequest(sku, qty, null, null, null, null, null);
    }

    private CreateSaleCommand sale(PaymentMode mode, CreateSaleCommand.LineRequest... lines) {
        return new CreateSaleCommand(null, null, null, mode, "tester", null, List.of(lines));
    }
}
