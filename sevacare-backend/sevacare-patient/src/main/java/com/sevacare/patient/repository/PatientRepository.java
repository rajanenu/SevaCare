package com.sevacare.patient.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.Patient;

public interface PatientRepository extends JpaRepository<Patient, String> {

    Optional<Patient> findByPatientPublicIdAndTenantPublicId(String patientPublicId, String tenantPublicId);

    Optional<Patient> findFirstByTenantPublicIdOrderByPatientPublicIdAsc(String tenantPublicId);

    Optional<Patient> findByTenantPublicIdAndMobileNumber(String tenantPublicId, String mobileNumber);

    java.util.List<Patient> findByTenantPublicIdOrderByPatientPublicIdAsc(String tenantPublicId);
}
