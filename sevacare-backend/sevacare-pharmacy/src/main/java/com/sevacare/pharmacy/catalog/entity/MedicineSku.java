package com.sevacare.pharmacy.catalog.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * A thing this pharmacy can sell.
 *
 * <p>{@code drugPublicId} points at {@code platform.drug_master} and is nullable
 * on purpose: the tenant catalog is sovereign. A store sells surgical gloves and
 * a local ayurvedic syrup that no drug master will ever list, and refusing to
 * stock what we cannot classify would make the software useless on its first day.
 */
@Entity
@Table(name = "medicine_sku")
public class MedicineSku {

    @Id
    @Column(name = "sku_public_id", nullable = false, length = 24)
    private String skuPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 24)
    private String tenantPublicId;

    @Column(name = "drug_public_id", length = 24)
    private String drugPublicId;

    @Column(name = "brand_name", nullable = false, length = 200)
    private String brandName;

    @Column(name = "manufacturer", length = 200)
    private String manufacturer;

    @Column(name = "dosage_form", length = 40)
    private String dosageForm;

    @Column(name = "strength", length = 80)
    private String strength;

    @Column(name = "base_unit", nullable = false, length = 16)
    private String baseUnit = "UNIT";

    @Column(name = "schedule_class", length = 8)
    private String scheduleClass;

    @Column(name = "hsn_code", length = 12)
    private String hsnCode;

    @Column(name = "gst_rate_bp", nullable = false)
    private int gstRateBp;

    @Column(name = "rack_location", length = 40)
    private String rackLocation;

    @Column(name = "reorder_level")
    private Integer reorderLevel;

    @Column(name = "reorder_qty")
    private Integer reorderQty;

    @Column(name = "active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    @Version
    @Column(name = "version", nullable = false)
    private long version;

    public String getSkuPublicId() {
        return skuPublicId;
    }

    public void setSkuPublicId(String skuPublicId) {
        this.skuPublicId = skuPublicId;
    }

    public String getTenantPublicId() {
        return tenantPublicId;
    }

    public void setTenantPublicId(String tenantPublicId) {
        this.tenantPublicId = tenantPublicId;
    }

    public String getDrugPublicId() {
        return drugPublicId;
    }

    public void setDrugPublicId(String drugPublicId) {
        this.drugPublicId = drugPublicId;
    }

    public String getBrandName() {
        return brandName;
    }

    public void setBrandName(String brandName) {
        this.brandName = brandName;
    }

    public String getManufacturer() {
        return manufacturer;
    }

    public void setManufacturer(String manufacturer) {
        this.manufacturer = manufacturer;
    }

    public String getDosageForm() {
        return dosageForm;
    }

    public void setDosageForm(String dosageForm) {
        this.dosageForm = dosageForm;
    }

    public String getStrength() {
        return strength;
    }

    public void setStrength(String strength) {
        this.strength = strength;
    }

    public String getBaseUnit() {
        return baseUnit;
    }

    public void setBaseUnit(String baseUnit) {
        this.baseUnit = baseUnit;
    }

    public String getScheduleClass() {
        return scheduleClass;
    }

    public void setScheduleClass(String scheduleClass) {
        this.scheduleClass = scheduleClass;
    }

    public String getHsnCode() {
        return hsnCode;
    }

    public void setHsnCode(String hsnCode) {
        this.hsnCode = hsnCode;
    }

    public int getGstRateBp() {
        return gstRateBp;
    }

    public void setGstRateBp(int gstRateBp) {
        this.gstRateBp = gstRateBp;
    }

    public String getRackLocation() {
        return rackLocation;
    }

    public void setRackLocation(String rackLocation) {
        this.rackLocation = rackLocation;
    }

    public Integer getReorderLevel() {
        return reorderLevel;
    }

    public void setReorderLevel(Integer reorderLevel) {
        this.reorderLevel = reorderLevel;
    }

    public Integer getReorderQty() {
        return reorderQty;
    }

    public void setReorderQty(Integer reorderQty) {
        this.reorderQty = reorderQty;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public long getVersion() {
        return version;
    }

    public void setVersion(long version) {
        this.version = version;
    }
}
