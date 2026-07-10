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

    @Column(name = "email", length = 160)
    private String email;

    /**
     * Doctors, appointments, prescriptions. False for a standalone medical store,
     * which is a first-class customer rather than a hospital with parts missing.
     */
    @Column(name = "clinical_enabled", nullable = false)
    private boolean clinicalEnabled = true;

    /**
     * {@code platform.capability_profile.profile_key}, or null when this tenant
     * has no pharmacy. A database check constraint refuses a tenant with neither
     * module: that is a login that leads to an empty screen.
     */
    @Column(name = "pharmacy_profile_key", length = 32)
    private String pharmacyProfileKey;

    public boolean isClinicalEnabled() { return clinicalEnabled; }
    public void setClinicalEnabled(boolean clinicalEnabled) { this.clinicalEnabled = clinicalEnabled; }
    public String getPharmacyProfileKey() { return pharmacyProfileKey; }
    public void setPharmacyProfileKey(String pharmacyProfileKey) { this.pharmacyProfileKey = pharmacyProfileKey; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public String getPinCode() { return pinCode; }
    public void setPinCode(String pinCode) { this.pinCode = pinCode; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

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
