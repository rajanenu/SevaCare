package com.sevacare.api.service;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.sevacare.shared.security.TokenClaims;
import com.sevacare.tenant.service.PlatformAdminService;
import com.sevacare.tenant.service.TenantRegistryService;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Resolves the mobile number behind an authenticated session.
 *
 * <p>The passcode table is keyed by mobile number, but a token carries only
 * {@code (tenant, role, subject)} — deliberately, so the client can never name
 * whose passcode it is changing. This resolver walks from the signed claims to
 * the one mobile number they belong to; the caller can therefore only ever
 * touch their own credential.
 */
@Service
public class AccountMobileResolver {

    private final JdbcTemplate jdbcTemplate;
    private final TenantRegistryService tenantRegistryService;

    public AccountMobileResolver(JdbcTemplate jdbcTemplate, TenantRegistryService tenantRegistryService) {
        this.jdbcTemplate = jdbcTemplate;
        this.tenantRegistryService = tenantRegistryService;
    }

    /** The mobile number this session logged in with, or null if the subject no longer exists. */
    public String mobileFor(TokenClaims claims) {
        if (PlatformAdminService.PLATFORM_TENANT_PUBLIC_ID.equalsIgnoreCase(claims.tenantPublicId())) {
            return single(
                    "SELECT mobile_number FROM public.platform_admin_user WHERE platform_admin_public_id = ? AND active = true",
                    claims.subjectPublicId());
        }

        String schema = TenantSchemas.require(tenantRegistryService.resolveTenantSchema(claims.tenantPublicId()));
        return switch (claims.role()) {
            // The IP-Staff login carries the 'admin' JWT role, so admin_user covers both.
            case "admin" -> single(
                    "SELECT mobile_number FROM " + schema + ".admin_user WHERE admin_public_id = ?",
                    claims.subjectPublicId());
            case "doctor" -> single(
                    "SELECT mobile_number FROM " + schema + ".doctor WHERE doctor_public_id = ?",
                    claims.subjectPublicId());
            case "patient" -> single(
                    "SELECT mobile_number FROM " + schema + ".patient WHERE patient_public_id = ?",
                    claims.subjectPublicId());
            default -> null;
        };
    }

    /**
     * Whether this mobile number belongs to any user of the given tenant —
     * admin, staff, doctor or patient. Gates the admin's passcode reset so one
     * hospital cannot reset a stranger's code by guessing numbers.
     */
    public boolean mobileKnownToTenant(String tenantPublicId, String mobileNumber) {
        String schema = TenantSchemas.require(tenantRegistryService.resolveTenantSchema(tenantPublicId));
        String mobile = mobileNumber == null ? "" : mobileNumber.trim();
        if (mobile.isEmpty()) {
            return false;
        }
        Integer hits = jdbcTemplate.queryForObject(
                "SELECT (SELECT COUNT(*) FROM " + schema + ".admin_user WHERE mobile_number = ?) + " +
                        "(SELECT COUNT(*) FROM " + schema + ".doctor WHERE mobile_number = ?) + " +
                        "(SELECT COUNT(*) FROM " + schema + ".patient WHERE mobile_number = ?)",
                Integer.class, mobile, mobile, mobile);
        return hits != null && hits > 0;
    }

    private String single(String sql, String arg) {
        List<String> rows = jdbcTemplate.queryForList(sql, String.class, arg);
        return rows.isEmpty() ? null : rows.get(0);
    }
}
