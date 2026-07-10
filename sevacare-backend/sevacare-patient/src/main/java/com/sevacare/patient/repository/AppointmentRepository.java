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

    /**
     * Appointments in a slot window, for the reminder sweep. appointment_slot is
     * stored as "yyyy-MM-dd HH:mm", so a lexicographic BETWEEN is also a
     * chronological one — which lets the database do the filtering instead of
     * the scheduler pulling every appointment the tenant has ever had.
     */
    List<Appointment> findByTenantPublicIdAndAppointmentStatusAndAppointmentSlotBetween(
            String tenantPublicId,
            String appointmentStatus,
            String slotFrom,
            String slotTo
    );

    Optional<Appointment> findByTenantPublicIdAndAppointmentPublicId(String tenantPublicId, String appointmentPublicId);

    long countByTenantPublicIdAndAppointmentStatus(String tenantPublicId, String appointmentStatus);
}
