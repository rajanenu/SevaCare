package com.sevacare.patient.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.Prescription;

public interface PrescriptionRepository extends JpaRepository<Prescription, String> {

    List<Prescription> findByTenantPublicIdAndPatientPublicIdOrderByPrescriptionPublicIdAsc(String tenantPublicId, String patientPublicId);

    Optional<Prescription> findByTenantPublicIdAndPrescriptionPublicId(String tenantPublicId, String prescriptionPublicId);

    List<Prescription> findByTenantPublicIdAndDoctorPublicId(String tenantPublicId, String doctorPublicId);

    /**
     * The doctor's prescriptions screen shows recent work, not an archive — cap
     * the read so it stops growing with every consult the doctor has ever done.
     */
    List<Prescription> findTop200ByTenantPublicIdAndDoctorPublicIdOrderByCreatedAtDesc(
            String tenantPublicId, String doctorPublicId);

    Optional<Prescription> findByTenantPublicIdAndDoctorPublicIdAndAppointmentPublicId(
            String tenantPublicId,
            String doctorPublicId,
            String appointmentPublicId
    );

    List<Prescription> findByTenantPublicIdAndDoctorPublicIdAndPatientPublicIdOrderByCreatedAtDesc(
            String tenantPublicId,
            String doctorPublicId,
            String patientPublicId
    );

    long countByTenantPublicId(String tenantPublicId);

    List<Prescription> findByTenantPublicIdOrderByCreatedAtDesc(String tenantPublicId);

    List<Prescription> findByTenantPublicIdAndCreatedAtAfter(String tenantPublicId, LocalDateTime since);
}
