package com.sevacare.pharmacy.catalog.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.pharmacy.catalog.entity.SkuPack;

public interface SkuPackRepository extends JpaRepository<SkuPack, Long> {

    List<SkuPack> findBySkuPublicIdOrderBySortOrderAsc(String skuPublicId);
}
