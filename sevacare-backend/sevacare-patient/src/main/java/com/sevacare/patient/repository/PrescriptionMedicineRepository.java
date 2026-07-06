package com.sevacare.patient.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.PrescriptionMedicine;

public interface PrescriptionMedicineRepository extends JpaRepository<PrescriptionMedicine, Long> {

    List<PrescriptionMedicine> findByPrescriptionPublicId(String prescriptionPublicId);

    // Batch lookup used to avoid one query per prescription when listing a patient's/doctor's prescriptions.
    List<PrescriptionMedicine> findByPrescriptionPublicIdIn(List<String> prescriptionPublicIds);

    void deleteByPrescriptionPublicId(String prescriptionPublicId);
}
