package com.sevacare.pharmacy.billing.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.sevacare.pharmacy.billing.spi.SaleReceipt;

/**
 * Queues the counter receipt on WhatsApp — the same durable outbox
 * {@code WhatsAppService} drains for prescriptions and booking confirmations
 * (blueprint: enqueue inside the triggering transaction, never throw, deliver
 * separately). Pharmacy deliberately has no Java dependency on the patient
 * module that owns that service ({@code PharmacyBoundaryTest} forbids it), but
 * {@code public.whatsapp_outbox} is a plain table, not a class — inserting into
 * it directly is legal and keeps the module boundary intact.
 *
 * <p>Returns the computed {@code wa.me} link regardless of whether the insert
 * succeeded, so the counter can offer an immediate tap-to-send even before any
 * WhatsApp provider credentials exist — the same link the drainer would use
 * once they do.
 */
@Service
public class PharmacyReceiptNotifier {

    private static final Logger log = LoggerFactory.getLogger(PharmacyReceiptNotifier.class);
    private static final String MESSAGE_TYPE = "PHARMACY_RECEIPT";

    private final JdbcTemplate jdbcTemplate;

    @Value("${sevacare.whatsapp.country-code:91}")
    private String countryCode;

    public PharmacyReceiptNotifier(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Never throws — a courtesy receipt message must not fail the sale that
     * produced it. Returns null when there is no customer mobile to send to.
     */
    public String notify(String tenantPublicId, SaleReceipt receipt) {
        String mobile = normalizeMobile(receipt.customerMobile());
        if (mobile == null) {
            return null;
        }
        String shopName = shopName(tenantPublicId);
        String body = receiptBody(shopName, receipt);
        String link = waLink(mobile, body);
        try {
            jdbcTemplate.update(
                    "INSERT INTO public.whatsapp_outbox " +
                    "(tenant_public_id, to_mobile, message_type, reference_id, body, wa_link, status, scheduled_at) " +
                    "VALUES (?, ?, ?, ?, ?, ?, 'PENDING', CURRENT_TIMESTAMP) " +
                    "ON CONFLICT (tenant_public_id, message_type, reference_id) DO NOTHING",
                    tenantPublicId, mobile, MESSAGE_TYPE, receipt.salePublicId(), body, link);
        } catch (Exception e) {
            log.warn("pharmacy_receipt_whatsapp_enqueue_failed tenant={} sale={} reason={}",
                    tenantPublicId, receipt.salePublicId(), e.getMessage());
        }
        return link;
    }

    private String shopName(String tenantPublicId) {
        try {
            String name = jdbcTemplate.queryForObject(
                    "SELECT tenant_name FROM public.tenant_registry WHERE tenant_public_id = ?",
                    String.class, tenantPublicId);
            return (name == null || name.isBlank()) ? "Your pharmacy" : name;
        } catch (Exception e) {
            return "Your pharmacy";
        }
    }

    private String receiptBody(String shopName, SaleReceipt receipt) {
        StringBuilder sb = new StringBuilder();
        sb.append("*").append(shopName).append("*\n");
        sb.append("Invoice ").append(receipt.invoiceNo()).append("\n\n");
        for (SaleReceipt.Line line : receipt.lines()) {
            sb.append(line.qtyBaseUnits()).append(" x ").append(line.brandName())
              .append(" — ").append(rupees(line.grossPaise())).append("\n");
        }
        sb.append("\n*Total: ").append(rupees(receipt.totalPaise())).append("*\n");
        sb.append("Paid via ").append(receipt.paymentMode()).append("\n\n");
        sb.append("Thank you for shopping with us. Keep this message for your records.");
        return sb.toString();
    }

    private static String rupees(long paise) {
        return "Rs " + String.format("%.2f", paise / 100.0);
    }

    /** Strips separators and prepends the country code when a bare 10-digit number is given. */
    private String normalizeMobile(String raw) {
        if (raw == null) {
            return null;
        }
        String digits = raw.replaceAll("\\D", "");
        if (digits.length() == 10) {
            digits = countryCode + digits;
        }
        return digits.length() >= 11 && digits.length() <= 15 ? digits : null;
    }

    private String waLink(String normalizedMobile, String body) {
        return "https://wa.me/" + normalizedMobile + "?text="
                + URLEncoder.encode(body, StandardCharsets.UTF_8);
    }
}
