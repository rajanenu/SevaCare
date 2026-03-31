package com.sevacare.patient.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.Appointment;

public interface AppointmentRepository extends JpaRepository<Appointment, String> {

    List<Appointment> findByTenantPublicIdAndPatientPublicIdOrderByAppointmentSlotDesc(String tenantPublicId, String patientPublicId);

    Optional<Appointment> findByTenantPublicIdAndDoctorPublicIdAndAppointmentSlotAndAppointmentStatus(
            String tenantPublicId,
            String doctorPublicId,
            String appointmentSlot,
            String appointmentStatus
    );

    List<Appointment> findByTenantPublicIdAndDoctorPublicIdOrderByAppointmentSlotDesc(String tenantPublicId, String doctorPublicId);

    List<Appointment> findByTenantPublicIdOrderByAppointmentSlotDesc(String tenantPublicId);

    Optional<Appointment> findByTenantPublicIdAndAppointmentPublicId(String tenantPublicId, String appointmentPublicId);

    long countByTenantPublicIdAndAppointmentStatus(String tenantPublicId, String appointmentStatus);
}
