package com.sevacare.shared.tenant;

public final class TenantContext {

    private static final ThreadLocal<String> TENANT_SCHEMA = new ThreadLocal<>();
    private static final ThreadLocal<String> TENANT_PUBLIC_ID = new ThreadLocal<>();

    private TenantContext() {
    }

    public static void set(String tenantPublicId, String schema) {
        TENANT_PUBLIC_ID.set(tenantPublicId);
        TENANT_SCHEMA.set(schema);
    }

    public static String tenantPublicId() {
        return TENANT_PUBLIC_ID.get();
    }

    public static String tenantSchema() {
        String value = TENANT_SCHEMA.get();
        return value == null || value.isBlank() ? "public" : value;
    }

    public static void clear() {
        TENANT_PUBLIC_ID.remove();
        TENANT_SCHEMA.remove();
    }
}
