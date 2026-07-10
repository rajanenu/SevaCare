package com.sevacare.patient.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.patient.entity.Appointment;
import com.sevacare.patient.entity.AppointmentAttachment;
import com.sevacare.patient.entity.DoctorReview;
import com.sevacare.patient.entity.MedicalHistory;
import com.sevacare.patient.entity.Patient;
import com.sevacare.patient.entity.Prescription;
import com.sevacare.patient.entity.PrescriptionMedicine;
import com.sevacare.patient.repository.AppointmentAttachmentRepository;
import com.sevacare.patient.repository.AppointmentRepository;
import com.sevacare.patient.repository.DoctorReviewRepository;
import com.sevacare.patient.repository.MedicalHistoryRepository;
import com.sevacare.patient.repository.PatientRepository;
import com.sevacare.patient.repository.PrescriptionMedicineRepository;
import com.sevacare.patient.repository.PrescriptionRepository;
import com.sevacare.shared.dto.HospitalManagementDtos;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.shared.tenant.TenantContext;

@Service
public class PatientDomainService {

    private static final Logger log = LoggerFactory.getLogger(PatientDomainService.class);

    private final PatientRepository patientRepository;
    private final AppointmentRepository appointmentRepository;
    private final PrescriptionRepository prescriptionRepository;
    private final PrescriptionMedicineRepository prescriptionMedicineRepository;
    private final MedicalHistoryRepository medicalHistoryRepository;
    private final AppointmentAttachmentRepository appointmentAttachmentRepository;
    private final DoctorReviewRepository doctorReviewRepository;
        private final JdbcTemplate jdbcTemplate;
        private final WhatsAppService whatsAppService;

    public PatientDomainService(
            PatientRepository patientRepository,
            AppointmentRepository appointmentRepository,
            PrescriptionRepository prescriptionRepository,
            PrescriptionMedicineRepository prescriptionMedicineRepository,
                        MedicalHistoryRepository medicalHistoryRepository,
                        AppointmentAttachmentRepository appointmentAttachmentRepository,
                        DoctorReviewRepository doctorReviewRepository,
                        JdbcTemplate jdbcTemplate,
                        WhatsAppService whatsAppService
    ) {
        this.patientRepository = patientRepository;
        this.appointmentRepository = appointmentRepository;
        this.prescriptionRepository = prescriptionRepository;
        this.prescriptionMedicineRepository = prescriptionMedicineRepository;
        this.medicalHistoryRepository = medicalHistoryRepository;
        this.appointmentAttachmentRepository = appointmentAttachmentRepository;
        this.doctorReviewRepository = doctorReviewRepository;
                this.jdbcTemplate = jdbcTemplate;
                this.whatsAppService = whatsAppService;
    }

        /** Hospital display name, used as the sender identity in outbound WhatsApp messages. */
        private String hospitalNameOf(String tenantPublicId) {
                try {
                        return jdbcTemplate.query(
                                        "SELECT tenant_name FROM public.tenant_registry WHERE tenant_public_id = ? LIMIT 1",
                                        rs -> rs.next() ? rs.getString("tenant_name") : null,
                                        tenantPublicId);
                } catch (Exception e) {
                        return null;
                }
        }

        private String doctorNameOf(String doctorPublicId) {
                try {
                        return jdbcTemplate.query(
                                        "SELECT full_name FROM " + TenantContext.tenantSchema() + ".doctor WHERE doctor_public_id = ? LIMIT 1",
                                        rs -> rs.next() ? rs.getString("full_name") : null,
                                        doctorPublicId);
                } catch (Exception e) {
                        return null;
                }
        }

    @Transactional(readOnly = true)
    public PatientDtos.PatientHomeView home(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));

        List<PatientDtos.AppointmentView> appointments = appointmentRepository.findByTenantPublicIdAndPatientPublicIdOrderByAppointmentSlotDesc(tenantPublicId, patient.getPatientPublicId())
                .stream()
                .map(item -> new PatientDtos.AppointmentView(
                        item.getAppointmentPublicId(),
                        item.getDoctorPublicId(),
                        item.getDoctorPublicId(),
                        item.getAppointmentSlot(),
                        item.getAppointmentStatus(),
                        item.getNotes(),
                        item.getBookingType(),
                        item.getTokenNumber(),
                        item.getTokenSession()
                ))
                .toList();

        List<PatientDtos.PrescriptionView> prescriptions = prescriptionRepository.findByTenantPublicIdAndPatientPublicIdOrderByPrescriptionPublicIdAsc(tenantPublicId, patient.getPatientPublicId())
                .stream()
                .map(item -> new PatientDtos.PrescriptionView(
                        item.getPrescriptionPublicId(),
                        item.getDoctorPublicId(),
                        item.getDoctorName(),
                        item.getIssuedOn(),
                        List.of(item.getNotes())
                ))
                .toList();

        return new PatientDtos.PatientHomeView(patientPublicId, tenantPublicId, appointments, prescriptions);
    }

        @Transactional(readOnly = true)
        public PatientDtos.BookingSetupView bookingSetup(String tenantPublicId, List<String> specialties) {
                List<String> normalized = specialties.stream()
                                .map(value -> value == null ? "" : value.trim())
                                .filter(value -> !value.isBlank())
                                .map(value -> value.substring(0, 1).toUpperCase(Locale.ROOT) + value.substring(1))
                                .distinct()
                                .toList();

                // Build available dates: today + next 2 weeks
                LocalDate today = LocalDate.now();
                List<String> availableDates = new ArrayList<>();
                for (int i = 0; i <= 14; i++) {
                        availableDates.add(today.plusDays(i).toString());
                }

                // Build time slots: Morning 09:00-14:00, Evening 17:00-21:00 in 15-min intervals
                List<String> morningSlots = new ArrayList<>();
                LocalTime morningStart = LocalTime.of(9, 0);
                LocalTime morningEnd = LocalTime.of(14, 0);
                for (LocalTime t = morningStart; t.isBefore(morningEnd); t = t.plusMinutes(15)) {
                        morningSlots.add(t.format(DateTimeFormatter.ofPattern("HH:mm")));
                }

                List<String> eveningSlots = new ArrayList<>();
                LocalTime eveningStart = LocalTime.of(17, 0);
                LocalTime eveningEnd = LocalTime.of(21, 0);
                for (LocalTime t = eveningStart; t.isBefore(eveningEnd); t = t.plusMinutes(15)) {
                        eveningSlots.add(t.format(DateTimeFormatter.ofPattern("HH:mm")));
                }

                return new PatientDtos.BookingSetupView(tenantPublicId, 15, normalized, availableDates, morningSlots, eveningSlots);
        }

        @Transactional(readOnly = true)
        public List<String> getBookedSlots(String tenantPublicId, String doctorPublicId, String date) {
                String schema = TenantContext.tenantSchema();
                // Slots are stored as "yyyy-MM-dd HH:mm" — filter by date prefix and extract HH:mm
                List<String> slots = jdbcTemplate.queryForList(
                        "SELECT appointment_slot FROM " + schema + ".appointment " +
                        "WHERE doctor_public_id = ? AND appointment_slot LIKE ? AND appointment_status = 'upcoming'",
                        String.class,
                        doctorPublicId,
                        date + "%"
                );
                return slots.stream()
                        .map(s -> s.length() >= 16 ? s.substring(11, 16) : s)
                        .distinct()
                        .sorted()
                        .toList();
        }

        /**
         * Booked + doctor-blocked slots and leave status for one doctor/date.
         * Blocked windows come from the slot_block table (partial-day
         * unavailability the doctor sets); leave comes from approved leave_request rows.
         */
        @Transactional(readOnly = true)
        public PatientDtos.SlotStatusView getSlotStatus(String tenantPublicId, String doctorPublicId, String date) {
                List<String> booked = getBookedSlots(tenantPublicId, doctorPublicId, date);
                List<String> blocked = blockedSlotMarks(doctorPublicId, date);
                boolean onLeave = isDoctorOnLeaveForDate(tenantPublicId, doctorPublicId, date);
                return new PatientDtos.SlotStatusView(doctorPublicId, date, booked, blocked, onLeave);
        }

        private static LocalTime parseTimeOrNull(String raw) {
                if (raw == null || raw.isBlank()) {
                        return null;
                }
                try {
                        return LocalTime.parse(raw.trim());
                } catch (DateTimeParseException e) {
                        return null;
                }
        }

        private List<String> blockedSlotMarks(String doctorPublicId, String date) {
                String schema = TenantContext.tenantSchema();
                List<String[]> windows = jdbcTemplate.query(
                                "SELECT start_time, end_time FROM " + schema + ".slot_block WHERE doctor_public_id = ? AND block_date = ?::date",
                                (rs, i) -> new String[] { rs.getString("start_time"), rs.getString("end_time") },
                                doctorPublicId, date
                );
                List<String> marks = new ArrayList<>();
                for (String[] window : windows) {
                        // A block row with a null/garbage time blocks nothing — skip it
                        // rather than fail the whole slot lookup for the day.
                        LocalTime start = parseTimeOrNull(window[0]);
                        LocalTime end = parseTimeOrNull(window[1]);
                        if (start == null || end == null) {
                                continue;
                        }
                        LocalTime cursor = start.withMinute((start.getMinute() / 15) * 15);
                        while (cursor.isBefore(end)) {
                                String mark = cursor.format(DateTimeFormatter.ofPattern("HH:mm"));
                                if (!marks.contains(mark)) {
                                        marks.add(mark);
                                }
                                cursor = cursor.plusMinutes(15);
                        }
                }
                marks.sort(String::compareTo);
                return marks;
        }

        private boolean isDoctorOnLeaveForDate(String tenantPublicId, String doctorPublicId, String date) {
                String schema = TenantContext.tenantSchema();
                Integer count = jdbcTemplate.queryForObject(
                                "SELECT COUNT(*) FROM " + schema + ".leave_request WHERE tenant_public_id = ? AND doctor_public_id = ? " +
                                "AND status IN ('APPROVED','AUTO_APPROVED') AND leave_type <> 'MESSAGE' " +
                                "AND start_time IS NULL AND requester_type = 'DOCTOR' AND from_date <= ?::date AND to_date >= ?::date",
                                Integer.class, tenantPublicId, doctorPublicId, date, date
                );
                return count != null && count > 0;
        }

        /** Rejects booking when the doctor is on leave or has blocked the requested time. */
        private void assertDoctorAvailable(String tenantPublicId, String doctorPublicId, String slot) {
                // slot format already validated: "yyyy-MM-dd HH:mm"
                String date = slot.substring(0, 10);
                String time = slot.substring(11, 16);
                if (isDoctorOnLeaveForDate(tenantPublicId, doctorPublicId, date)) {
                        throw new IllegalStateException("Doctor is on leave on " + date + ". Please pick another date or doctor.");
                }
                if (blockedSlotMarks(doctorPublicId, date).contains(time)) {
                        throw new IllegalStateException("Doctor is not available at " + time + " on " + date + ". Please pick another slot.");
                }
        }

        @Transactional
        public PatientDtos.AppointmentBookingResult bookAppointment(String tenantPublicId, String patientPublicId, PatientDtos.AppointmentBookingRequest request) {
                if (!tenantPublicId.equals(request.tenantPublicId()) || !patientPublicId.equals(request.patientPublicId())) {
                        throw new IllegalArgumentException("Tenant or patient mismatch");
                }

                String bookingType = normalizeBookingType(request.bookingType());
                String resolvedSlot;
                Integer tokenNumber = null;
                String tokenSession = null;

                if ("TOKEN".equals(bookingType)) {
                        LocalDate tokenDate = parseTokenDate(request.slot());
                        tokenSession = normalizeTokenSession(request.tokenSession());
                        resolvedSlot = tokenDate + " " + sessionStartTime(tokenSession);

                        // Leave/full-day-block still blocks token booking for that date; tokens
                        // have no time grid so there is no per-time conflict to check.
                        assertDoctorAvailable(tenantPublicId, request.doctorPublicId(), resolvedSlot);
                        tokenNumber = nextTokenNumber(tenantPublicId, request.doctorPublicId(), tokenDate, tokenSession);
                } else {
                        bookingType = "SLOT";
                        // Validate slot date/time
                        validateBookingSlot(request.slot());

                        // Enforce doctor leave & blocked windows
                        assertDoctorAvailable(tenantPublicId, request.doctorPublicId(), request.slot());

                        appointmentRepository.findByTenantPublicIdAndDoctorPublicIdAndAppointmentSlotAndAppointmentStatus(
                                        tenantPublicId,
                                        request.doctorPublicId(),
                                        request.slot(),
                                        "upcoming"
                                )
                                        .ifPresent(existing -> {
                                                throw new IllegalStateException("Selected slot is already booked");
                                        });
                        resolvedSlot = request.slot();

                        // Unified queue: a slot booking also draws a token from the SAME
                        // per-(doctor, date, session) counter that token bookings use, so slot
                        // and token appointments share ONE sequence. The appointment keeps its
                        // chosen time; the token number is what the doctor serves by. Every valid
                        // slot falls in the morning (09:00-14:00) or evening (17:00-21:00) window.
                        if (resolvedSlot == null || resolvedSlot.length() < 16) {
                                throw new IllegalArgumentException("Invalid slot. Expected yyyy-MM-ddTHH:mm");
                        }
                        LocalDate slotDate;
                        LocalTime slotTime;
                        try {
                                slotDate = LocalDate.parse(resolvedSlot.substring(0, 10));
                                slotTime = LocalTime.parse(resolvedSlot.substring(11, 16));
                        } catch (DateTimeParseException e) {
                                throw new IllegalArgumentException("Invalid slot. Expected yyyy-MM-ddTHH:mm");
                        }
                        tokenSession = sessionForTime(slotTime);
                        tokenNumber = nextTokenNumber(tenantPublicId, request.doctorPublicId(), slotDate, tokenSession);
                }

                Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                                .orElseGet(() -> {
                                        Patient fresh = new Patient();
                                        fresh.setPatientPublicId(patientPublicId);
                                        fresh.setTenantPublicId(tenantPublicId);
                                        fresh.setFullName(request.patientName());
                                        fresh.setMobileNumber(request.mobileNumber());
                                        fresh.setStatus("active");
                                        return patientRepository.save(fresh);
                                });

                patient.setFullName(request.patientName());
                patient.setMobileNumber(request.mobileNumber());
                patientRepository.save(patient);

                Appointment appointment = new Appointment();
                appointment.setAppointmentPublicId(nextAppointmentPublicId());
                appointment.setTenantPublicId(tenantPublicId);
                appointment.setPatientPublicId(patientPublicId);
                appointment.setDoctorPublicId(request.doctorPublicId());
                appointment.setAppointmentSlot(resolvedSlot);
                appointment.setAppointmentStatus("upcoming");
                appointment.setBookingType(bookingType);
                appointment.setTokenNumber(tokenNumber);
                appointment.setTokenSession(tokenSession);
                appointment.setNotes(request.note() != null && !request.note().isBlank()
                        ? request.note() : "Booked via patient app");
                if (request.vitals() != null && !request.vitals().isBlank()) {
                        appointment.setVitalsSummary(request.vitals().trim());
                }
                appointment.setBookingSource(normalizeBookingSource(request.bookingSource()));

                Appointment saved = appointmentRepository.save(appointment);

                if (request.attachments() != null) {
                        for (PatientDtos.AttachmentUploadRequest attachmentRequest : request.attachments()) {
                                if (attachmentRequest.dataBase64() == null || attachmentRequest.dataBase64().isBlank()) {
                                        continue;
                                }
                                AppointmentAttachment attachment = new AppointmentAttachment();
                                attachment.setAttachmentPublicId("ATT-" + UUID.randomUUID());
                                attachment.setTenantPublicId(tenantPublicId);
                                attachment.setAppointmentPublicId(saved.getAppointmentPublicId());
                                attachment.setFileName(attachmentRequest.fileName());
                                attachment.setMimeType(attachmentRequest.mimeType());
                                attachment.setDataBase64(attachmentRequest.dataBase64());
                                attachment.setUploadedBy("PATIENT");
                                appointmentAttachmentRepository.save(attachment);
                        }
                }

                // Every booking channel — patient app, IP-Staff, QR portal and chatbot —
                // funnels through here, so one enqueue covers all four. It joins this
                // transaction: a rolled-back booking can never leave a queued message.
                whatsAppService.enqueue(
                                tenantPublicId,
                                patient.getMobileNumber(),
                                WhatsAppService.TYPE_APPOINTMENT_CONFIRMED,
                                saved.getAppointmentPublicId(),
                                WhatsAppService.appointmentConfirmedBody(
                                                hospitalNameOf(tenantPublicId),
                                                patient.getFullName(),
                                                doctorNameOf(saved.getDoctorPublicId()),
                                                saved.getTokenNumber(),
                                                saved.getTokenSession(),
                                                saved.getAppointmentSlot()));

                log.info("patient_book_appointment tenantPublicId={} patientPublicId={} appointmentPublicId={} doctorPublicId={} slot={}",
                        tenantPublicId,
                        patientPublicId,
                        saved.getAppointmentPublicId(),
                        saved.getDoctorPublicId(),
                        saved.getAppointmentSlot());
                return new PatientDtos.AppointmentBookingResult(
                                saved.getAppointmentPublicId(),
                                tenantPublicId,
                                saved.getDoctorPublicId(),
                                saved.getPatientPublicId(),
                                saved.getAppointmentSlot(),
                                saved.getAppointmentStatus(),
                                saved.getBookingType(),
                                saved.getTokenNumber(),
                                saved.getTokenSession()
                );
        }

        /** Read-only peek at the next token number for a doctor/date/session — does not reserve it. */
        @Transactional(readOnly = true)
        public PatientDtos.TokenPreviewView tokenPreview(String tenantPublicId, String doctorPublicId, String date, String session) {
                String normalizedSession = normalizeTokenSession(session);
                LocalDate tokenDate = parseTokenDate(date);
                String schema = TenantContext.tenantSchema();
                Integer lastToken = jdbcTemplate.query(
                                "SELECT last_token FROM " + schema + ".token_counter WHERE tenant_public_id = ? AND doctor_public_id = ? AND token_date = ? AND session = ?",
                                rs -> rs.next() ? rs.getInt("last_token") : null,
                                tenantPublicId, doctorPublicId, tokenDate, normalizedSession
                );
                int next = (lastToken == null ? 0 : lastToken) + 1;
                return new PatientDtos.TokenPreviewView(doctorPublicId, tokenDate.toString(), normalizedSession, next);
        }

        /** Resets today's (or any given date's) token counter for a doctor/session back to zero. Already-issued tokens are unaffected. */
        @Transactional
        public void resetTokenCounter(String tenantPublicId, String doctorPublicId, String date, String session) {
                String normalizedSession = normalizeTokenSession(session);
                LocalDate tokenDate = parseTokenDate(date);
                String schema = TenantContext.tenantSchema();
                int updated = jdbcTemplate.update(
                                "UPDATE " + schema + ".token_counter SET last_token = 0 WHERE tenant_public_id = ? AND doctor_public_id = ? AND token_date = ? AND session = ?",
                                tenantPublicId, doctorPublicId, tokenDate, normalizedSession
                );
                if (updated == 0) {
                        jdbcTemplate.update(
                                        "INSERT INTO " + schema + ".token_counter (tenant_public_id, doctor_public_id, token_date, session, last_token) VALUES (?, ?, ?, ?, 0) " +
                                        "ON CONFLICT (tenant_public_id, doctor_public_id, token_date, session) DO NOTHING",
                                        tenantPublicId, doctorPublicId, tokenDate, normalizedSession
                        );
                }
                log.info("token_counter_reset tenantPublicId={} doctorPublicId={} date={} session={}", tenantPublicId, doctorPublicId, tokenDate, normalizedSession);
        }

        private String normalizeBookingType(String bookingType) {
                return (bookingType != null && "TOKEN".equalsIgnoreCase(bookingType.trim())) ? "TOKEN" : "SLOT";
        }

        private String normalizeBookingSource(String bookingSource) {
                if (bookingSource == null) {
                        return "PATIENT_APP";
                }
                String normalized = bookingSource.trim().toUpperCase(Locale.ROOT);
                return switch (normalized) {
                        case "QR_CODE", "IP_STAFF", "CHATBOT" -> normalized;
                        default -> "PATIENT_APP";
                };
        }

        private String normalizeTokenSession(String session) {
                if (session == null || session.isBlank()) {
                        throw new IllegalArgumentException("Token session (MORNING or EVENING) is required");
                }
                String normalized = session.trim().toUpperCase(Locale.ROOT);
                if (!normalized.equals("MORNING") && !normalized.equals("EVENING")) {
                        throw new IllegalArgumentException("Token session must be MORNING or EVENING");
                }
                return normalized;
        }

        private String sessionStartTime(String session) {
                return "MORNING".equals(session) ? "09:00" : "17:00";
        }

        /**
         * Maps a wall-clock slot time to its token session. Slot bookings are validated to
         * fall in the morning (09:00-14:00) or evening (17:00-21:00) window, so anything
         * before 14:00 is a morning token and everything else is an evening token.
         */
        private String sessionForTime(LocalTime time) {
                return time.isBefore(LocalTime.of(14, 0)) ? "MORNING" : "EVENING";
        }

        private LocalDate parseTokenDate(String rawDate) {
                if (rawDate == null || rawDate.length() < 10) {
                        throw new IllegalArgumentException("A valid date is required for token booking");
                }
                LocalDate date;
                try {
                        date = LocalDate.parse(rawDate.substring(0, 10));
                } catch (DateTimeParseException e) {
                        throw new IllegalArgumentException("Invalid date format. Expected: yyyy-MM-dd");
                }

                LocalDate today = LocalDate.now();
                if (date.isBefore(today)) {
                        throw new IllegalArgumentException("Cannot book a token for a past date");
                }
                if (date.isAfter(today.plusWeeks(2))) {
                        throw new IllegalArgumentException("Cannot book a token more than 2 weeks in advance");
                }
                return date;
        }

        private int nextTokenNumber(String tenantPublicId, String doctorPublicId, LocalDate date, String session) {
                String schema = TenantContext.tenantSchema();
                Integer next = jdbcTemplate.queryForObject(
                                "INSERT INTO " + schema + ".token_counter (tenant_public_id, doctor_public_id, token_date, session, last_token) " +
                                "VALUES (?, ?, ?, ?, 1) " +
                                "ON CONFLICT (tenant_public_id, doctor_public_id, token_date, session) " +
                                "DO UPDATE SET last_token = " + schema + ".token_counter.last_token + 1 " +
                                "RETURNING last_token",
                                Integer.class,
                                tenantPublicId, doctorPublicId, date, session
                );
                if (next == null) {
                        throw new IllegalStateException("Could not generate token number");
                }
                return next;
        }

    @Transactional(readOnly = true)
    public Patient findFirstPatientForTenant(String tenantPublicId) {
        return patientRepository.findFirstByTenantPublicIdOrderByPatientPublicIdAsc(tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("No patient exists for tenant"));
    }

        @Transactional
        public Patient findOrCreatePatientForLogin(String tenantPublicId, String mobileNumber) {
                String normalizedMobileNumber = mobileNumber == null ? "" : mobileNumber.trim();
                if (normalizedMobileNumber.isBlank()) {
                        throw new IllegalArgumentException("Mobile number is required");
                }

                Optional<Patient> existingPatient = patientRepository.findByTenantPublicIdAndMobileNumber(tenantPublicId, normalizedMobileNumber);
                if (existingPatient.isPresent()) {
                        Patient patient = existingPatient.get();
                        if ("disabled".equalsIgnoreCase(patient.getStatus())) {
                                throw new IllegalStateException("This account has been deleted and is no longer active.");
                        }
                        return patient;
                }

                Patient patient = new Patient();
                patient.setPatientPublicId(nextPatientPublicId());
                patient.setTenantPublicId(tenantPublicId);
                patient.setMobileNumber(normalizedMobileNumber);
                patient.setStatus("active");
                patient.setFullName("Patient " + normalizedMobileNumber.substring(Math.max(0, normalizedMobileNumber.length() - 4)));
                return patientRepository.save(patient);
        }

        /**
         * Confirms a QR-code appointment request by creating a real patient (find-or-create
         * by mobile) + appointment, going through the exact same {@link #bookAppointment} path
         * used by the patient app and IP-Staff — so slot-conflict checks, doctor-leave checks
         * and token numbering are all reused, and the resulting appointment shows up in the
         * doctor's queue/consult flow and the IP-Staff patient list like any other booking.
         */
        @Transactional
        public PatientDtos.AppointmentBookingResult confirmQrAppointmentRequest(
                        String tenantPublicId,
                        String doctorPublicId,
                        String patientMobile,
                        String patientName,
                        int patientAge,
                        String specialty,
                        LocalDate preferredDate,
                        HospitalManagementDtos.AppointmentRequestConfirmRequest confirmReq,
                        String bookingSource
        ) {
                Patient patient = findOrCreatePatientForLogin(tenantPublicId, patientMobile);
                if (patientName != null && !patientName.isBlank()) {
                        patient.setFullName(patientName);
                }
                if (patientAge > 0) {
                        patient.setAge(patientAge);
                }
                patient = patientRepository.save(patient);

                String bookingType = normalizeBookingType(confirmReq.bookingType());
                String slot;
                if ("TOKEN".equals(bookingType)) {
                        if (confirmReq.tokenSession() == null || confirmReq.tokenSession().isBlank()) {
                                throw new IllegalArgumentException("Token session (MORNING or EVENING) is required");
                        }
                        slot = preferredDate.toString();
                } else {
                        if (confirmReq.slot() == null || confirmReq.slot().isBlank()) {
                                throw new IllegalArgumentException("A slot time is required");
                        }
                        slot = confirmReq.slot();
                }

                String note = confirmReq.notes() != null && !confirmReq.notes().isBlank()
                                ? confirmReq.notes()
                                : ("CHATBOT".equals(bookingSource)
                                                ? "Booked via SevaCare Assistant"
                                                : "Booked via QR code");

                PatientDtos.AppointmentBookingRequest bookingRequest = new PatientDtos.AppointmentBookingRequest(
                                tenantPublicId,
                                patient.getPatientPublicId(),
                                patient.getFullName(),
                                "Not specified",
                                patient.getAge() == null ? patientAge : patient.getAge(),
                                patient.getMobileNumber(),
                                null,
                                specialty,
                                doctorPublicId,
                                slot,
                                bookingType,
                                confirmReq.tokenSession(),
                                note,
                                null,
                                null,
                                bookingSource == null || bookingSource.isBlank() ? "QR_CODE" : bookingSource
                );

                return bookAppointment(tenantPublicId, patient.getPatientPublicId(), bookingRequest);
        }

    @Transactional
    public Patient save(Patient patient) {
        return patientRepository.save(patient);
    }

    @Transactional(readOnly = true)
    public PatientDtos.PatientCollection listPatientRecords(String tenantPublicId) {
        List<PatientDtos.PatientView> records = patientRepository.findTop2000ByTenantPublicIdOrderByPatientPublicIdAsc(tenantPublicId)
                .stream()
                .map(patient -> new PatientDtos.PatientView(
                        patient.getPatientPublicId(),
                        patient.getTenantPublicId(),
                        patient.getFullName(),
                        patient.getMobileNumber(),
                        patient.getStatus(),
                        patient.getEmail(),
                        patient.getGender(),
                        patient.getAge(),
                        patient.getAddress()
                ))
                .toList();
        return new PatientDtos.PatientCollection(tenantPublicId, records);
    }

    @Transactional(readOnly = true)
    public PatientDtos.PatientView getPatientRecord(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        return new PatientDtos.PatientView(
                patient.getPatientPublicId(),
                patient.getTenantPublicId(),
                patient.getFullName(),
                patient.getMobileNumber(),
                patient.getStatus(),
                patient.getEmail(),
                patient.getGender(),
                patient.getAge(),
                patient.getAddress()
        );
    }

    @Transactional
    public PatientDtos.PatientView upsertPatientRecord(String tenantPublicId, String patientPublicId, PatientDtos.PatientUpsertRequest request) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseGet(() -> {
                    Patient fresh = new Patient();
                    fresh.setPatientPublicId(patientPublicId);
                    fresh.setTenantPublicId(tenantPublicId);
                    return fresh;
                });

        patient.setFullName(request.fullName());
        patient.setMobileNumber(request.mobileNumber());
        patient.setStatus(request.status());
        patient.setEmail(request.email());
        patient.setGender(request.gender());
        patient.setAge(request.age());
        patient.setAddress(request.address());

        Patient saved = patientRepository.save(patient);
        log.info("patient_upsert tenantPublicId={} patientPublicId={} status={}",
                tenantPublicId,
                saved.getPatientPublicId(),
                saved.getStatus());
        return new PatientDtos.PatientView(
                saved.getPatientPublicId(),
                saved.getTenantPublicId(),
                saved.getFullName(),
                saved.getMobileNumber(),
                saved.getStatus(),
                saved.getEmail(),
                saved.getGender(),
                saved.getAge(),
                saved.getAddress()
        );
    }

    @Transactional
    public void deletePatientRecord(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        patientRepository.delete(patient);
        log.info("patient_delete tenantPublicId={} patientPublicId={}", tenantPublicId, patientPublicId);
    }

    /**
     * Self-service "delete my account". Only disables login — appointments,
     * prescriptions and every other record tied to this patientPublicId are
     * left untouched, and the mobile number stays attached so history is
     * still recognizable if the same person registers again later.
     */
    @Transactional
    public void requestAccountDeletion(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        patient.setStatus("disabled");
        patient.setDeletionRequestedAt(LocalDateTime.now());
        patientRepository.save(patient);
        log.info("patient_account_deletion_requested tenantPublicId={} patientPublicId={}", tenantPublicId, patientPublicId);
    }

    @Transactional(readOnly = true)
    public PatientDtos.PhotoView getPatientPhoto(String tenantPublicId, String patientPublicId) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        return new PatientDtos.PhotoView(patient.getPhotoBase64());
    }

    @Transactional
    public void updatePatientPhoto(String tenantPublicId, String patientPublicId, String photoBase64) {
        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));
        patient.setPhotoBase64(photoBase64);
        patientRepository.save(patient);
    }

    @Transactional(readOnly = true)
    public PatientDtos.AppointmentCollection listAppointmentRecords(String tenantPublicId) {
        List<PatientDtos.AppointmentEntityView> records = appointmentRepository.findByTenantPublicIdOrderByAppointmentSlotDesc(tenantPublicId)
                .stream()
                .map(appointment -> new PatientDtos.AppointmentEntityView(
                        appointment.getAppointmentPublicId(),
                        appointment.getPatientPublicId(),
                        appointment.getDoctorPublicId(),
                        appointment.getAppointmentSlot(),
                        appointment.getAppointmentStatus(),
                        appointment.getNotes(),
                        appointment.getBookingType(),
                        appointment.getTokenNumber(),
                        appointment.getTokenSession()
                ))
                .toList();
        return new PatientDtos.AppointmentCollection(tenantPublicId, records);
    }

    @Transactional(readOnly = true)
    public PatientDtos.AppointmentEntityView getAppointmentRecord(String tenantPublicId, String appointmentPublicId) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));
        return new PatientDtos.AppointmentEntityView(
                appointment.getAppointmentPublicId(),
                appointment.getPatientPublicId(),
                appointment.getDoctorPublicId(),
                appointment.getAppointmentSlot(),
                appointment.getAppointmentStatus(),
                appointment.getNotes(),
                appointment.getBookingType(),
                appointment.getTokenNumber(),
                appointment.getTokenSession()
        );
    }

    @Transactional
    public PatientDtos.AppointmentEntityView upsertAppointmentRecord(String tenantPublicId, String appointmentPublicId, PatientDtos.AppointmentUpsertRequest request) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseGet(() -> {
                    Appointment fresh = new Appointment();
                    fresh.setAppointmentPublicId(appointmentPublicId);
                    fresh.setTenantPublicId(tenantPublicId);
                    return fresh;
                });

        appointment.setPatientPublicId(request.patientPublicId());
        appointment.setDoctorPublicId(request.doctorPublicId());
        appointment.setAppointmentSlot(request.slot());
        appointment.setAppointmentStatus(request.status());
        appointment.setNotes(request.note());

        Appointment saved = appointmentRepository.save(appointment);
        log.info("appointment_upsert tenantPublicId={} appointmentPublicId={} status={}",
                tenantPublicId,
                saved.getAppointmentPublicId(),
                saved.getAppointmentStatus());
        return new PatientDtos.AppointmentEntityView(
                saved.getAppointmentPublicId(),
                saved.getPatientPublicId(),
                saved.getDoctorPublicId(),
                saved.getAppointmentSlot(),
                saved.getAppointmentStatus(),
                saved.getNotes(),
                saved.getBookingType(),
                saved.getTokenNumber(),
                saved.getTokenSession()
        );
    }

    @Transactional
    public void deleteAppointmentRecord(String tenantPublicId, String appointmentPublicId) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));
        appointmentRepository.delete(appointment);
        log.info("appointment_delete tenantPublicId={} appointmentPublicId={}", tenantPublicId, appointmentPublicId);
    }

    @Transactional
    public void completeAppointment(String tenantPublicId, String doctorPublicId, String appointmentPublicId) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found"));
        if (!appointment.getDoctorPublicId().equals(doctorPublicId)) {
            throw new IllegalArgumentException("You are not the assigned doctor for this appointment");
        }
        appointment.setAppointmentStatus("completed");
        appointmentRepository.save(appointment);
        log.info("appointment_complete tenantPublicId={} doctorPublicId={} appointmentPublicId={}", tenantPublicId, doctorPublicId, appointmentPublicId);
    }

    /** One review per completed appointment — enforced by the doctor_review.appointment_public_id unique constraint. */
    @Transactional
    public PatientDtos.ReviewSubmitResult submitReview(String tenantPublicId, String patientPublicId, String appointmentPublicId, PatientDtos.ReviewSubmitRequest request) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));
        if (!appointment.getPatientPublicId().equals(patientPublicId)) {
            throw new IllegalArgumentException("Patient mismatch for appointment");
        }
        if (!"completed".equalsIgnoreCase(appointment.getAppointmentStatus())) {
            throw new IllegalStateException("Only completed appointments can be reviewed");
        }
        if (doctorReviewRepository.findByAppointmentPublicId(appointmentPublicId).isPresent()) {
            throw new IllegalStateException("This appointment has already been reviewed");
        }

        DoctorReview review = new DoctorReview();
        review.setAppointmentPublicId(appointmentPublicId);
        review.setDoctorPublicId(appointment.getDoctorPublicId());
        review.setPatientPublicId(patientPublicId);
        review.setRating(request.rating());
        review.setComment(request.comment());
        DoctorReview saved = doctorReviewRepository.save(review);

        log.info("doctor_review_submit tenantPublicId={} appointmentPublicId={} doctorPublicId={} rating={}",
                tenantPublicId, appointmentPublicId, saved.getDoctorPublicId(), saved.getRating());

        return new PatientDtos.ReviewSubmitResult(appointmentPublicId, saved.getDoctorPublicId(), saved.getRating(), saved.getComment());
    }

    /** Live queue position for a patient's own TOKEN appointment, driving the "your turn is near" banner. */
    @Transactional(readOnly = true)
    public PatientDtos.QueueStatusView getQueueStatus(String tenantPublicId, String patientPublicId, String appointmentPublicId) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));
        if (!appointment.getPatientPublicId().equals(patientPublicId)) {
            throw new IllegalArgumentException("Patient mismatch for appointment");
        }
        // Unified queue: both slot and token appointments carry a token, so either can
        // report a live queue position. Only appointments without a token (legacy rows) are rejected.
        if (appointment.getTokenNumber() == null || appointment.getTokenSession() == null) {
            throw new IllegalArgumentException("Appointment has no token in the queue");
        }

        LocalDate date = parseSlotDate(appointment.getAppointmentSlot())
                .orElseThrow(() -> new IllegalArgumentException("Could not determine appointment date"));

        PatientDtos.DoctorQueueDayView dayView = getDoctorQueueForDate(tenantPublicId, appointment.getDoctorPublicId(), date);

        List<PatientDtos.DoctorQueueFacetView> waiting = dayView.facets().stream()
                .filter(f -> f.tokenNumber() != null && appointment.getTokenSession().equals(f.tokenSession()))
                .filter(f -> !"cancelled".equalsIgnoreCase(f.status()) && !"completed".equalsIgnoreCase(f.status()))
                .sorted(Comparator.comparing(f -> f.tokenNumber() == null ? 0 : f.tokenNumber()))
                .toList();

        int patientIndex = -1;
        for (int i = 0; i < waiting.size(); i++) {
            if (waiting.get(i).appointmentPublicId().equals(appointmentPublicId)) {
                patientIndex = i;
                break;
            }
        }

        boolean alreadyServed = "completed".equalsIgnoreCase(appointment.getAppointmentStatus());
        Integer nowServingToken = waiting.isEmpty() ? null : waiting.get(0).tokenNumber();
        int tokensAhead = patientIndex < 0 ? 0 : patientIndex;
        int estimatedWaitMinutes = tokensAhead * 10;

        return new PatientDtos.QueueStatusView(
                appointment.getDoctorPublicId(),
                date.toString(),
                appointment.getTokenSession(),
                appointment.getTokenNumber(),
                nowServingToken,
                tokensAhead,
                estimatedWaitMinutes,
                alreadyServed
        );
    }

    // Prescription Methods
    @Transactional(readOnly = true)
    public PatientDtos.PatientPrescriptionsWrapper getPatientPrescriptions(String tenantPublicId, String patientPublicId) {
        List<Prescription> prescriptionRows = prescriptionRepository.findByTenantPublicIdAndPatientPublicIdOrderByPrescriptionPublicIdAsc(tenantPublicId, patientPublicId);
        Map<String, List<PrescriptionMedicine>> medicinesByPrescription = medicinesGroupedByPrescriptionId(prescriptionRows);

        List<PatientDtos.PrescriptionDetailView> prescriptions = prescriptionRows
                .stream()
                .map(prescription -> {
                    List<PatientDtos.MedicineView> medicines = medicinesByPrescription
                            .getOrDefault(prescription.getPrescriptionPublicId(), List.of())
                            .stream()
                            .map(medicine -> new PatientDtos.MedicineView(
                                    medicine.getMedicineName(),
                                    medicine.getStrength(),
                                    medicine.getFrequency(),
                                    medicine.getDuration(),
                                    medicine.getInstructions()
                            ))
                            .toList();
                    return new PatientDtos.PrescriptionDetailView(
                            prescription.getPrescriptionPublicId(),
                            prescription.getDoctorPublicId(),
                            prescription.getDoctorName(),
                            null, null, null,
                            prescription.getIssuedOn(),
                            prescription.getValidUntil() != null ? prescription.getValidUntil().toString() : null,
                            prescription.getNotes(),
                            prescription.getStatus() != null ? prescription.getStatus() : "active",
                            medicines
                    );
                })
                .toList();
        return new PatientDtos.PatientPrescriptionsWrapper(tenantPublicId, patientPublicId, prescriptions);
    }

    /** Batch-fetches medicines for a list of prescriptions in one query instead of one query per prescription. */
    private Map<String, List<PrescriptionMedicine>> medicinesGroupedByPrescriptionId(List<Prescription> prescriptionRows) {
        List<String> prescriptionIds = prescriptionRows.stream().map(Prescription::getPrescriptionPublicId).toList();
        if (prescriptionIds.isEmpty()) {
            return Map.of();
        }
        return prescriptionMedicineRepository.findByPrescriptionPublicIdIn(prescriptionIds)
                .stream()
                .collect(Collectors.groupingBy(PrescriptionMedicine::getPrescriptionPublicId));
    }

    @Transactional(readOnly = true)
    public PatientDtos.PrescriptionDetailView getPrescriptionDetail(String tenantPublicId, String prescriptionPublicId) {
        Prescription prescription = prescriptionRepository.findByTenantPublicIdAndPrescriptionPublicId(tenantPublicId, prescriptionPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Prescription not found for tenant"));

        List<PatientDtos.MedicineView> medicines = prescriptionMedicineRepository.findByPrescriptionPublicId(prescriptionPublicId)
                .stream()
                .map(medicine -> new PatientDtos.MedicineView(
                        medicine.getMedicineName(),
                        medicine.getStrength(),
                        medicine.getFrequency(),
                        medicine.getDuration(),
                        medicine.getInstructions()
                ))
                .toList();

        String schema = TenantContext.tenantSchema();
        String doctorSpecialty = jdbcTemplate.query(
                "SELECT specialty FROM " + schema + ".doctor WHERE doctor_public_id = ? LIMIT 1",
                rs -> rs.next() ? rs.getString("specialty") : null,
                prescription.getDoctorPublicId()
        );
        String patientName = jdbcTemplate.query(
                "SELECT full_name FROM " + schema + ".patient WHERE patient_public_id = ? LIMIT 1",
                rs -> rs.next() ? rs.getString("full_name") : null,
                prescription.getPatientPublicId()
        );

        return new PatientDtos.PrescriptionDetailView(
                prescription.getPrescriptionPublicId(),
                prescription.getDoctorPublicId(),
                prescription.getDoctorName(),
                doctorSpecialty,
                prescription.getPatientPublicId(),
                patientName,
                prescription.getIssuedOn(),
                prescription.getValidUntil() != null ? prescription.getValidUntil().toString() : null,
                prescription.getNotes(),
                prescription.getStatus() != null ? prescription.getStatus() : "active",
                medicines
        );
    }

    @Transactional
    public PatientDtos.PrescriptionUploadResult uploadPrescription(String tenantPublicId, String patientPublicId, PatientDtos.PrescriptionUploadRequest request) {
        boolean hasMedicines = request.medicines() != null && !request.medicines().isEmpty();
        boolean hasNotes = request.notes() != null && !request.notes().isBlank();
        if (!hasMedicines && !hasNotes) {
            throw new IllegalArgumentException("Add at least one medicine or a clinical note before completing.");
        }

        Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Patient not found for tenant"));

        Prescription prescription = new Prescription();
        prescription.setPrescriptionPublicId(nextPrescriptionPublicId());
        prescription.setTenantPublicId(tenantPublicId);
        prescription.setPatientPublicId(patientPublicId);
        prescription.setDoctorPublicId(request.doctorPublicId());
        prescription.setDoctorName(request.doctorName());
        prescription.setIssuedOn(LocalDate.now().toString());
        prescription.setValidUntil(LocalDate.now().plusMonths(1));
        prescription.setNotes(request.notes() != null ? request.notes() : "");
        prescription.setStatus("active");
        prescription.setCreatedAt(LocalDateTime.now());
        prescription.setUpdatedAt(LocalDateTime.now());

        Prescription saved = prescriptionRepository.save(prescription);

        // Save medicines
        if (request.medicines() != null && !request.medicines().isEmpty()) {
            for (PatientDtos.MedicineUploadRequest medicine : request.medicines()) {
                PrescriptionMedicine prescMedicine = new PrescriptionMedicine();
                prescMedicine.setPrescriptionPublicId(saved.getPrescriptionPublicId());
                prescMedicine.setMedicineName(medicine.medicineName());
                prescMedicine.setStrength(medicine.strength());
                prescMedicine.setFrequency(medicine.frequency());
                prescMedicine.setDuration(medicine.duration());
                prescMedicine.setInstructions(medicine.instructions());
                prescMedicine.setCreatedAt(LocalDateTime.now());
                prescriptionMedicineRepository.save(prescMedicine);
            }
        }

        LocalDate followUpDate = null;
        if (request.followUpDays() != null && request.followUpDays() > 0) {
            followUpDate = LocalDate.now().plusDays(request.followUpDays());
            MedicalHistory followUp = new MedicalHistory();
            followUp.setTenantPublicId(tenantPublicId);
            followUp.setPatientPublicId(patientPublicId);
            followUp.setRecordType("follow_up");
            followUp.setRecordValue(request.followUpDays() + " days");
            followUp.setNotes("Follow-up suggested by Dr. " + request.doctorName() + " after prescription " + saved.getPrescriptionPublicId());
            followUp.setRecordDate(followUpDate);
            medicalHistoryRepository.save(followUp);
        }

        // The doctor's checkbox is opt-out, so a missing flag means "send".
        boolean sendWhatsapp = request.sendWhatsapp() == null || request.sendWhatsapp();
        if (sendWhatsapp) {
            String hospitalName = hospitalNameOf(tenantPublicId);
            List<String> medicineLines = request.medicines() == null ? List.of()
                    : request.medicines().stream().map(PatientDomainService::medicineLine).toList();

            whatsAppService.enqueue(
                    tenantPublicId,
                    patient.getMobileNumber(),
                    WhatsAppService.TYPE_PRESCRIPTION,
                    saved.getPrescriptionPublicId(),
                    WhatsAppService.prescriptionBody(hospitalName, patient.getFullName(), request.doctorName(),
                            saved.getPrescriptionPublicId(), medicineLines, prescription.getNotes(), request.followUpDays()));

            // Queued now, delivered on the morning of the follow-up date — the outbox
            // drainer only picks up rows whose scheduled_at has arrived.
            if (followUpDate != null) {
                whatsAppService.enqueueAt(
                        tenantPublicId,
                        patient.getMobileNumber(),
                        WhatsAppService.TYPE_FOLLOW_UP,
                        saved.getPrescriptionPublicId(),
                        WhatsAppService.followUpBody(hospitalName, patient.getFullName(), request.doctorName(),
                                followUpDate.toString()),
                        WhatsAppService.reminderTimeFor(followUpDate));
            }
        }

        log.info("prescription_upload tenantPublicId={} patientPublicId={} prescriptionPublicId={} doctorPublicId={} medicineCount={} followUpDays={} whatsapp={}",
                tenantPublicId,
                patientPublicId,
                saved.getPrescriptionPublicId(),
                saved.getDoctorPublicId(),
                request.medicines() != null ? request.medicines().size() : 0,
                request.followUpDays(),
                sendWhatsapp);

        return new PatientDtos.PrescriptionUploadResult(
                saved.getPrescriptionPublicId(),
                saved.getPatientPublicId(),
                saved.getDoctorPublicId(),
                saved.getIssuedOn(),
                request.medicines() != null ? request.medicines().size() : 0,
                saved.getStatus(),
                sendWhatsapp
        );
    }

    /** "Paracetamol 500mg — TDS · 5 days (After food)" */
    private static String medicineLine(PatientDtos.MedicineUploadRequest m) {
        StringBuilder sb = new StringBuilder(m.medicineName());
        if (m.strength() != null && !m.strength().isBlank()) {
            sb.append(' ').append(m.strength().trim());
        }
        String schedule = java.util.stream.Stream.of(m.frequency(), m.duration())
                .filter(s -> s != null && !s.isBlank())
                .map(String::trim)
                .collect(java.util.stream.Collectors.joining(" · "));
        if (!schedule.isEmpty()) {
            sb.append(" — ").append(schedule);
        }
        if (m.instructions() != null && !m.instructions().isBlank()) {
            sb.append(" (").append(m.instructions().trim()).append(')');
        }
        return sb.toString();
    }

    @Transactional(readOnly = true)
    public String downloadPrescription(String tenantPublicId, String prescriptionPublicId) {
        Prescription prescription = prescriptionRepository.findByTenantPublicIdAndPrescriptionPublicId(tenantPublicId, prescriptionPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Prescription not found for tenant"));
        
        // For now, return null or a placeholder URL
        // In real implementation, would generate PDF and return S3 URL
                return "https://example.com/prescriptions/" + prescription.getPrescriptionPublicId() + ".pdf";
    }

    @Transactional(readOnly = true)
    public PatientDtos.MedicalHistoryView getPatientMedicalHistory(String tenantPublicId, String patientPublicId) {
        // Get all medical history records
        List<MedicalHistory> allRecords = medicalHistoryRepository.findByTenantPublicIdAndPatientPublicId(tenantPublicId, patientPublicId);

        // Get appointments
        List<Appointment> appointments = appointmentRepository.findByTenantPublicIdAndPatientPublicIdOrderByAppointmentSlotDesc(tenantPublicId, patientPublicId);

        // Get prescriptions
        List<Prescription> prescriptions = prescriptionRepository.findByTenantPublicIdAndPatientPublicIdOrderByPrescriptionPublicIdAsc(tenantPublicId, patientPublicId);

        // Convert all records to views
        List<PatientDtos.MedicalHistoryRecordView> allergies = allRecords.stream()
                .filter(r -> "allergy".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.MedicalHistoryRecordView> conditions = allRecords.stream()
                .filter(r -> "condition".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.MedicalHistoryRecordView> records = allRecords.stream()
                .filter(r -> "record".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.MedicalHistoryRecordView> followUps = allRecords.stream()
                .filter(r -> "follow_up".equals(r.getRecordType()))
                .map(r -> new PatientDtos.MedicalHistoryRecordView(r.getRecordType(), r.getRecordValue(), r.getNotes(), r.getRecordDate() != null ? r.getRecordDate().toString() : null))
                .toList();

        List<PatientDtos.AppointmentEntityView> appointmentViews = appointments.stream()
                .map(a -> new PatientDtos.AppointmentEntityView(a.getAppointmentPublicId(), a.getPatientPublicId(), a.getDoctorPublicId(), a.getAppointmentSlot(), a.getAppointmentStatus(), a.getNotes(),
                        a.getBookingType(), a.getTokenNumber(), a.getTokenSession()))
                .toList();

        List<PatientDtos.PrescriptionDetailView> prescriptionViews = prescriptions.stream()
                .map(p -> {
                    List<PatientDtos.MedicineView> medicines = prescriptionMedicineRepository.findByPrescriptionPublicId(p.getPrescriptionPublicId())
                            .stream()
                            .map(m -> new PatientDtos.MedicineView(m.getMedicineName(), m.getStrength(), m.getFrequency(), m.getDuration(), m.getInstructions()))
                            .toList();
                    return new PatientDtos.PrescriptionDetailView(p.getPrescriptionPublicId(), p.getDoctorPublicId(), p.getDoctorName(), null, p.getPatientPublicId(), null, p.getIssuedOn(), p.getValidUntil() != null ? p.getValidUntil().toString() : null, p.getNotes(), p.getStatus() != null ? p.getStatus() : "active", medicines);
                })
                .toList();

        return new PatientDtos.MedicalHistoryView(
                patientPublicId,
                allergies,
                conditions,
                records,
                followUps,
                appointmentViews,
                prescriptionViews
        );
    }

        private String nextAppointmentPublicId() {
                int value = ThreadLocalRandom.current().nextInt(1000, 9999);
                return "APT-" + value;
        }

        private String nextPrescriptionPublicId() {
                int value = ThreadLocalRandom.current().nextInt(1000, 9999);
                return "RX-" + value;
        }

        private static final DateTimeFormatter SLOT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

        private void validateBookingSlot(String slot) {
                LocalDateTime slotDateTime;
                try {
                        slotDateTime = LocalDateTime.parse(slot, SLOT_FORMATTER);
                } catch (DateTimeParseException e) {
                        throw new IllegalArgumentException("Invalid slot format. Expected: yyyy-MM-dd HH:mm");
                }

                LocalDateTime now = LocalDateTime.now();
                LocalDate today = now.toLocalDate();
                LocalDate slotDate = slotDateTime.toLocalDate();
                LocalTime slotTime = slotDateTime.toLocalTime();

                // No past dates
                if (slotDate.isBefore(today)) {
                        throw new IllegalArgumentException("Cannot book appointments for past dates");
                }

                // Max 2 weeks in advance
                if (slotDate.isAfter(today.plusWeeks(2))) {
                        throw new IllegalArgumentException("Cannot book appointments more than 2 weeks in advance");
                }

                // For today, no past time slots
                if (slotDate.equals(today) && slotDateTime.isBefore(now)) {
                        throw new IllegalArgumentException("Cannot book a time slot that has already passed");
                }

                // Valid time ranges: 09:00-14:00 or 17:00-21:00
                boolean inMorning = !slotTime.isBefore(LocalTime.of(9, 0)) && slotTime.isBefore(LocalTime.of(14, 0));
                boolean inEvening = !slotTime.isBefore(LocalTime.of(17, 0)) && slotTime.isBefore(LocalTime.of(21, 0));
                if (!inMorning && !inEvening) {
                        throw new IllegalArgumentException("Appointment slot must be within 09:00-14:00 or 17:00-21:00");
                }

                // Slot must be on 15-minute boundary
                if (slotTime.getMinute() % 15 != 0) {
                        throw new IllegalArgumentException("Appointment slot must be on a 15-minute interval");
                }
        }

    // Doctor-scoped patient list (derived from appointments)
    @Transactional(readOnly = true)
    public PatientDtos.DoctorPatientCollection getDoctorPatients(String tenantPublicId, String doctorPublicId) {
        List<Appointment> appointments = appointmentRepository.findByTenantPublicIdAndDoctorPublicIdOrderByAppointmentSlotDesc(tenantPublicId, doctorPublicId);

        // Build unique patient list with last appointment info
        java.util.Map<String, Appointment> latestByPatient = new java.util.LinkedHashMap<>();
        for (Appointment a : appointments) {
            latestByPatient.put(a.getPatientPublicId(), a);
        }

        List<PatientDtos.DoctorPatientView> patients = latestByPatient.entrySet().stream()
                .map(entry -> {
                    String patientId = entry.getKey();
                    Appointment lastAppt = entry.getValue();
                    Patient patient = patientRepository.findByPatientPublicIdAndTenantPublicId(patientId, tenantPublicId).orElse(null);
                    return new PatientDtos.DoctorPatientView(
                            patientId,
                            patient != null ? patient.getFullName() : patientId,
                            patient != null ? patient.getMobileNumber() : "",
                            patient != null ? patient.getStatus() : "unknown",
                            lastAppt.getAppointmentSlot()
                    );
                })
                .toList();

        return new PatientDtos.DoctorPatientCollection(tenantPublicId, doctorPublicId, patients);
    }

    // Doctor-scoped prescription list
    @Transactional(readOnly = true)
    public PatientDtos.DoctorPrescriptionCollection getDoctorPrescriptions(String tenantPublicId, String doctorPublicId) {
        List<Prescription> prescriptionRows = prescriptionRepository.findByTenantPublicIdAndDoctorPublicId(tenantPublicId, doctorPublicId);
        Map<String, List<PrescriptionMedicine>> medicinesByPrescription = medicinesGroupedByPrescriptionId(prescriptionRows);

        List<PatientDtos.PrescriptionDetailView> prescriptions = prescriptionRows
                .stream()
                .map(prescription -> {
                    List<PatientDtos.MedicineView> medicines = medicinesByPrescription
                            .getOrDefault(prescription.getPrescriptionPublicId(), List.of())
                            .stream()
                            .map(medicine -> new PatientDtos.MedicineView(
                                    medicine.getMedicineName(),
                                    medicine.getStrength(),
                                    medicine.getFrequency(),
                                    medicine.getDuration(),
                                    medicine.getInstructions()
                            ))
                            .toList();
                    return new PatientDtos.PrescriptionDetailView(
                            prescription.getPrescriptionPublicId(),
                            prescription.getDoctorPublicId(),
                            prescription.getDoctorName(),
                            null,
                            prescription.getPatientPublicId(),
                            null,
                            prescription.getIssuedOn(),
                            prescription.getValidUntil() != null ? prescription.getValidUntil().toString() : null,
                            prescription.getNotes(),
                            prescription.getStatus() != null ? prescription.getStatus() : "active",
                            medicines
                    );
                })
                .toList();
        return new PatientDtos.DoctorPrescriptionCollection(tenantPublicId, doctorPublicId, prescriptions);
    }

    // Cancel appointment (soft delete via status change)
    @Transactional
        public PatientDtos.AppointmentActionResult cancelAppointment(String tenantPublicId, String patientPublicId, String appointmentPublicId, PatientDtos.AppointmentCancelRequest request) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));

                if (!appointment.getPatientPublicId().equals(patientPublicId)) {
                        throw new IllegalArgumentException("Patient mismatch for appointment");
                }

        appointment.setAppointmentStatus("cancelled");
        appointment.setNotes(request != null && request.reason() != null ? request.reason() : "Cancelled by user");
        appointmentRepository.save(appointment);
        log.info("appointment_cancel tenantPublicId={} appointmentPublicId={} reason={}",
                tenantPublicId,
                appointmentPublicId,
                request != null ? request.reason() : "Cancelled by user");

        return new PatientDtos.AppointmentActionResult(appointmentPublicId, "cancelled", "Appointment cancelled successfully");
    }

    // Reschedule appointment
    @Transactional
        public PatientDtos.AppointmentActionResult rescheduleAppointment(String tenantPublicId, String patientPublicId, String appointmentPublicId, PatientDtos.AppointmentRescheduleRequest request) {
        Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));

                if (!appointment.getPatientPublicId().equals(patientPublicId)) {
                        throw new IllegalArgumentException("Patient mismatch for appointment");
                }

        // Check new slot availability
        appointmentRepository.findByTenantPublicIdAndDoctorPublicIdAndAppointmentSlotAndAppointmentStatus(
                tenantPublicId, appointment.getDoctorPublicId(), request.newSlot(), "upcoming")
                .ifPresent(existing -> {
                    throw new IllegalStateException("New slot is already booked");
                });
        assertDoctorAvailable(tenantPublicId, appointment.getDoctorPublicId(), request.newSlot());

        appointment.setAppointmentSlot(request.newSlot());
        appointment.setNotes("Rescheduled");
        appointmentRepository.save(appointment);
        log.info("appointment_reschedule tenantPublicId={} appointmentPublicId={} newSlot={}",
                tenantPublicId,
                appointmentPublicId,
                request.newSlot());

        return new PatientDtos.AppointmentActionResult(appointmentPublicId, "rescheduled", "Appointment rescheduled to " + request.newSlot());
    }

        // Delete appointment for patient after marking it cancelled (audit-friendly flow)
        @Transactional
        public PatientDtos.AppointmentActionResult deleteAppointmentForPatient(String tenantPublicId, String patientPublicId, String appointmentPublicId) {
                Appointment appointment = appointmentRepository.findByTenantPublicIdAndAppointmentPublicId(tenantPublicId, appointmentPublicId)
                                .orElseThrow(() -> new IllegalArgumentException("Appointment not found for tenant"));

                if (!appointment.getPatientPublicId().equals(patientPublicId)) {
                        throw new IllegalArgumentException("Patient mismatch for appointment");
                }

                appointment.setAppointmentStatus("cancelled");
                appointment.setNotes("Cancelled and deleted by patient");
                appointmentRepository.save(appointment);
                appointmentRepository.delete(appointment);

                log.info("appointment_delete_by_patient tenantPublicId={} patientPublicId={} appointmentPublicId={}",
                                tenantPublicId,
                                patientPublicId,
                                appointmentPublicId);

                return new PatientDtos.AppointmentActionResult(appointmentPublicId, "deleted", "Appointment deleted successfully");
        }

    // Doctor patient queue (upcoming appointments)
    @Transactional(readOnly = true)
    public List<PatientDtos.AppointmentEntityView> getDoctorPatientQueue(String tenantPublicId, String doctorPublicId) {
        return appointmentRepository.findByTenantPublicIdAndDoctorPublicIdOrderByAppointmentSlotDesc(tenantPublicId, doctorPublicId)
                .stream()
                .filter(a -> "upcoming".equals(a.getAppointmentStatus()))
                .map(a -> new PatientDtos.AppointmentEntityView(
                        a.getAppointmentPublicId(),
                        a.getPatientPublicId(),
                        a.getDoctorPublicId(),
                        a.getAppointmentSlot(),
                        a.getAppointmentStatus(),
                        a.getNotes(),
                        a.getBookingType(),
                        a.getTokenNumber(),
                        a.getTokenSession()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public PatientDtos.DoctorQueueDayView getDoctorQueueForDate(String tenantPublicId, String doctorPublicId, LocalDate date) {
        List<Appointment> doctorAppointments = appointmentRepository.findByTenantPublicIdAndDoctorPublicIdOrderByAppointmentSlotDesc(tenantPublicId, doctorPublicId);

        List<Appointment> dayAppointments = doctorAppointments.stream()
                .filter(appointment -> parseSlotDate(appointment.getAppointmentSlot())
                        .map(slotDate -> slotDate.equals(date))
                        .orElse(false))
                .sorted(Comparator.comparing(Appointment::getAppointmentSlot)
                        .thenComparing(a -> a.getTokenNumber() == null ? 0 : a.getTokenNumber()))
                .toList();

        // Batch-fetch patients and attachments for the whole day instead of one query per
        // appointment (this screen is the doctor's main dashboard, loaded constantly).
        List<String> patientIds = dayAppointments.stream().map(Appointment::getPatientPublicId).distinct().toList();
        Map<String, Patient> patientsById = patientIds.isEmpty() ? Map.of() : patientRepository
                .findByPatientPublicIdInAndTenantPublicId(patientIds, tenantPublicId)
                .stream()
                .collect(Collectors.toMap(Patient::getPatientPublicId, p -> p, (a, b) -> a));

        List<String> dayAppointmentIds = dayAppointments.stream().map(Appointment::getAppointmentPublicId).toList();
        Map<String, List<AppointmentAttachment>> attachmentsByAppointment = dayAppointmentIds.isEmpty() ? Map.of() : appointmentAttachmentRepository
                .findByTenantPublicIdAndAppointmentPublicIdIn(tenantPublicId, dayAppointmentIds)
                .stream()
                .collect(Collectors.groupingBy(AppointmentAttachment::getAppointmentPublicId));

        List<PatientDtos.DoctorQueueFacetView> facets = dayAppointments.stream()
                .map(appointment -> toDoctorQueueFacet(
                        doctorPublicId, appointment, doctorAppointments, date,
                        patientsById.get(appointment.getPatientPublicId()),
                        attachmentsByAppointment.getOrDefault(appointment.getAppointmentPublicId(), List.of())))
                .toList();

        int totalAppointments = (int) facets.stream()
                .filter(facet -> !"cancelled".equalsIgnoreCase(facet.status()))
                .count();

        boolean currentOrPastDay = !date.isAfter(LocalDate.now());
        int pendingNotes = currentOrPastDay
                ? (int) facets.stream()
                        .filter(facet -> !"cancelled".equalsIgnoreCase(facet.status()))
                        .filter(facet -> facet.diagnosis() == null || facet.diagnosis().isBlank())
                        .count()
                : 0;

        int avgConsultMinutes = facets.isEmpty() ? 0 : 15;

        return new PatientDtos.DoctorQueueDayView(
                tenantPublicId,
                doctorPublicId,
                date.toString(),
                totalAppointments,
                pendingNotes,
                avgConsultMinutes,
                facets
        );
    }

    private PatientDtos.DoctorQueueFacetView toDoctorQueueFacet(
            String doctorPublicId,
            Appointment appointment,
            List<Appointment> allDoctorAppointments,
            LocalDate selectedDate,
            Patient patient,
            List<AppointmentAttachment> appointmentAttachments
    ) {
        Optional<Prescription> linkedPrescription = resolvePrescriptionForAppointment(doctorPublicId, appointment);

        List<PatientDtos.MedicineView> medicines = linkedPrescription
                .map(prescription -> prescriptionMedicineRepository.findByPrescriptionPublicId(prescription.getPrescriptionPublicId())
                        .stream()
                        .map(medicine -> new PatientDtos.MedicineView(
                                medicine.getMedicineName(),
                                medicine.getStrength(),
                                medicine.getFrequency(),
                                medicine.getDuration(),
                                medicine.getInstructions()
                        ))
                        .toList())
                .orElse(List.of());

        boolean followUp = allDoctorAppointments.stream()
                .filter(other -> !other.getAppointmentPublicId().equals(appointment.getAppointmentPublicId()))
                .filter(other -> other.getPatientPublicId().equals(appointment.getPatientPublicId()))
                .anyMatch(other -> parseSlotDate(other.getAppointmentSlot())
                        .map(slotDate -> slotDate.isBefore(selectedDate))
                        .orElse(false));

        String note = appointment.getNotes() == null ? "" : appointment.getNotes().trim();
        String symptoms = buildSymptoms(note, followUp);
        String diagnosis = linkedPrescription
                .map(Prescription::getNotes)
                .filter(text -> text != null && !text.isBlank())
                .orElse("");
        String rxNotes = linkedPrescription
                .map(Prescription::getNotes)
                .orElse("");

        List<PatientDtos.AttachmentView> attachments = appointmentAttachments
                .stream()
                .map(a -> new PatientDtos.AttachmentView(
                        a.getAttachmentPublicId(),
                        a.getFileName(),
                        a.getMimeType(),
                        a.getDataBase64(),
                        a.getUploadedBy()
                ))
                .toList();

        return new PatientDtos.DoctorQueueFacetView(
                appointment.getAppointmentPublicId(),
                appointment.getPatientPublicId(),
                patient == null ? appointment.getPatientPublicId() : patient.getFullName(),
                appointment.getAppointmentSlot(),
                appointment.getAppointmentStatus(),
                followUp,
                symptoms,
                diagnosis,
                medicines,
                rxNotes,
                appointment.getVitalsSummary() == null ? "" : appointment.getVitalsSummary(),
                attachments,
                appointment.getBookingType(),
                appointment.getTokenNumber(),
                appointment.getTokenSession(),
                appointment.getBookingSource()
        );
    }

    private Optional<Prescription> resolvePrescriptionForAppointment(String doctorPublicId, Appointment appointment) {
        if (appointment.getAppointmentPublicId() != null && !appointment.getAppointmentPublicId().isBlank()) {
            Optional<Prescription> byAppointment = prescriptionRepository.findByTenantPublicIdAndDoctorPublicIdAndAppointmentPublicId(
                    appointment.getTenantPublicId(),
                    doctorPublicId,
                    appointment.getAppointmentPublicId()
            );
            if (byAppointment.isPresent()) {
                return byAppointment;
            }
        }

        return prescriptionRepository
                .findByTenantPublicIdAndDoctorPublicIdAndPatientPublicIdOrderByCreatedAtDesc(
                        appointment.getTenantPublicId(),
                        doctorPublicId,
                        appointment.getPatientPublicId()
                )
                .stream()
                .findFirst();
    }

    private String buildSymptoms(String notes, boolean followUp) {
        if (!notes.isBlank() && !"Booked via patient app".equalsIgnoreCase(notes) && !"Rescheduled".equalsIgnoreCase(notes)) {
            return notes;
        }

        if (followUp) {
            return "Follow-up review with prior treatment response discussion";
        }

        return "General consultation and symptom assessment pending";
    }

    private Optional<LocalDate> parseSlotDate(String slot) {
        if (slot == null || slot.length() < 10) {
            return Optional.empty();
        }

        try {
            return Optional.of(LocalDate.parse(slot.substring(0, 10)));
        } catch (DateTimeParseException ignored) {
            return Optional.empty();
        }
    }

        private String nextPatientPublicId() {
                Long value = jdbcTemplate.queryForObject("SELECT nextval('public.patient_public_id_seq')", Long.class);
                if (value == null) {
                        throw new IllegalStateException("Could not generate patient id");
                }
                return "P-" + String.format("%04d", value);
        }
}
