package com.sevacare.pharmacy.returns.spi;

/** Facts the returns context announces. */
public final class ReturnsEvents {

    /** A customer return posted: stock is back (or quarantined), money went out. */
    public static final String CUSTOMER_RETURN_POSTED = "pharmacy.return.customer_posted";

    private ReturnsEvents() {
    }
}
