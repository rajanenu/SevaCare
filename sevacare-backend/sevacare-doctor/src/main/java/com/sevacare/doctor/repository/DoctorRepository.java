package com.sevacare.doctor.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.doctor.entity.Doctor;

public interface DoctorRepository extends JpaRepository<Doctor, String> {

    List<Doctor> findByTenantPublicIdAndActiveTrueOrderByDoctorPublicIdAsc(String tenantPublicId);

    Optional<Doctor> findByDoctorPublicIdAndTenantPublicId(String doctorPublicId, String tenantPublicId);

    Optional<Doctor> findFirstByTenantPublicIdAndActiveTrueOrderByDoctorPublicIdAsc(String tenantPublicId);

    Optional<Doctor> findFirstByTenantPublicIdAndMobileNumberAndActiveTrueOrderByDoctorPublicIdAsc(String tenantPublicId, String mobileNumber);

    boolean existsByTenantPublicIdAndMobileNumberAndActiveTrue(String tenantPublicId, String mobileNumber);

    List<Doctor> findByTenantPublicIdOrderByDoctorPublicIdAsc(String tenantPublicId);

    List<Doctor> findByTenantPublicIdAndSpecialtyAndActiveTrueOrderByDoctorPublicIdAsc(
            String tenantPublicId, String specialty);
}
