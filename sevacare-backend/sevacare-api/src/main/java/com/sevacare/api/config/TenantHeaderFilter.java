package com.sevacare.api.config;

import java.io.IOException;

import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.service.TenantRegistryService;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class TenantHeaderFilter extends OncePerRequestFilter {

    private final TenantRegistryService tenantRegistryService;

    public TenantHeaderFilter(TenantRegistryService tenantRegistryService) {
        this.tenantRegistryService = tenantRegistryService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        try {
            String path = request.getRequestURI();
            if (path.startsWith("/api/v1/public") || path.startsWith("/api/v1/auth") || path.startsWith("/api/v1/platform-admin") || path.startsWith("/actuator")) {
                filterChain.doFilter(request, response);
                return;
            }

            String tenantPublicId = request.getHeader("X-Tenant-Id");
            if (tenantPublicId == null || tenantPublicId.isBlank()) {
                response.sendError(HttpServletResponse.SC_BAD_REQUEST, "X-Tenant-Id header is required");
                return;
            }

            String schema = tenantRegistryService.resolveTenantSchema(tenantPublicId);
            TenantContext.set(tenantPublicId, schema);
            filterChain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }
}
