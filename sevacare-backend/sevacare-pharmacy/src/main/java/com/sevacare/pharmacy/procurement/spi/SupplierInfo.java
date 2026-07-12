package com.sevacare.pharmacy.procurement.spi;

/**
 * What other contexts (and the API) may know about a supplier. The
 * {@code returnWindowDays} is the number that matters: the near-expiry queue
 * turns it into a deadline — "return to this supplier by <date> or eat the loss".
 */
public record SupplierInfo(
        String supplierPublicId,
        String supplierName,
        String mobileNumber,
        String email,
        String gstin,
        String city,
        int returnWindowDays,
        boolean active) {
}
