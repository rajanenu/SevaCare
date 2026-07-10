package com.sevacare.pharmacy.catalog.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.pharmacy.catalog.entity.SkuAlias;

public interface SkuAliasRepository extends JpaRepository<SkuAlias, Long> {

    List<SkuAlias> findBySkuPublicId(String skuPublicId);
}
