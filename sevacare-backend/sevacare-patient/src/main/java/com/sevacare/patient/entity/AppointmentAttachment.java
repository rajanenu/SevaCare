package com.sevacare.patient.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "appointment_attachment")
public class AppointmentAttachment {

    @Id
    @Column(name = "attachment_public_id", nullable = false, length = 40)
    private String attachmentPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "appointment_public_id", nullable = false, length = 16)
    private String appointmentPublicId;

    @Column(name = "file_name", nullable = false, length = 200)
    private String fileName;

    @Column(name = "mime_type", nullable = false, length = 80)
    private String mimeType;

    @JdbcTypeCode(SqlTypes.LONGVARCHAR)
    @Column(name = "data_base64", nullable = false)
    private String dataBase64;

    @Column(name = "uploaded_by", nullable = false, length = 16)
    private String uploadedBy;

    public String getAttachmentPublicId() {
        return attachmentPublicId;
    }

    public void setAttachmentPublicId(String attachmentPublicId) {
        this.attachmentPublicId = attachmentPublicId;
    }

    public String getTenantPublicId() {
        return tenantPublicId;
    }

    public void setTenantPublicId(String tenantPublicId) {
        this.tenantPublicId = tenantPublicId;
    }

    public String getAppointmentPublicId() {
        return appointmentPublicId;
    }

    public void setAppointmentPublicId(String appointmentPublicId) {
        this.appointmentPublicId = appointmentPublicId;
    }

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
    }

    public String getMimeType() {
        return mimeType;
    }

    public void setMimeType(String mimeType) {
        this.mimeType = mimeType;
    }

    public String getDataBase64() {
        return dataBase64;
    }

    public void setDataBase64(String dataBase64) {
        this.dataBase64 = dataBase64;
    }

    public String getUploadedBy() {
        return uploadedBy;
    }

    public void setUploadedBy(String uploadedBy) {
        this.uploadedBy = uploadedBy;
    }
}
