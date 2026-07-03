package com.sevacare.patient.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.AppointmentAttachment;

public interface AppointmentAttachmentRepository extends JpaRepository<AppointmentAttachment, String> {

    List<AppointmentAttachment> findByTenantPublicIdAndAppointmentPublicId(String tenantPublicId, String appointmentPublicId);
}
