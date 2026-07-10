package com.sevacare.pharmacy.catalog.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * One level of a SKU's pack hierarchy: box, strip, tablet.
 *
 * <p>{@code unitsInPack} is expressed in BASE units, not in the level below it.
 * A box of 10 strips of 10 tablets stores 100, not 10. Storing it relative to
 * the level below saves nothing and means a corrected strip size silently
 * rescales every box ever sold.
 */
@Entity
@Table(name = "sku_pack")
public class SkuPack {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "pack_id")
    private Long packId;

    @Column(name = "sku_public_id", nullable = false, length = 24)
    private String skuPublicId;

    @Column(name = "pack_name", nullable = false, length = 40)
    private String packName;

    @Column(name = "units_in_pack", nullable = false)
    private int unitsInPack;

    @Column(name = "sellable", nullable = false)
    private boolean sellable = true;

    @Column(name = "is_base", nullable = false)
    private boolean base;

    @Column(name = "sort_order", nullable = false)
    private short sortOrder;

    public Long getPackId() {
        return packId;
    }

    public void setPackId(Long packId) {
        this.packId = packId;
    }

    public String getSkuPublicId() {
        return skuPublicId;
    }

    public void setSkuPublicId(String skuPublicId) {
        this.skuPublicId = skuPublicId;
    }

    public String getPackName() {
        return packName;
    }

    public void setPackName(String packName) {
        this.packName = packName;
    }

    public int getUnitsInPack() {
        return unitsInPack;
    }

    public void setUnitsInPack(int unitsInPack) {
        this.unitsInPack = unitsInPack;
    }

    public boolean isSellable() {
        return sellable;
    }

    public void setSellable(boolean sellable) {
        this.sellable = sellable;
    }

    public boolean isBase() {
        return base;
    }

    public void setBase(boolean base) {
        this.base = base;
    }

    public short getSortOrder() {
        return sortOrder;
    }

    public void setSortOrder(short sortOrder) {
        this.sortOrder = sortOrder;
    }
}
