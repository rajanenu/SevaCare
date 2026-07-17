package com.sevacare.patient.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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

    /**
     * One day of a doctor's queue, filtered in SQL. This backs the doctor's main
     * dashboard, polled every 20 seconds — it used to pull the doctor's entire
     * appointment history and pick the day out in memory, so the hospital's
     * busiest screen got slower with every appointment ever booked.
     */
    List<Appointment> findByTenantPublicIdAndDoctorPublicIdAndAppointmentSlotBetween(
            String tenantPublicId, String doctorPublicId, String slotFrom, String slotTo);

    List<Appointment> findByTenantPublicIdAndDoctorPublicIdAndAppointmentStatusOrderByAppointmentSlotDesc(
            String tenantPublicId, String doctorPublicId, String appointmentStatus);

    /**
     * Which of these patients has seen this doctor before the given slot — one
     * batch query for the whole day's queue, feeding the follow-up badge.
     */
    @Query("""
            SELECT DISTINCT a.patientPublicId FROM Appointment a
            WHERE a.tenantPublicId = :tenantPublicId AND a.doctorPublicId = :doctorPublicId
              AND a.patientPublicId IN :patientPublicIds AND a.appointmentSlot < :slotBefore
            """)
    List<String> findPatientIdsSeenBefore(
            @Param("tenantPublicId") String tenantPublicId,
            @Param("doctorPublicId") String doctorPublicId,
            @Param("patientPublicIds") List<String> patientPublicIds,
            @Param("slotBefore") String slotBefore);

    /**
     * A doctor's distinct patients with each one's latest visit, aggregated in
     * SQL instead of materialising the full appointment history.
     */
    @Query("""
            SELECT a.patientPublicId, MAX(a.appointmentSlot) FROM Appointment a
            WHERE a.tenantPublicId = :tenantPublicId AND a.doctorPublicId = :doctorPublicId
            GROUP BY a.patientPublicId ORDER BY MAX(a.appointmentSlot) DESC
            """)
    List<Object[]> findDistinctPatientsWithLatestSlot(
            @Param("tenantPublicId") String tenantPublicId,
            @Param("doctorPublicId") String doctorPublicId);

    List<Appointment> findByTenantPublicIdOrderByAppointmentSlotDesc(String tenantPublicId);

    List<Appointment> findTop500ByTenantPublicIdOrderByAppointmentSlotDesc(String tenantPublicId);

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
