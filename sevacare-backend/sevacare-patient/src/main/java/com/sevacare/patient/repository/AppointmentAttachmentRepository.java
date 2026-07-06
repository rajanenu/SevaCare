package com.sevacare.patient.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.AppointmentAttachment;

public interface AppointmentAttachmentRepository extends JpaRepository<AppointmentAttachment, String> {

    List<AppointmentAttachment> findByTenantPublicIdAndAppointmentPublicId(String tenantPublicId, String appointmentPublicId);

    // Batch lookup used to avoid one query per appointment when building a doctor's day queue.
    List<AppointmentAttachment> findByTenantPublicIdAndAppointmentPublicIdIn(String tenantPublicId, List<String> appointmentPublicIds);
}
