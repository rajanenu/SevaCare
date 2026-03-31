package com.sevacare.patient.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.MedicalHistory;

public interface MedicalHistoryRepository extends JpaRepository<MedicalHistory, Long> {

    List<MedicalHistory> findByTenantPublicIdAndPatientPublicId(String tenantPublicId, String patientPublicId);

    List<MedicalHistory> findByTenantPublicIdAndPatientPublicIdAndRecordType(
            String tenantPublicId,
            String patientPublicId,
            String recordType
    );
}
