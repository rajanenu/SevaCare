package com.sevacare.patient.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.HospitalManagementDtos;

@Service
public class AppointmentRequestService {

    private final JdbcTemplate jdbc;
    private final PatientDomainService patientDomainService;

    public AppointmentRequestService(JdbcTemplate jdbc, PatientDomainService patientDomainService) {
        this.jdbc = jdbc;
        this.patientDomainService = patientDomainService;
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

    @Transactional
    public HospitalManagementDtos.AppointmentRequestConfirmResponse confirmAndCreateAppointment(
            String tenantPublicId,
            String doctorPublicId,
            String requestPublicId,
            HospitalManagementDtos.AppointmentRequestConfirmRequest confirmReq
    ) {
        List<PendingRequestRow> rows = jdbc.query(
            "SELECT patient_mobile, patient_name, patient_age, specialty, preferred_date, request_status " +
            "FROM public.appointment_request WHERE request_public_id = ? AND tenant_public_id = ? AND doctor_public_id = ?",
            (rs, rowNum) -> new PendingRequestRow(
                rs.getString("patient_mobile"),
                rs.getString("patient_name"),
                rs.getInt("patient_age"),
                rs.getString("specialty"),
                rs.getDate("preferred_date").toLocalDate(),
                rs.getString("request_status")
            ),
            requestPublicId, tenantPublicId, doctorPublicId
        );

        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Appointment request not found: " + requestPublicId);
        }
        PendingRequestRow row = rows.get(0);
        if (!"pending".equals(row.requestStatus())) {
            throw new IllegalStateException("Appointment request is already " + row.requestStatus());
        }

        // Creates a real patient + appointment via the same path as the patient app and
        // IP-Staff, so the confirmed QR patient shows up in the doctor's queue/consult
        // screen, the IP-Staff patient list, and admin totals — not just this table.
        var bookingResult = patientDomainService.confirmQrAppointmentRequest(
            tenantPublicId,
            doctorPublicId,
            row.patientMobile(),
            row.patientName(),
            row.patientAge(),
            row.specialty(),
            row.preferredDate(),
            confirmReq
        );

        String assignedSlotDisplay = "TOKEN".equals(bookingResult.bookingType())
            ? "Token #" + bookingResult.tokenNumber() + " · " + bookingResult.tokenSession()
                + " · " + bookingResult.slot()
            : bookingResult.slot();

        LocalDateTime now = LocalDateTime.now();
        int updated = jdbc.update(
            "UPDATE public.appointment_request SET request_status = ?, assigned_slot = ?, notes = ?, " +
            "appointment_public_id = ?, updated_at = ? " +
            "WHERE request_public_id = ? AND tenant_public_id = ? AND doctor_public_id = ? AND request_status = 'pending'",
            "confirmed", assignedSlotDisplay, confirmReq.notes(), bookingResult.appointmentPublicId(), now,
            requestPublicId, tenantPublicId, doctorPublicId
        );

        if (updated == 0) {
            throw new IllegalStateException("Appointment request was already confirmed by another request");
        }

        return new HospitalManagementDtos.AppointmentRequestConfirmResponse(
            requestPublicId, bookingResult.appointmentPublicId(), "confirmed", assignedSlotDisplay, now
        );
    }

    private record PendingRequestRow(
        String patientMobile,
        String patientName,
        int patientAge,
        String specialty,
        LocalDate preferredDate,
        String requestStatus
    ) {
    }
}
