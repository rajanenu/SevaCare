package com.sevacare.api.pharmacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;

import com.sevacare.pharmacy.capability.service.CapabilityPolicyService;
import com.sevacare.pharmacy.capability.spi.PolicyKey;
import com.sevacare.pharmacy.capability.spi.PolicyMode;
import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.inventory.service.CreateBatchCommand;
import com.sevacare.pharmacy.inventory.service.InventoryService;
import com.sevacare.pharmacy.inventory.service.StockLedgerService;
import com.sevacare.pharmacy.inventory.spi.BatchAllocation;
import com.sevacare.pharmacy.inventory.spi.InsufficientStockException;
import com.sevacare.pharmacy.inventory.spi.InventoryEvents;
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.shared.tenant.TenantContext;

class StockLedgerIntegrationTest extends PharmacyIntegrationTestBase {

    @Autowired
    private StockLedgerService stockLedger;

    @Autowired
    private InventoryService inventory;

    @Autowired
    private CatalogService catalog;

    @Autowired
    private CapabilityPolicyService policies;

    @Test
    void a_receipt_and_a_loose_sale_leave_the_ledger_and_the_balance_agreeing() {
        String sku = newSku("Dolo 650");
        String batch = newBatch(sku, "B1", LocalDate.now().plusYears(1));

        stockLedger.append(movement(sku, batch, 100, MovementReason.GRN));
        // Four tablets out of a strip of ten: the commonest operation at an Indian
        // counter, and ordinary arithmetic only because the ledger counts tablets.
        stockLedger.append(movement(sku, batch, -4, MovementReason.SALE));

        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isEqualTo(96);
        assertThat(ledgerSum(batch)).isEqualTo(96);
        assertThat(ledgerRowCount()).isEqualTo(2);
    }

    /**
     * The claim that {@code batch_balance} is a cache and the ledger is the truth
     * is only worth making if the cache can actually be discarded and rebuilt.
     */
    @Test
    void every_balance_can_be_rebuilt_from_the_ledger_alone() {
        String sku = newSku("Azithral 500");
        String batchA = newBatch(sku, "A1", LocalDate.now().plusMonths(6));
        String batchB = newBatch(sku, "B2", LocalDate.now().plusMonths(9));

        stockLedger.append(movement(sku, batchA, 30, MovementReason.GRN));
        stockLedger.append(movement(sku, batchB, 20, MovementReason.GRN));
        stockLedger.append(movement(sku, batchA, -7, MovementReason.SALE));
        stockLedger.append(movement(sku, batchB, 3, MovementReason.RETURN_IN));

        long beforeA = stockLedger.balanceOfBatch(batchA, COUNTER);
        long beforeB = stockLedger.balanceOfBatch(batchB, COUNTER);

        stockLedger.rebuildBalancesFromLedger();

        assertThat(stockLedger.balanceOfBatch(batchA, COUNTER)).isEqualTo(beforeA).isEqualTo(23);
        assertThat(stockLedger.balanceOfBatch(batchB, COUNTER)).isEqualTo(beforeB).isEqualTo(23);
    }

    @Test
    void the_ledger_cannot_be_edited_or_deleted() {
        String sku = newSku("Crocin");
        String batch = newBatch(sku, "C1", LocalDate.now().plusYears(1));
        long ledgerId = stockLedger.append(movement(sku, batch, 10, MovementReason.GRN));

        assertThatThrownBy(() -> jdbcTemplate.update(
                "UPDATE " + TENANT_SCHEMA + ".stock_ledger SET qty_delta = 9999 WHERE ledger_id = ?", ledgerId))
                .hasMessageContaining("append-only");

        assertThatThrownBy(() -> jdbcTemplate.update(
                "DELETE FROM " + TENANT_SCHEMA + ".stock_ledger WHERE ledger_id = ?", ledgerId))
                .hasMessageContaining("append-only");

        assertThat(ledgerRowCount()).isEqualTo(1);
    }

    /**
     * The tripwire. Someone will eventually write "quick fix: UPDATE the balance";
     * this is the test that stops it, and it fails at the database rather than at
     * a code review.
     */
    @Test
    void the_balance_cannot_be_written_outside_the_ledger_append_path() {
        String sku = newSku("Shelcal");
        String batch = newBatch(sku, "S1", LocalDate.now().plusYears(2));
        stockLedger.append(movement(sku, batch, 50, MovementReason.GRN));

        assertThatThrownBy(() -> jdbcTemplate.update(
                "UPDATE " + TENANT_SCHEMA + ".batch_balance SET qty = 9999 WHERE batch_public_id = ?", batch))
                .hasMessageContaining("cannot be written directly");

        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO " + TENANT_SCHEMA + ".batch_balance (sku_public_id, batch_public_id, location_id, qty) " +
                "VALUES (?, ?, 'STORE', 5)", sku, batch))
                .hasMessageContaining("cannot be written directly");

        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isEqualTo(50);
    }

    @Test
    void allocation_takes_the_earliest_expiry_first_and_never_an_expired_batch() {
        String sku = newSku("Amoxil 500");
        String expired = newBatch(sku, "OLD", LocalDate.now().minusDays(1));
        String soon = newBatch(sku, "SOON", LocalDate.now().plusDays(20));
        String later = newBatch(sku, "LATER", LocalDate.now().plusDays(300));

        stockLedger.append(movement(sku, expired, 50, MovementReason.GRN));
        stockLedger.append(movement(sku, soon, 50, MovementReason.GRN));
        stockLedger.append(movement(sku, later, 50, MovementReason.GRN));

        BatchAllocation.Result result = stockLedger.allocateFefo(sku, COUNTER, 60);

        assertThat(result.isComplete()).isTrue();
        assertThat(result.allocations()).hasSize(2);
        assertThat(result.allocations().get(0).batchPublicId()).isEqualTo(soon);
        assertThat(result.allocations().get(0).qtyBaseUnits()).isEqualTo(50);
        assertThat(result.allocations().get(1).batchPublicId()).isEqualTo(later);
        assertThat(result.allocations().get(1).qtyBaseUnits()).isEqualTo(10);

        // 50 expired units sit on the shelf and are invisible to allocation.
        assertThat(stockLedger.balanceOf(sku, COUNTER)).isEqualTo(150);
    }

    @Test
    void a_shortfall_is_reported_rather_than_thrown() {
        String sku = newSku("Pan 40");
        String batch = newBatch(sku, "P1", LocalDate.now().plusMonths(3));
        stockLedger.append(movement(sku, batch, 8, MovementReason.GRN));

        BatchAllocation.Result result = stockLedger.allocateFefo(sku, COUNTER, 20);

        assertThat(result.isComplete()).isFalse();
        assertThat(result.allocatedBaseUnits()).isEqualTo(8);
        assertThat(result.shortfallBaseUnits()).isEqualTo(12);
    }

    /**
     * A negative balance is the ledger reporting a missing receipt, not corruption.
     * At SUGGEST the sale completes and the store gets a reconciliation task.
     */
    @Test
    void a_negative_balance_is_allowed_at_suggest_and_announced() {
        String sku = newSku("Zincovit");
        String batch = newBatch(sku, "Z1", LocalDate.now().plusYears(1));

        assertThat(policies.modeOf(PolicyKey.NEGATIVE_STOCK)).isEqualTo(PolicyMode.SUGGEST);

        stockLedger.append(movement(sku, batch, -5, MovementReason.SALE));

        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isEqualTo(-5);
        assertThat(outboxCountOfType(InventoryEvents.STOCK_WENT_NEGATIVE)).isEqualTo(1);
        assertThat(outboxCountOfType(InventoryEvents.STOCK_MOVED)).isEqualTo(1);
    }

    /**
     * The important half of ENFORCE is not that the sale fails — it is that the
     * ledger row written moments before the balance check does not survive it.
     */
    @Test
    void enforce_blocks_the_oversell_and_takes_the_ledger_row_down_with_it() {
        policies.setTenantOverride(PolicyKey.NEGATIVE_STOCK, PolicyMode.ENFORCE, "test");

        String sku = newSku("Augmentin 625");
        String batch = newBatch(sku, "AU1", LocalDate.now().plusMonths(8));
        stockLedger.append(movement(sku, batch, 10, MovementReason.GRN));

        assertThatThrownBy(() -> stockLedger.append(movement(sku, batch, -11, MovementReason.SALE)))
                .isInstanceOf(InsufficientStockException.class);

        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isEqualTo(10);
        assertThat(ledgerRowCount()).isEqualTo(1);
        assertThat(ledgerSum(batch)).isEqualTo(10);
    }

    @Test
    void a_mistake_is_reversed_by_a_compensating_entry_and_only_ever_once() {
        String sku = newSku("Betadine");
        String batch = newBatch(sku, "BD1", LocalDate.now().plusYears(1));
        long grnId = stockLedger.append(movement(sku, batch, 10, MovementReason.GRN));

        long reversalId = stockLedger.reverse(grnId, "manager", "wrong batch keyed");

        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isZero();
        assertThat(ledgerRowCount()).isEqualTo(2);

        // The reversal keeps the original's reason: the stock moved because of a
        // GRN, and the correction does not change why.
        String reason = jdbcTemplate.queryForObject(
                "SELECT reason FROM " + TENANT_SCHEMA + ".stock_ledger WHERE ledger_id = ?", String.class, reversalId);
        assertThat(reason).isEqualTo("GRN");

        assertThatThrownBy(() -> stockLedger.reverse(grnId, "manager", "again"))
                .isInstanceOf(DuplicateKeyException.class);
    }

    /**
     * Two counters, one blockbuster SKU, ten units, six wanted by each. Postgres
     * row locks are the whole concurrency control — there is no Redis and no queue
     * anywhere in this path.
     */
    @Test
    void two_concurrent_sales_cannot_oversell_the_same_batch_under_enforce() throws Exception {
        policies.setTenantOverride(PolicyKey.NEGATIVE_STOCK, PolicyMode.ENFORCE, "test");

        String sku = newSku("Liv 52");
        String batch = newBatch(sku, "L1", LocalDate.now().plusYears(1));
        stockLedger.append(movement(sku, batch, 10, MovementReason.GRN));

        CountDownLatch startTogether = new CountDownLatch(1);
        CountDownLatch bothDone = new CountDownLatch(2);
        AtomicInteger succeeded = new AtomicInteger();
        AtomicInteger refused = new AtomicInteger();
        AtomicReference<Throwable> unexpected = new AtomicReference<>();

        Runnable sellSix = () -> {
            TenantContext.set(TENANT_PUBLIC_ID, TENANT_SCHEMA);
            try {
                startTogether.await();
                stockLedger.append(movement(sku, batch, -6, MovementReason.SALE));
                succeeded.incrementAndGet();
            } catch (InsufficientStockException e) {
                refused.incrementAndGet();
            } catch (Throwable t) {
                unexpected.set(t);
            } finally {
                TenantContext.clear();
                bothDone.countDown();
            }
        };

        Thread one = new Thread(sellSix, "counter-1");
        Thread two = new Thread(sellSix, "counter-2");
        one.start();
        two.start();
        startTogether.countDown();
        assertThat(bothDone.await(30, TimeUnit.SECONDS)).isTrue();

        assertThat(unexpected.get()).isNull();
        assertThat(succeeded.get()).isEqualTo(1);
        assertThat(refused.get()).isEqualTo(1);
        assertThat(stockLedger.balanceOfBatch(batch, COUNTER)).isEqualTo(4);
        assertThat(ledgerSum(batch)).isEqualTo(4);
    }

    /** Deadlock bait: the same two batches, claimed in opposite order by each sale. */
    @Test
    void multi_line_sales_touching_the_same_batches_in_opposite_order_do_not_deadlock() throws Exception {
        String sku = newSku("Combiflam");
        String first = newBatch(sku, "F1", LocalDate.now().plusYears(1));
        String second = newBatch(sku, "F2", LocalDate.now().plusYears(2));
        stockLedger.appendAll(List.of(
                movement(sku, first, 100, MovementReason.GRN),
                movement(sku, second, 100, MovementReason.GRN)));

        CountDownLatch bothDone = new CountDownLatch(2);
        AtomicReference<Throwable> failure = new AtomicReference<>();

        Runnable sellBoth = () -> {
            TenantContext.set(TENANT_PUBLIC_ID, TENANT_SCHEMA);
            try {
                for (int i = 0; i < 20; i++) {
                    stockLedger.appendAll(List.of(
                            movement(sku, second, -1, MovementReason.SALE),
                            movement(sku, first, -1, MovementReason.SALE)));
                }
            } catch (Throwable t) {
                failure.set(t);
            } finally {
                TenantContext.clear();
                bothDone.countDown();
            }
        };
        Runnable sellBothReversed = () -> {
            TenantContext.set(TENANT_PUBLIC_ID, TENANT_SCHEMA);
            try {
                for (int i = 0; i < 20; i++) {
                    stockLedger.appendAll(List.of(
                            movement(sku, first, -1, MovementReason.SALE),
                            movement(sku, second, -1, MovementReason.SALE)));
                }
            } catch (Throwable t) {
                failure.set(t);
            } finally {
                TenantContext.clear();
                bothDone.countDown();
            }
        };

        new Thread(sellBoth, "counter-a").start();
        new Thread(sellBothReversed, "counter-b").start();
        assertThat(bothDone.await(60, TimeUnit.SECONDS)).isTrue();

        assertThat(failure.get()).isNull();
        assertThat(stockLedger.balanceOfBatch(first, COUNTER)).isEqualTo(60);
        assertThat(stockLedger.balanceOfBatch(second, COUNTER)).isEqualTo(60);
    }

    @Test
    void a_ledger_append_outside_a_transaction_is_refused_rather_than_half_written() {
        // Guards the SET LOCAL contract: without a transaction the balance trigger
        // would reject the write anyway, but it would do so after the ledger row
        // had already committed on its own.
        String sku = newSku("Ecosprin");
        String batch = newBatch(sku, "E1", LocalDate.now().plusYears(1));

        StockLedgerService unproxied = new StockLedgerService(jdbcTemplate, event -> {
        }, policies);

        assertThatThrownBy(() -> unproxied.append(movement(sku, batch, 5, MovementReason.GRN)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("inside a transaction");

        assertThat(ledgerRowCount()).isZero();
    }

    private StockMovement movement(String sku, String batch, int qtyDelta, MovementReason reason) {
        return StockMovement.of(sku, batch, COUNTER, qtyDelta, reason, "TEST", "REF-1", "tester");
    }

    private String newSku(String brandName) {
        return catalog.createSku(new CreateSkuCommand(
                brandName, "Acme", "TABLET", "650mg", BaseUnit.TABLET, null, "3004", 1200,
                "R1", null, null, null,
                List.of(new CreateSkuCommand.PackLevel("STRIP", 10, true)), List.of()))
                .skuPublicId();
    }

    private String newBatch(String skuPublicId, String batchNo, LocalDate expiry) {
        return inventory.findOrCreateBatch(
                new CreateBatchCommand(skuPublicId, batchNo, expiry, 500L, 400L, null));
    }
}
