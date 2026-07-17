package com.sevacare.patient.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.AppointmentAttachment;

public interface AppointmentAttachmentRepository extends JpaRepository<AppointmentAttachment, String> {

    List<AppointmentAttachment> findByTenantPublicIdAndAppointmentPublicId(String tenantPublicId, String appointmentPublicId);

    // Batch lookup used to avoid one query per appointment when building a doctor's day queue.
    List<AppointmentAttachment> findByTenantPublicIdAndAppointmentPublicIdIn(String tenantPublicId, List<String> appointmentPublicIds);

    // Single attachment, fetched on demand when the doctor actually opens it — this
    // is the only read path that pulls the (potentially large) data_base64 bytes.
    Optional<AppointmentAttachment> findByTenantPublicIdAndAttachmentPublicId(String tenantPublicId, String attachmentPublicId);

    /**
     * Metadata only — never the bytes. The doctor's day queue is polled every 20s
     * and used to re-ship every attachment's full base64 payload on every poll.
     * A closed interface projection makes Spring Data select only these columns,
     * leaving data_base64 in the database until it is actually viewed.
     */
    List<AttachmentMeta> findMetaByTenantPublicIdAndAppointmentPublicIdIn(String tenantPublicId, List<String> appointmentPublicIds);

    interface AttachmentMeta {
        String getAttachmentPublicId();
        String getAppointmentPublicId();
        String getFileName();
        String getMimeType();
        String getUploadedBy();
    }
}
