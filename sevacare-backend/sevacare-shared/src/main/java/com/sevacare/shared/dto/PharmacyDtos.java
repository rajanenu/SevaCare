package com.sevacare.shared.dto;

import java.time.LocalDate;
import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * Request bodies for the pharmacy counter. Responses reuse the pharmacy context's
 * own SPI records, so there is one shape for each concept and no mapping to drift.
 *
 * <p>Money is always integer paise and quantities are always base units, matching
 * the ledger. The client never sends a price on a sale line — it sends what and
 * how many, and billing charges the batch's printed MRP — except the deliberate
 * {@code mrpOverridePaise}, honoured only where policy permits a price edit.
 */
public final class PharmacyDtos {

    private PharmacyDtos() {
    }

    /**
     * Add something to the catalog. Only a brand name is required — a pharmacist
     * stocking an item mid-sale should not be blocked on an HSN code.
     */
    public record QuickSkuRequest(
            @NotBlank String brandName,
            String manufacturer,
            String dosageForm,
            String strength,
            String baseUnit,
            String scheduleClass,
            String hsnCode,
            Integer gstRateBp,
            String rackLocation,
            Integer reorderLevel,
            Integer reorderQty,
            List<PackLevelRequest> packs,
            List<String> aliases) {
    }

    /** @param unitsInPack how many base units this level holds, e.g. STRIP → 10 */
    public record PackLevelRequest(String packName, int unitsInPack, Boolean sellable) {
        public boolean sellableOrDefault() {
            return sellable == null || sellable;
        }
    }

    /** Receive stock: the batch off the invoice, and how many base units arrived. */
    public record ReceiveStockRequest(
            @NotBlank String skuPublicId,
            @NotBlank String batchNo,
            LocalDate expiryDate,
            @PositiveOrZero long mrpPaise,
            Long purchasePricePaise,
            String supplierPublicId,
            @Positive int qtyBaseUnits) {
    }

    public record SaleRequest(
            String customerName,
            String customerMobile,
            String prescriberName,
            String paymentMode,
            String note,
            @NotEmpty List<SaleLineRequest> lines) {
    }

    /**
     * Either a catalog line ({@code skuPublicId} set) or a manual, non-catalog line
     * ({@code manualLabel}/{@code manualAmountPaise} set instead — a courier bag, a
     * delivery charge, anything that isn't on the shelf).
     */
    public record SaleLineRequest(
            String skuPublicId,
            @Positive int qtyBaseUnits,
            String batchPublicId,
            Long discountPaise,
            Long mrpOverridePaise,
            String manualLabel,
            Long manualAmountPaise) {
    }

    /** A khata repayment as the counter records it. */
    public record CreditPaymentRequest(
            @NotBlank String customerMobile,
            @Positive long amountPaise,
            String paidVia,
            String note) {
    }

    /** Corrections to an existing medicine; null fields are left untouched. */
    public record UpdateSkuRequest(
            Integer gstRateBp,
            String hsnCode,
            String rackLocation,
            String scheduleClass,
            Integer reorderLevel,
            Integer reorderQty) {
    }

    /** A distributor, added inline while a delivery waits. Name is enough. */
    public record SupplierRequest(
            @NotBlank String supplierName,
            String mobileNumber,
            String email,
            String gstin,
            String city,
            Integer returnWindowDays) {
    }

    /**
     * One delivery. Lines carry the supplier invoice's own numbers: billed
     * quantity, free scheme quantity ("10+1"), printed MRP, invoice price per
     * billed base unit. Supplier and invoice number are optional — a carton that
     * arrived on a phone order is still a delivery.
     */
    public record GrnRequest(
            String supplierPublicId,
            String supplierInvoiceNo,
            LocalDate invoiceDate,
            String note,
            @NotEmpty List<GrnLineRequest> lines) {
    }

    public record GrnLineRequest(
            @NotBlank String skuPublicId,
            @NotBlank String batchNo,
            LocalDate expiryDate,
            @Positive int qtyBaseUnits,
            @PositiveOrZero int freeQtyBaseUnits,
            @PositiveOrZero long mrpPaise,
            Long purchasePricePaise) {
    }

    /** A customer return against one bill; refund is computed server-side. */
    public record ReturnRequest(
            @NotBlank String salePublicId,
            String refundMode,
            String reason,
            @NotEmpty List<ReturnLineRequest> lines) {
    }

    /** @param disposition RESTOCK (sellable again) or QUARANTINE (never resold) */
    public record ReturnLineRequest(
            @NotBlank String skuPublicId,
            @NotBlank String batchPublicId,
            @Positive int qtyBaseUnits,
            String disposition) {
    }

    /** Close the day: what was physically counted in the cash drawer. */
    public record DayCloseRequest(
            LocalDate date,
            @PositiveOrZero long countedCashPaise,
            String note) {
    }

    /**
     * A supplier catalog uploaded at once. The client parses the CSV/Excel and
     * sends structured rows, so the server never guesses at column order or a
     * regional date format. A row may carry only the product, or the product plus
     * an opening batch to stock it in the same pass.
     */
    public record CatalogImportRequest(
            @NotEmpty List<ImportRowRequest> rows) {
    }

    public record ImportRowRequest(
            @NotBlank String brandName,
            String manufacturer,
            String dosageForm,
            String strength,
            String baseUnit,
            String scheduleClass,
            String hsnCode,
            Integer gstRateBp,
            String rackLocation,
            Integer reorderLevel,
            String batchNo,
            LocalDate expiryDate,
            Long mrpPaise,
            Long purchasePricePaise,
            Integer openingQty) {
    }
}
