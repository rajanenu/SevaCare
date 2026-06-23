package com.sevacare.tenant.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "tenant_registry", schema = "public")
public class TenantRegistry {

    @Id
    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "tenant_name", nullable = false, length = 120)
    private String tenantName;

    @Column(name = "tenant_theme_key", nullable = false, length = 32)
    private String tenantThemeKey;

    @Column(name = "tenant_schema_name", nullable = false, length = 63)
    private String tenantSchemaName;

    @Column(name = "tenant_status", nullable = false, length = 24)
    private String tenantStatus;

    @Column(name = "city", nullable = false, length = 120)
    private String city = "";

    @Column(name = "pin_code", nullable = false, length = 10)
    private String pinCode = "";

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public String getPinCode() { return pinCode; }
    public void setPinCode(String pinCode) { this.pinCode = pinCode; }

    public String getTenantPublicId() {
        return tenantPublicId;
    }

    public void setTenantPublicId(String tenantPublicId) {
        this.tenantPublicId = tenantPublicId;
    }

    public String getTenantName() {
        return tenantName;
    }

    public void setTenantName(String tenantName) {
        this.tenantName = tenantName;
    }

    public String getTenantThemeKey() {
        return tenantThemeKey;
    }

    public void setTenantThemeKey(String tenantThemeKey) {
        this.tenantThemeKey = tenantThemeKey;
    }

    public String getTenantSchemaName() {
        return tenantSchemaName;
    }

    public void setTenantSchemaName(String tenantSchemaName) {
        this.tenantSchemaName = tenantSchemaName;
    }

    public String getTenantStatus() {
        return tenantStatus;
    }

    public void setTenantStatus(String tenantStatus) {
        this.tenantStatus = tenantStatus;
    }
}
