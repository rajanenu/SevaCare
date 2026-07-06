package com.sevacare.patient.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.Patient;

public interface PatientRepository extends JpaRepository<Patient, String> {

    Optional<Patient> findByPatientPublicIdAndTenantPublicId(String patientPublicId, String tenantPublicId);

    // Batch lookup used to avoid one query per appointment when building a doctor's day queue.
    List<Patient> findByPatientPublicIdInAndTenantPublicId(List<String> patientPublicIds, String tenantPublicId);

    Optional<Patient> findFirstByTenantPublicIdOrderByPatientPublicIdAsc(String tenantPublicId);

    Optional<Patient> findByTenantPublicIdAndMobileNumber(String tenantPublicId, String mobileNumber);

    // Capped at the DB level so a hospital's full patient history can't be pulled into
    // memory in one unbounded query as the tenant grows; admin patient list doesn't need
    // more than the most recent few thousand records at a time.
    java.util.List<Patient> findTop2000ByTenantPublicIdOrderByPatientPublicIdAsc(String tenantPublicId);

    long countByTenantPublicId(String tenantPublicId);
}
