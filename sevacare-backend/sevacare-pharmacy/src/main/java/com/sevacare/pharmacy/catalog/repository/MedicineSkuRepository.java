package com.sevacare.pharmacy.catalog.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.pharmacy.catalog.entity.MedicineSku;

public interface MedicineSkuRepository extends JpaRepository<MedicineSku, String> {
}
