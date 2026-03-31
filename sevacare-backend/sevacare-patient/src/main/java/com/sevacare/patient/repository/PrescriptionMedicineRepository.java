package com.sevacare.patient.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.PrescriptionMedicine;

public interface PrescriptionMedicineRepository extends JpaRepository<PrescriptionMedicine, Long> {

    List<PrescriptionMedicine> findByPrescriptionPublicId(String prescriptionPublicId);
    
    void deleteByPrescriptionPublicId(String prescriptionPublicId);
}
