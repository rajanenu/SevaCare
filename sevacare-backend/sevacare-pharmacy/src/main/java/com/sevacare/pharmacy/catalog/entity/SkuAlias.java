package com.sevacare.pharmacy.catalog.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * A name this pharmacy's people actually use for a SKU: the doctor's shorthand,
 * the customer's word for it, the barcode on the carton.
 *
 * <p>{@code hitCount} is what turns the alias table into a ranking signal — the
 * scrawl a resolution engine sees fifty times a week should outrank the one it
 * saw once. Every confirmed resolution writes a row here, so the tenant's own
 * vocabulary accumulates into an asset (and, honestly, a switching cost).
 */
@Entity
@Table(name = "sku_alias")
public class SkuAlias {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "alias_id")
    private Long aliasId;

    @Column(name = "sku_public_id", nullable = false, length = 24)
    private String skuPublicId;

    @Column(name = "alias", nullable = false, length = 200)
    private String alias;

    /** MANUAL | LEARNED | BARCODE | IMPORT */
    @Column(name = "alias_kind", nullable = false, length = 16)
    private String aliasKind = "MANUAL";

    @Column(name = "hit_count", nullable = false)
    private int hitCount;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getAliasId() {
        return aliasId;
    }

    public void setAliasId(Long aliasId) {
        this.aliasId = aliasId;
    }

    public String getSkuPublicId() {
        return skuPublicId;
    }

    public void setSkuPublicId(String skuPublicId) {
        this.skuPublicId = skuPublicId;
    }

    public String getAlias() {
        return alias;
    }

    public void setAlias(String alias) {
        this.alias = alias;
    }

    public String getAliasKind() {
        return aliasKind;
    }

    public void setAliasKind(String aliasKind) {
        this.aliasKind = aliasKind;
    }

    public int getHitCount() {
        return hitCount;
    }

    public void setHitCount(int hitCount) {
        this.hitCount = hitCount;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
