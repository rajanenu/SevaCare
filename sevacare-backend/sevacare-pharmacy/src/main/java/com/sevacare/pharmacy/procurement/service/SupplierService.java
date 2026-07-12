package com.sevacare.pharmacy.procurement.service;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.procurement.spi.SupplierInfo;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The store's distributors. Deliberately small: a supplier here is a name, a
 * phone number and a return window — enough to receive a delivery and chase an
 * expiry claim. Rate contracts and payables come with the procurement phase
 * that needs them.
 */
@Service
public class SupplierService {

    private final JdbcTemplate jdbcTemplate;

    public SupplierService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Creates the supplier, or returns the existing one with the same name.
     * Idempotent on name because the quick-add path lives inside the GRN sheet —
     * the pharmacist types "Sri Balaji Agencies" while a delivery waits, and the
     * second typing of the same distributor must not fork the master data.
     */
    @Transactional
    public SupplierInfo createOrGet(String name, String mobile, String email, String gstin, String city,
                                    Integer returnWindowDays) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Supplier name is required");
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());
        String trimmed = name.trim();

        List<SupplierInfo> existing = jdbcTemplate.query(
                SELECT_COLUMNS + "FROM " + schema + ".supplier WHERE upper(supplier_name) = upper(?)",
                SupplierService::mapRow, trimmed);
        if (!existing.isEmpty()) {
            return existing.get(0);
        }

        Long seq = jdbcTemplate.queryForObject(
                "SELECT nextval('" + schema + ".supplier_public_id_seq')", Long.class);
        String supplierPublicId = "SUP-" + String.format("%06d", seq);
        int window = returnWindowDays == null ? 90 : Math.max(0, returnWindowDays);

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".supplier " +
                "(supplier_public_id, tenant_public_id, supplier_name, mobile_number, email, gstin, city, return_window_days) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                supplierPublicId, tenantPublicId, trimmed,
                trimToNull(mobile), trimToNull(email), trimToNull(gstin), trimToNull(city), window);

        return new SupplierInfo(supplierPublicId, trimmed, trimToNull(mobile), trimToNull(email),
                trimToNull(gstin), trimToNull(city), window, true);
    }

    @Transactional(readOnly = true)
    public List<SupplierInfo> listActive() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbcTemplate.query(
                SELECT_COLUMNS + "FROM " + schema + ".supplier WHERE active ORDER BY supplier_name",
                SupplierService::mapRow);
    }

    private static final String SELECT_COLUMNS =
            "SELECT supplier_public_id, supplier_name, mobile_number, email, gstin, city, return_window_days, active ";

    private static SupplierInfo mapRow(java.sql.ResultSet rs, int i) throws java.sql.SQLException {
        return new SupplierInfo(
                rs.getString("supplier_public_id"),
                rs.getString("supplier_name"),
                rs.getString("mobile_number"),
                rs.getString("email"),
                rs.getString("gstin"),
                rs.getString("city"),
                rs.getInt("return_window_days"),
                rs.getBoolean("active"));
    }

    private static String trimToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }
}
