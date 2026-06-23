package com.sevacare.tenant.service;

import java.time.LocalDateTime;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.sevacare.shared.dto.HospitalManagementDtos;

@Service
public class HospitalManagementService {

    private final JdbcTemplate jdbc;

    public HospitalManagementService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ==================== Hospital Admin Enrollment ====================
    public HospitalManagementDtos.HospitalAdminEnrollView enrollHospitalAdmin(String tenantPublicId, HospitalManagementDtos.HospitalAdminEnrollRequest req) {
        String adminEnrollmentPublicId = "HA-" + ThreadLocalRandom.current().nextInt(1000, 99999);
        LocalDateTime now = LocalDateTime.now();
        boolean active = req.active();

        jdbc.update(
            "INSERT INTO public.hospital_admin_enrollment (admin_enrollment_public_id, tenant_public_id, hospital_admin_mobile, hospital_admin_name, active, enrolled_at) " +
            "VALUES (?, ?, ?, ?, ?, ?) " +
            "ON CONFLICT (hospital_admin_mobile) DO UPDATE SET active = EXCLUDED.active, hospital_admin_name = EXCLUDED.hospital_admin_name",
            adminEnrollmentPublicId, tenantPublicId, req.hospitalAdminMobile(), req.hospitalAdminName(), active, now
        );

        return new HospitalManagementDtos.HospitalAdminEnrollView(adminEnrollmentPublicId, tenantPublicId, req.hospitalAdminMobile(), req.hospitalAdminName(), active, now);
    }

    public HospitalManagementDtos.HospitalAdminEnrollCollection listHospitalAdmins(String tenantPublicId) {
        var admins = jdbc.query(
            "SELECT admin_enrollment_public_id, tenant_public_id, hospital_admin_mobile, hospital_admin_name, active, enrolled_at " +
            "FROM public.hospital_admin_enrollment WHERE tenant_public_id = ? ORDER BY enrolled_at DESC",
            (rs, rowNum) -> new HospitalManagementDtos.HospitalAdminEnrollView(
                rs.getString("admin_enrollment_public_id"),
                rs.getString("tenant_public_id"),
                rs.getString("hospital_admin_mobile"),
                rs.getString("hospital_admin_name"),
                rs.getBoolean("active"),
                rs.getTimestamp("enrolled_at").toLocalDateTime()
            ),
            tenantPublicId
        );

        return new HospitalManagementDtos.HospitalAdminEnrollCollection(tenantPublicId, admins);
    }

    // ==================== Doctor Enrollment ====================
    public HospitalManagementDtos.DoctorEnrollView enrollDoctor(String tenantPublicId, HospitalManagementDtos.DoctorEnrollRequest req) {
        String doctorEnrollmentPublicId = "DE-" + ThreadLocalRandom.current().nextInt(1000, 99999);
        LocalDateTime now = LocalDateTime.now();
        boolean active = req.active();

        jdbc.update(
            "INSERT INTO public.doctor_hospital_enrollment (doctor_enrollment_public_id, tenant_public_id, doctor_mobile, doctor_name, specialty, active, enrolled_at) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?) " +
            "ON CONFLICT (tenant_public_id, doctor_mobile) DO UPDATE SET active = EXCLUDED.active, doctor_name = EXCLUDED.doctor_name, specialty = EXCLUDED.specialty",
            doctorEnrollmentPublicId, tenantPublicId, req.doctorMobile(), req.doctorName(), req.specialty(), active, now
        );

        return new HospitalManagementDtos.DoctorEnrollView(doctorEnrollmentPublicId, tenantPublicId, req.doctorMobile(), req.doctorName(), req.specialty(), active, now);
    }

    public HospitalManagementDtos.DoctorEnrollCollection listDoctors(String tenantPublicId) {
        var doctors = jdbc.query(
            "SELECT doctor_enrollment_public_id, tenant_public_id, doctor_mobile, doctor_name, specialty, active, enrolled_at " +
            "FROM public.doctor_hospital_enrollment WHERE tenant_public_id = ? AND active = true ORDER BY enrolled_at DESC",
            (rs, rowNum) -> new HospitalManagementDtos.DoctorEnrollView(
                rs.getString("doctor_enrollment_public_id"),
                rs.getString("tenant_public_id"),
                rs.getString("doctor_mobile"),
                rs.getString("doctor_name"),
                rs.getString("specialty"),
                rs.getBoolean("active"),
                rs.getTimestamp("enrolled_at").toLocalDateTime()
            ),
            tenantPublicId
        );

        return new HospitalManagementDtos.DoctorEnrollCollection(tenantPublicId, doctors);
    }

    // ==================== Hospital QR Code ====================
    public HospitalManagementDtos.HospitalQRCodeGenerateResponse generateOrGetQRCode(String tenantPublicId) {
        var existing = jdbc.query(
            "SELECT qrcode_public_id, qrcode_uuid FROM public.hospital_qrcode WHERE tenant_public_id = ? LIMIT 1",
            (rs, rowNum) -> new Object[] { rs.getString("qrcode_public_id"), rs.getString("qrcode_uuid") },
            tenantPublicId
        );

        if (!existing.isEmpty()) {
            Object[] row = existing.get(0);
            return new HospitalManagementDtos.HospitalQRCodeGenerateResponse((String) row[0], tenantPublicId, (String) row[1]);
        }

        String qrcodePublicId = "QR-" + ThreadLocalRandom.current().nextInt(1000, 99999);
        String qrcodeUuid = UUID.randomUUID().toString();

        jdbc.update(
            "INSERT INTO public.hospital_qrcode (qrcode_public_id, tenant_public_id, qrcode_uuid, created_at) VALUES (?, ?, ?, ?)",
            qrcodePublicId, tenantPublicId, qrcodeUuid, LocalDateTime.now()
        );

        return new HospitalManagementDtos.HospitalQRCodeGenerateResponse(qrcodePublicId, tenantPublicId, qrcodeUuid);
    }

    public HospitalManagementDtos.HospitalQRCodeView getQRCodeByUuid(String qrcodeUuid) {
        var result = jdbc.query(
            "SELECT qrcode_public_id, tenant_public_id, qrcode_uuid, qrcode_url, created_at FROM public.hospital_qrcode WHERE qrcode_uuid = ?",
            (rs, rowNum) -> new HospitalManagementDtos.HospitalQRCodeView(
                rs.getString("qrcode_public_id"),
                rs.getString("tenant_public_id"),
                rs.getString("qrcode_uuid"),
                rs.getString("qrcode_url"),
                rs.getTimestamp("created_at").toLocalDateTime()
            ),
            qrcodeUuid
        );

        return result.isEmpty() ? null : result.get(0);
    }

    public HospitalManagementDtos.QRCodeFormDataResponse getQRCodeFormData(String qrcodeUuid) {
        var qrcode = getQRCodeByUuid(qrcodeUuid);
        if (qrcode == null) {
            throw new IllegalArgumentException("QR Code not found: " + qrcodeUuid);
        }

        String tenantPublicId = qrcode.tenantPublicId();
        String tenantName = jdbc.queryForObject(
            "SELECT tenant_name FROM public.tenant_registry WHERE tenant_public_id = ?",
            String.class,
            tenantPublicId
        );

        var doctors = jdbc.query(
            "SELECT doctor_enrollment_public_id, doctor_name, specialty FROM public.doctor_hospital_enrollment " +
            "WHERE tenant_public_id = ? AND active = true ORDER BY doctor_name",
            (rs, rowNum) -> new HospitalManagementDtos.QRCodeFormDataResponse.DoctorOption(
                rs.getString("doctor_enrollment_public_id"),
                rs.getString("doctor_name"),
                rs.getString("specialty")
            ),
            tenantPublicId
        );

        return new HospitalManagementDtos.QRCodeFormDataResponse(tenantPublicId, tenantName, doctors);
    }
}
