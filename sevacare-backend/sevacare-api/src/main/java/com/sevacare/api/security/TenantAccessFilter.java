package com.sevacare.api.security;

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.sevacare.shared.security.TokenClaims;
import com.sevacare.shared.tenant.TenantContext;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * A session may only ever touch the tenant it was issued for.
 *
 * <p>{@code X-Tenant-Id} is supplied by the client, and {@link
 * com.sevacare.api.config.TenantHeaderFilter} turns it straight into the schema
 * every query then runs against. The token carries the tenant the user actually
 * logged into — but until this filter existed nothing compared the two. A valid
 * admin token from one hospital, replayed with another hospital's id in the
 * header, returned that hospital's patient list: names, mobile numbers, ages,
 * visit history. One tenant could read every other tenant's records.
 *
 * <p>The per-controller {@code "Tenant mismatch"} guards do not close this. They
 * compare the path variable with {@code TenantContext} — header against path,
 * both chosen by the caller — so they only check that the client agrees with
 * itself. This is the check that makes them mean something: once the context is
 * pinned to the token, those guards become defence in depth rather than the only
 * line of defence.
 *
 * <p>Answers <b>403, not 404</b>. The tenant directory is already public
 * ({@code GET /api/v1/public/tenants}), so concealing that a tenant exists buys
 * nothing — unlike {@link ModuleAccessFilter}, where 404 hides what a customer
 * bought. And deliberately not 401: the app signs the user out on 401, and a
 * cross-tenant request must not be able to destroy a good session.
 */
@Component
public class TenantAccessFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(TenantAccessFilter.class);

    /**
     * Pure, so the one line that decides whether a hospital can read another
     * hospital's records is testable without a servlet container.
     *
     * <p>A platform admin is denied too. Their token's tenant is the sentinel
     * {@code "platform"}, which matches no real tenant, and every operator
     * endpoint lives under {@code /api/v1/platform-admin} — which carries no
     * tenant context at all. So they lose nothing, and a stolen operator token
     * cannot be pointed at a customer's schema.
     */
    static boolean isCrossTenant(String tokenTenant, String requestTenant) {
        if (requestTenant == null) {
            // Public, auth and platform-admin routes never resolve a tenant.
            return false;
        }
        return tokenTenant == null || !requestTenant.equalsIgnoreCase(tokenTenant.trim());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        String requestTenant = TenantContext.tenantPublicId();
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

        // No tenant resolved, or nobody authenticated yet: not our call. An
        // anonymous request to a protected route is Spring Security's 401 to make.
        if (requestTenant == null || authentication == null
                || !(authentication.getDetails() instanceof TokenClaims claims)) {
            chain.doFilter(request, response);
            return;
        }

        if (isCrossTenant(claims.tenantPublicId(), requestTenant)) {
            // WARN, not DEBUG: a real client cannot produce this. It is either an
            // attacker replaying a token across tenants or a bug that would leak
            // records, and both are worth waking someone up for.
            log.warn("cross_tenant_denied tokenTenant={} requestTenant={} subject={} path={}",
                    claims.tenantPublicId(), requestTenant, claims.subjectPublicId(), request.getRequestURI());
            response.setStatus(HttpStatus.FORBIDDEN.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write("{\"error\":\"Forbidden\"}");
            return;
        }

        chain.doFilter(request, response);
    }
}
