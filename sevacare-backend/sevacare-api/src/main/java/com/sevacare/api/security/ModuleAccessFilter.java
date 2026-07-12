package com.sevacare.api.security;

import java.io.IOException;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.capability.TenantManifest;
import com.sevacare.tenant.capability.TenantModuleService;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * A module a tenant did not buy does not exist for that tenant.
 *
 * <p>The response is <b>404, not 403</b>, and the distinction is the whole
 * design. 403 says "this exists and you may not have it", which tells a medical
 * store that a Doctors API is sitting there, invites support tickets asking why
 * it is forbidden, and hands an attacker a map of what a tenant has bought. 404
 * says the endpoint is not part of this product, which is the truth.
 *
 * <p>Runs after {@link TokenAuthenticationFilter}, which is what puts the tenant
 * in {@code TenantContext}. Unauthenticated and public routes are never module
 * scoped, so they pass straight through.
 */
@Component
public class ModuleAccessFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(ModuleAccessFilter.class);

    /**
     * The clinical spine. Deliberately not {@code /api/v1/admin}: a store owner
     * manages staff, settings and reports through the same admin surface a
     * hospital admin does, and gating that whole prefix would lock the owner out
     * of their own shop. Clinical means doctors, patients and prescriptions.
     */
    private static final List<String> CLINICAL_PREFIXES =
            List.of("/api/v1/doctors", "/api/v1/patients", "/api/v1/prescriptions");

    private static final String PHARMACY_PREFIX = "/api/v1/pharmacy";

    private final TenantModuleService tenantModuleService;

    public ModuleAccessFilter(TenantModuleService tenantModuleService) {
        this.tenantModuleService = tenantModuleService;
    }

    /**
     * Pure, so it can be tested without a servlet container or a database — and
     * so the one line that decides whether a customer can reach a feature is
     * readable on its own.
     */
    static boolean isBlocked(String path, TenantManifest manifest) {
        if (path.startsWith(PHARMACY_PREFIX)) {
            return !manifest.pharmacyEnabled();
        }
        if (CLINICAL_PREFIXES.stream().anyMatch(path::startsWith)) {
            return !manifest.clinicalEnabled();
        }
        return false;
    }

    private static boolean isModuleScoped(String path) {
        return path.startsWith(PHARMACY_PREFIX) || CLINICAL_PREFIXES.stream().anyMatch(path::startsWith);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        String path = request.getRequestURI();
        String tenantPublicId = TenantContext.tenantPublicId();

        // Only pay for the lookup on a path a module could switch off. Everything
        // else -- auth, public discovery, health -- is never tenant scoped.
        if (tenantPublicId == null || !isModuleScoped(path)) {
            chain.doFilter(request, response);
            return;
        }

        TenantManifest manifest = tenantModuleService.manifestOf(tenantPublicId);
        if (isBlocked(path, manifest)) {
            log.debug("module_not_enabled tenantPublicId={} path={}", tenantPublicId, path);
            response.setStatus(HttpStatus.NOT_FOUND.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write("{\"error\":\"Not found\"}");
            return;
        }
        chain.doFilter(request, response);
    }
}
