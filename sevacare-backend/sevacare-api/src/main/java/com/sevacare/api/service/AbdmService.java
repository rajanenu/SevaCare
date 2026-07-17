package com.sevacare.api.service;

import java.time.LocalDate;
import java.time.Year;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.sevacare.patient.service.AppointmentRequestService;
import com.sevacare.shared.dto.HospitalManagementDtos;
import com.sevacare.shared.tenant.TenantContext;

/**
 * ABDM (Ayushman Bharat Digital Mission) foundation. The flagship flow is
 * <b>Scan &amp; Share</b>: a patient scans the facility's ABDM counter QR with any
 * PHR app (ABHA, Aarogya Setu, …), consents to share their demographic profile,
 * and the ABDM gateway POSTs that profile to the facility's registered webhook.
 * We resolve the facility (by its Health Facility Registry id →
 * {@code tenant_registry.abdm_hip_id}), and hand the patient to the exact same
 * intake pipeline the QR portal uses — {@code submitAppointmentRequest} with
 * booking source {@code ABDM} — which auto-assigns a queue token. The patient
 * walks from the gate to the waiting area without touching the reception desk.
 *
 * <p>Inert until the org is registered with ABDM: without
 * {@code SEVACARE_ABDM_CLIENT_ID}/{@code SEVACARE_ABDM_CLIENT_SECRET} the
 * webhook answers 404 (the jobs-token pattern), so nothing is exposed. Sandbox
 * registration, HFR enrolment and the M1/M2 milestones are the operator's side
 * of the work — see {@code docs/abdm/ABDM_INTEGRATION.md}.
 */
@Service
public class AbdmService {

    private static final Logger log = LoggerFactory.getLogger(AbdmService.class);

    private final JdbcTemplate jdbcTemplate;
    private final AppointmentRequestService appointmentRequestService;

    @Value("${sevacare.abdm.client-id:}")
    private String clientId;

    @Value("${sevacare.abdm.client-secret:}")
    private String clientSecret;

    @Value("${sevacare.abdm.base-url:https://dev.abdm.gov.in/gateway}")
    private String baseUrl;

    public AbdmService(JdbcTemplate jdbcTemplate, AppointmentRequestService appointmentRequestService) {
        this.jdbcTemplate = jdbcTemplate;
        this.appointmentRequestService = appointmentRequestService;
    }

    public boolean isConfigured() {
        return clientId != null && !clientId.isBlank()
                && clientSecret != null && !clientSecret.isBlank();
    }

    public record ShareAck(String status, String healthId, String tokenNumber, String message) {
    }

    /**
     * Handles the gateway's profile-share callback. Payload shape (v0.5):
     * {@code {requestId, timestamp, intent, metadata: {hipId, context, …},
     * profile: {patient: {name, gender, yearOfBirth, phoneNumber, abhaNumber,
     * abhaAddress, address, …}}}}. Anything absent degrades gracefully — the
     * worst case is a sparser booking-request card for the front desk.
     */
    public ShareAck handleProfileShare(JsonNode payload) {
        String hipId = payload.path("metadata").path("hipId").asText("");
        JsonNode patient = payload.path("profile").path("patient");
        String name = patient.path("name").asText("").trim();
        String mobile = digits(patient.path("phoneNumber").asText(""));
        String abhaNumber = patient.path("abhaNumber").asText("");
        String abhaAddress = patient.path("abhaAddress").asText("");

        if (hipId.isBlank() || name.isBlank() || mobile.length() < 10) {
            log.warn("abdm_share_rejected reason=incomplete_profile hipId={}", hipId);
            return new ShareAck("FAILED", abhaAddress, null, "Profile is missing a name, mobile or facility id");
        }
        if (mobile.length() > 10) {
            mobile = mobile.substring(mobile.length() - 10);
        }

        Map<String, Object> tenant;
        try {
            tenant = jdbcTemplate.queryForMap(
                    "SELECT tenant_public_id, tenant_schema_name FROM public.tenant_registry " +
                    "WHERE abdm_hip_id = ? AND tenant_status = 'active'", hipId);
        } catch (Exception e) {
            log.warn("abdm_share_rejected reason=unknown_hip hipId={}", hipId);
            return new ShareAck("FAILED", abhaAddress, null, "Facility is not registered with this server");
        }
        String tenantPublicId = (String) tenant.get("tenant_public_id");
        String schema = (String) tenant.get("tenant_schema_name");

        // Scan & Share arrives before any doctor is chosen; the front desk (or the
        // patient at the counter) refines it later. Auto-assigning the first doctor
        // mirrors what the chatbot quick-booking does for an unspecified doctor.
        Map<String, Object> doctor;
        try {
            doctor = jdbcTemplate.queryForMap(
                    "SELECT doctor_public_id, specialty FROM " + schema + ".doctor " +
                    "ORDER BY doctor_public_id LIMIT 1");
        } catch (Exception e) {
            log.warn("abdm_share_rejected reason=no_doctors tenantPublicId={}", tenantPublicId);
            return new ShareAck("FAILED", abhaAddress, null, "Facility has no doctors to register against");
        }

        int age = ageFrom(patient.path("yearOfBirth").asInt(0));
        String symptoms = abhaNumber.isBlank()
                ? "Walk-in via ABHA Scan & Share"
                : "Walk-in via ABHA Scan & Share · ABHA " + abhaNumber;

        String previousTenant = TenantContext.tenantPublicId();
        String previousSchema = TenantContext.tenantSchema();
        try {
            TenantContext.set(tenantPublicId, schema);
            HospitalManagementDtos.AppointmentRequestView view =
                    appointmentRequestService.submitAppointmentRequest(
                            tenantPublicId,
                            mobile,
                            new HospitalManagementDtos.AppointmentRequestSubmitRequest(
                                    name,
                                    mobile,
                                    age,
                                    symptoms,
                                    (String) doctor.get("doctor_public_id"),
                                    (String) doctor.get("specialty"),
                                    LocalDate.now()),
                            "ABDM");
            log.info("abdm_share_accepted tenantPublicId={} requestPublicId={}", tenantPublicId, view.requestPublicId());
            return new ShareAck("SUCCESS",
                    abhaAddress.isBlank() ? abhaNumber : abhaAddress,
                    view.requestPublicId(),
                    "Registered — please proceed to the reception desk");
        } catch (Exception e) {
            log.error("abdm_share_failed tenantPublicId={} reason={}", tenantPublicId, e.getMessage());
            return new ShareAck("FAILED", abhaAddress, null, "Could not register the visit");
        } finally {
            if (previousTenant != null && previousSchema != null) {
                TenantContext.set(previousTenant, previousSchema);
            } else {
                TenantContext.clear();
            }
        }
    }

    private static int ageFrom(int yearOfBirth) {
        if (yearOfBirth < 1900) {
            return 30; // profile withheld the birth year; a plausible default beats a rejection
        }
        return Math.max(1, Year.now().getValue() - yearOfBirth);
    }

    private static String digits(String raw) {
        return raw == null ? "" : raw.replaceAll("\\D", "");
    }
}
