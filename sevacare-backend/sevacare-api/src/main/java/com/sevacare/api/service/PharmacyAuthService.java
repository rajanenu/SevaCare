package com.sevacare.api.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.api.security.TokenService;
import com.sevacare.shared.dto.AuthDtos;
import com.sevacare.shared.security.TokenClaims;
import com.sevacare.tenant.capability.TenantManifest;
import com.sevacare.tenant.capability.TenantModuleService;
import com.sevacare.tenant.service.TenantRegistryService;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Sign-in for a standalone medical store — mobile number first, no hospital to
 * pick and no tenant code to type. The owner's phone <em>is</em> the shop's
 * identity: we look across every pharmacy-enabled tenant for a store where that
 * number is a registered admin or staff, and let them in there.
 *
 * <p>Kept entirely separate from {@code AuthController}'s hospital login, which
 * requires a tenant chosen up front via hospital search. A shop owner never
 * searches hospitals. A hospital's own pharmacist can use this door too — the
 * resolver simply finds their tenant — but the hospital login is unchanged.
 *
 * <p>The cross-tenant sweep is a handful of primary-key lookups today; if the
 * tenant count ever makes it a cost, back it with a {@code public} mobile→tenant
 * index rather than caching (a stale login target is worse than a slow one).
 */
@Service
public class PharmacyAuthService {

    private static final Logger log = LoggerFactory.getLogger(PharmacyAuthService.class);

    private final JdbcTemplate jdbcTemplate;
    private final OtpService otpService;
    private final TokenService tokenService;
    private final TenantModuleService tenantModuleService;
    private final TenantRegistryService tenantRegistryService;

    public PharmacyAuthService(
            JdbcTemplate jdbcTemplate,
            OtpService otpService,
            TokenService tokenService,
            TenantModuleService tenantModuleService,
            TenantRegistryService tenantRegistryService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.otpService = otpService;
        this.tokenService = tokenService;
        this.tenantModuleService = tenantModuleService;
        this.tenantRegistryService = tenantRegistryService;
    }

    /** Every pharmacy-enabled store this mobile number can sign into. */
    @Transactional(readOnly = true)
    public List<AuthDtos.PharmacyLoginOption> shopsForMobile(String mobileNumber) {
        String mobile = mobileNumber == null ? "" : mobileNumber.trim();
        if (mobile.isEmpty()) {
            return List.of();
        }

        List<Map<String, Object>> tenants = jdbcTemplate.queryForList(
                "SELECT tenant_public_id, tenant_name, tenant_schema_name FROM public.tenant_registry " +
                        "WHERE tenant_status = 'active' AND pharmacy_profile_key IS NOT NULL " +
                        "ORDER BY tenant_public_id");

        List<AuthDtos.PharmacyLoginOption> shops = new ArrayList<>();
        for (Map<String, Object> t : tenants) {
            String schema = (String) t.get("tenant_schema_name");
            String userType = adminUserType(schema, mobile);
            if (userType != null) {
                shops.add(new AuthDtos.PharmacyLoginOption(
                        (String) t.get("tenant_public_id"),
                        (String) t.get("tenant_name"),
                        userType));
            }
        }
        return shops;
    }

    /** Validate the OTP against the chosen store and mint a counter session. */
    @Transactional(readOnly = true)
    public AuthDtos.AuthenticatedSession verify(String mobileNumber, String otp, String tenantPublicId) {
        String mobile = mobileNumber == null ? "" : mobileNumber.trim();

        if (!otpService.matches(mobile, otp)) {
            throw new IllegalArgumentException("Invalid OTP.");
        }

        TenantManifest manifest = tenantModuleService.manifestOf(tenantPublicId);
        if (!manifest.pharmacyEnabled()) {
            // 404-not-403 doctrine: a store without a pharmacy shouldn't reveal itself.
            throw new IllegalArgumentException("No medical store found for this sign-in.");
        }

        String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
        Map<String, Object> admin = findActiveAdmin(schema, mobile);
        if (admin == null) {
            throw new IllegalArgumentException("This mobile number is not registered at this store.");
        }

        String userType = (String) admin.get("user_type");
        String subjectPublicId = (String) admin.get("admin_public_id");
        String fullName = (String) admin.get("full_name");
        String subjectName = (fullName != null && !fullName.isBlank()) ? fullName : "Owner";

        // Staff and owner both run the counter; both carry the ADMIN jwt role so the
        // pharmacy security gates (hasAnyRole ADMIN,STAFF) pass, while userType keeps
        // the distinction the UI needs.
        String jwtRole = "admin";
        String token = tokenService.issue(new TokenClaims(tenantPublicId, jwtRole, subjectPublicId));

        log.info("pharmacy_login tenantPublicId={} subject={} userType={}", tenantPublicId, subjectPublicId, userType);
        return new AuthDtos.AuthenticatedSession(
                tenantPublicId, jwtRole, subjectPublicId, token, false, subjectName, userType);
    }

    private String adminUserType(String schema, String mobile) {
        Map<String, Object> admin = findActiveAdmin(schema, mobile);
        return admin == null ? null : (String) admin.get("user_type");
    }

    private Map<String, Object> findActiveAdmin(String schema, String mobile) {
        // schema comes from our own registry, but validate the identifier anyway
        // since it is interpolated into SQL.
        String safeSchema = TenantSchemas.require(schema);
        try {
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT admin_public_id, full_name, user_type FROM " + safeSchema +
                            ".admin_user WHERE mobile_number = ? AND active = true LIMIT 1",
                    mobile);
            return rows.isEmpty() ? null : rows.get(0);
        } catch (DataAccessException e) {
            // A tenant whose schema predates admin_user shouldn't break the sweep.
            log.warn("pharmacy_admin_lookup_failed schema={} message={}", safeSchema, e.getMessage());
            return null;
        }
    }
}
