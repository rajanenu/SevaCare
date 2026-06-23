package com.sevacare.patient.service;

import java.time.LocalDateTime;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.sevacare.shared.dto.HospitalManagementDtos;

@Service
public class AppointmentRequestService {

    private final JdbcTemplate jdbc;

    public AppointmentRequestService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public HospitalManagementDtos.AppointmentRequestView submitAppointmentRequest(
            String tenantPublicId,
            String patientMobile,
            HospitalManagementDtos.AppointmentRequestSubmitRequest req
    ) {
        String requestPublicId = "APTREQ-" + ThreadLocalRandom.current().nextInt(1000, 99999);
        LocalDateTime now = LocalDateTime.now();

        jdbc.update(
            "INSERT INTO public.appointment_request " +
            "(request_public_id, tenant_public_id, patient_mobile, patient_name, patient_age, symptoms, doctor_public_id, specialty, preferred_date, request_status, created_at, updated_at) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            requestPublicId, tenantPublicId, patientMobile, req.patientName(), req.patientAge(),
            req.symptoms(), req.doctorPublicId(), req.specialty(), req.preferredDate(), "pending", now, now
        );

        return new HospitalManagementDtos.AppointmentRequestView(
            requestPublicId, patientMobile, req.patientName(), req.patientAge(),
            req.symptoms(), req.doctorPublicId(), req.specialty(),
            req.preferredDate(), "pending", null, null, now, now
        );
    }

    public HospitalManagementDtos.AppointmentRequestCollection getDoctorRequests(
            String tenantPublicId,
            String doctorPublicId
    ) {
        var requests = jdbc.query(
            "SELECT request_public_id, patient_mobile, patient_name, patient_age, symptoms, doctor_public_id, specialty, " +
            "preferred_date, request_status, assigned_slot, notes, created_at, updated_at " +
            "FROM public.appointment_request WHERE tenant_public_id = ? AND doctor_public_id = ? " +
            "ORDER BY CASE WHEN request_status = 'pending' THEN 0 ELSE 1 END, created_at DESC",
            (rs, rowNum) -> new HospitalManagementDtos.AppointmentRequestView(
                rs.getString("request_public_id"),
                rs.getString("patient_mobile"),
                rs.getString("patient_name"),
                rs.getInt("patient_age"),
                rs.getString("symptoms"),
                rs.getString("doctor_public_id"),
                rs.getString("specialty"),
                rs.getDate("preferred_date").toLocalDate(),
                rs.getString("request_status"),
                rs.getString("assigned_slot"),
                rs.getString("notes"),
                rs.getTimestamp("created_at").toLocalDateTime(),
                rs.getTimestamp("updated_at").toLocalDateTime()
            ),
            tenantPublicId, doctorPublicId
        );

        return new HospitalManagementDtos.AppointmentRequestCollection(tenantPublicId, doctorPublicId, requests);
    }

    public HospitalManagementDtos.AppointmentRequestConfirmResponse confirmAndCreateAppointment(
            String tenantPublicId,
            String doctorPublicId,
            String requestPublicId,
            HospitalManagementDtos.AppointmentRequestConfirmRequest confirmReq
    ) {
        LocalDateTime now = LocalDateTime.now();

        // Update request status to confirmed
        jdbc.update(
            "UPDATE public.appointment_request SET request_status = ?, assigned_slot = ?, notes = ?, updated_at = ? " +
            "WHERE request_public_id = ? AND tenant_public_id = ? AND doctor_public_id = ?",
            "confirmed", confirmReq.assignedSlot(), confirmReq.notes(), now,
            requestPublicId, tenantPublicId, doctorPublicId
        );

        // Get patient mobile and details from request
        var requestDetails = jdbc.queryForMap(
            "SELECT patient_mobile, patient_name, patient_age FROM public.appointment_request WHERE request_public_id = ?",
            requestPublicId
        );

        // Create actual appointment in tenant schema
        String appointmentPublicId = "APT-" + ThreadLocalRandom.current().nextInt(1000, 99999);
        String tenantSchema = "tenant_" + tenantPublicId.toLowerCase().replace("-", "_");

        String notes = confirmReq.notes() != null ? confirmReq.notes() : "";
        jdbc.update(
            "INSERT INTO " + tenantSchema + ".appointment " +
            "(appointment_public_id, patient_public_id, doctor_public_id, appointment_slot, appointment_status, notes, tenant_public_id) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            appointmentPublicId, requestDetails.get("patient_mobile"), doctorPublicId,
            confirmReq.assignedSlot(), "confirmed", notes, tenantPublicId
        );

        return new HospitalManagementDtos.AppointmentRequestConfirmResponse(
            requestPublicId, appointmentPublicId, "confirmed", confirmReq.assignedSlot(), now
        );
    }
}
