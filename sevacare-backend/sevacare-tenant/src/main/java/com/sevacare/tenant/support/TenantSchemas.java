package com.sevacare.tenant.support;

import java.util.regex.Pattern;

/**
 * A tenant schema name cannot be a bind parameter — it is part of the SQL text —
 * so every place that concatenates one validates it first. The name comes from
 * {@code tenant_registry} rather than from a request, which makes this a
 * defence-in-depth check rather than the primary control, and cheap enough to
 * apply on every publish.
 */
public final class TenantSchemas {

    private static final Pattern SAFE_SCHEMA = Pattern.compile("^[a-z][a-z0-9_]{0,62}$");
    private static final Pattern SAFE_TENANT_ID = Pattern.compile("^[A-Za-z0-9_-]{1,24}$");

    private TenantSchemas() {
    }

    public static String require(String schemaName) {
        if (schemaName == null || !SAFE_SCHEMA.matcher(schemaName).matches()) {
            throw new IllegalArgumentException("Unsafe or absent tenant schema name: " + schemaName);
        }
        return schemaName;
    }

    public static String requireTenantId(String tenantPublicId) {
        if (tenantPublicId == null || !SAFE_TENANT_ID.matcher(tenantPublicId).matches()) {
            throw new IllegalArgumentException("Unsafe or absent tenant id: " + tenantPublicId);
        }
        return tenantPublicId;
    }
}
