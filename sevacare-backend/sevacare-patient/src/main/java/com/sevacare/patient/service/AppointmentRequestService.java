package com.sevacare.patient.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ThreadLocalRandom;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.HospitalManagementDtos;
import com.sevacare.shared.tenant.TenantContext;

@Service
public class AppointmentRequestService {

    private static final Logger log = LoggerFactory.getLogger(AppointmentRequestService.class);

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
        return submitAppointmentRequest(tenantPublicId, patientMobile, req, "QR_CODE");
    }

    /**
     * Stores the request and immediately auto-confirms it: the next available
     * token for the preferred date is booked with no doctor input, and the
     * request lands in the doctor's inbox already confirmed. If auto-confirm
     * fails for any reason (doctor on leave, date validation, …) the request
     * stays pending so the doctor can confirm it manually — nothing is lost.
     */
    public HospitalManagementDtos.AppointmentRequestView submitAppointmentRequest(
            String tenantPublicId,
            String patientMobile,
            HospitalManagementDtos.AppointmentRequestSubmitRequest req,
            String bookingSource
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

        try {
            var confirmReq = new HospitalManagementDtos.AppointmentRequestConfirmRequest(
                "TOKEN", null, autoSession(req.preferredDate()), null);

            // Public endpoints carry no tenant context, but token numbering and
            // appointment creation live in the tenant schema — set it explicitly
            // for the confirm call and restore whatever was there before.
            String prevTenant = TenantContext.tenantPublicId();
            String prevSchema = prevTenant == null ? null : TenantContext.tenantSchema();
            TenantContext.set(tenantPublicId, schemaFor(tenantPublicId));
            HospitalManagementDtos.AppointmentRequestConfirmResponse confirmed;
            try {
                confirmed = confirmAndCreateAppointment(
                    tenantPublicId, req.doctorPublicId(), requestPublicId, confirmReq, bookingSource);
            } finally {
                if (prevTenant == null) {
                    TenantContext.clear();
                } else {
                    TenantContext.set(prevTenant, prevSchema);
                }
            }

            return new HospitalManagementDtos.AppointmentRequestView(
                requestPublicId, patientMobile, req.patientName(), req.patientAge(),
                req.symptoms(), req.doctorPublicId(), req.specialty(),
                req.preferredDate(), confirmed.requestStatus(), confirmed.assignedSlot(), null,
                now, confirmed.updatedAt()
            );
        } catch (Exception e) {
            // The request survives as pending so the doctor can confirm manually, but
            // a patient who expected a token just got "we'll call you" instead — log
            // the stack so the cause is visible rather than inferred.
            log.warn("appointment_request_autoconfirm_failed requestPublicId={} tenantPublicId={} source={} reason={}",
                requestPublicId, tenantPublicId, bookingSource, e.getMessage(), e);
        }

        return new HospitalManagementDtos.AppointmentRequestView(
            requestPublicId, patientMobile, req.patientName(), req.patientAge(),
            req.symptoms(), req.doctorPublicId(), req.specialty(),
            req.preferredDate(), "pending", null, null, now, now
        );
    }

    /** Morning token unless the preferred date is today and the morning OPD window is over. */
    private static String autoSession(LocalDate preferredDate) {
        if (LocalDate.now().equals(preferredDate) && !LocalTime.now().isBefore(LocalTime.of(14, 0))) {
            return "EVENING";
        }
        return "MORNING";
    }

    /** Postgres schema for a tenant, e.g. T-1013 → tenant_t_1013 (same rule as HospitalManagementService). */
    private static String schemaFor(String tenantPublicId) {
        return "tenant_" + tenantPublicId.toLowerCase(Locale.ROOT).replace("-", "_");
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
        return confirmAndCreateAppointment(tenantPublicId, doctorPublicId, requestPublicId, confirmReq, "QR_CODE");
    }

    @Transactional
    public HospitalManagementDtos.AppointmentRequestConfirmResponse confirmAndCreateAppointment(
            String tenantPublicId,
            String doctorPublicId,
            String requestPublicId,
            HospitalManagementDtos.AppointmentRequestConfirmRequest confirmReq,
            String bookingSource
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
            confirmReq,
            bookingSource
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
