package com.sevacare.doctor.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.doctor.entity.Doctor;
import com.sevacare.doctor.entity.LeaveRequest;
import com.sevacare.doctor.repository.DoctorRepository;
import com.sevacare.doctor.repository.LeaveRequestRepository;
import com.sevacare.patient.service.NotificationDomainService;
import com.sevacare.shared.dto.NotificationDtos;

@Service
public class LeaveRequestService {

    private static final Logger log = LoggerFactory.getLogger(LeaveRequestService.class);
    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ISO_LOCAL_DATE;
    private static final DateTimeFormatter DT_FMT = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private final LeaveRequestRepository leaveRequestRepository;
    private final DoctorRepository doctorRepository;
    private final NotificationDomainService notificationService;
    private final SlotBlockService slotBlockService;

    public LeaveRequestService(
            LeaveRequestRepository leaveRequestRepository,
            DoctorRepository doctorRepository,
            NotificationDomainService notificationService,
            SlotBlockService slotBlockService
    ) {
        this.leaveRequestRepository = leaveRequestRepository;
        this.doctorRepository = doctorRepository;
        this.notificationService = notificationService;
        this.slotBlockService = slotBlockService;
    }

    @Transactional
    public NotificationDtos.LeaveRequestView createLeaveRequest(
            String tenantPublicId,
            String doctorPublicId,
            NotificationDtos.LeaveRequestCreateRequest req,
            String adminPublicId
    ) {
        Doctor doctor = doctorRepository.findByDoctorPublicIdAndTenantPublicId(doctorPublicId, tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Doctor not found"));
        return createRequest(tenantPublicId, doctorPublicId, doctor.getFullName(), "DOCTOR", req, adminPublicId);
    }

    /** IP-Staff leave request — same flow, requester is a staff member (no doctor record). */
    @Transactional
    public NotificationDtos.LeaveRequestView createStaffLeaveRequest(
            String tenantPublicId,
            String staffPublicId,
            String staffName,
            NotificationDtos.LeaveRequestCreateRequest req,
            String adminPublicId
    ) {
        return createRequest(tenantPublicId, staffPublicId, staffName, "STAFF", req, adminPublicId);
    }

    private NotificationDtos.LeaveRequestView createRequest(
            String tenantPublicId,
            String requesterId,
            String requesterName,
            String requesterType,
            NotificationDtos.LeaveRequestCreateRequest req,
            String adminPublicId
    ) {
        LeaveRequest lr = new LeaveRequest();
        lr.setRequestPublicId("LR-" + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase());
        lr.setTenantPublicId(tenantPublicId);
        lr.setDoctorPublicId(requesterId);
        lr.setDoctorName(requesterName);
        lr.setLeaveType(req.leaveType().toUpperCase());
        lr.setMessage(req.message() == null ? "" : req.message());
        lr.setStatus("PENDING");
        lr.setSubmittedAt(LocalDateTime.now());
        lr.setRequesterType(requesterType);

        if (req.fromDate() != null && !req.fromDate().isBlank()) {
            lr.setFromDate(LocalDate.parse(req.fromDate(), DATE_FMT));
        }
        if (req.toDate() != null && !req.toDate().isBlank()) {
            lr.setToDate(LocalDate.parse(req.toDate(), DATE_FMT));
        }

        // Hourly (partial-day) leave — both times must come together and be valid
        String start = req.startTime() == null ? "" : req.startTime().trim();
        String end = req.endTime() == null ? "" : req.endTime().trim();
        if (!start.isEmpty() || !end.isEmpty()) {
            if (start.isEmpty() || end.isEmpty()) {
                throw new IllegalArgumentException("Both start and end time are required for hourly leave");
            }
            java.time.LocalTime st = java.time.LocalTime.parse(start);
            java.time.LocalTime en = java.time.LocalTime.parse(end);
            if (!en.isAfter(st)) {
                throw new IllegalArgumentException("End time must be after start time");
            }
            lr.setStartTime(start);
            lr.setEndTime(end);
        }

        leaveRequestRepository.save(lr);

        // Notify all admins of the tenant
        String typeLabel = typeLabel(lr.getLeaveType());
        String dateRange = lr.getFromDate() != null
                ? " (" + lr.getFromDate() + " to " + lr.getToDate()
                        + (lr.getStartTime() != null ? ", " + lr.getStartTime() + "–" + lr.getEndTime() : "")
                        + ")"
                : "";
        String requesterLabel = "STAFF".equals(requesterType) ? requesterName + " (IP-Staff)" : "Dr. " + requesterName;
        notificationService.createNotification(
                tenantPublicId,
                adminPublicId,
                "ADMIN",
                "LEAVE_REQUEST",
                "Leave Request from " + requesterLabel,
                typeLabel + " leave request" + dateRange + (lr.getMessage().isBlank() ? "" : ": " + lr.getMessage()),
                lr.getRequestPublicId()
        );

        log.info("leave_request_created tenant={} requester={} requesterType={} type={} request={}",
                tenantPublicId, requesterId, requesterType, lr.getLeaveType(), lr.getRequestPublicId());

        return toView(lr);
    }

    @Transactional(readOnly = true)
    public NotificationDtos.LeaveRequestCollection listForDoctor(String tenantPublicId, String doctorPublicId) {
        List<NotificationDtos.LeaveRequestView> views =
                leaveRequestRepository.findByTenantPublicIdAndDoctorPublicIdOrderBySubmittedAtDesc(tenantPublicId, doctorPublicId)
                        .stream().map(this::toView).toList();
        return new NotificationDtos.LeaveRequestCollection(tenantPublicId, views);
    }

    /** IP-Staff view their own requests — requester id is stored in the doctorPublicId column. */
    @Transactional(readOnly = true)
    public NotificationDtos.LeaveRequestCollection listForStaff(String tenantPublicId, String staffPublicId) {
        return listForDoctor(tenantPublicId, staffPublicId);
    }

    @Transactional(readOnly = true)
    public NotificationDtos.LeaveRequestCollection listForAdmin(String tenantPublicId) {
        List<NotificationDtos.LeaveRequestView> views =
                leaveRequestRepository.findByTenantPublicIdOrderBySubmittedAtDesc(tenantPublicId)
                        .stream().map(this::toView).toList();
        return new NotificationDtos.LeaveRequestCollection(tenantPublicId, views);
    }

    @Transactional
    public NotificationDtos.LeaveRequestView actionRequest(
            String tenantPublicId,
            String requestPublicId,
            NotificationDtos.LeaveRequestActionRequest req
    ) {
        LeaveRequest lr = leaveRequestRepository.findByTenantPublicIdAndRequestPublicId(tenantPublicId, requestPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Leave request not found"));

        String action = req.action().toUpperCase();
        switch (action) {
            case "APPROVE" -> lr.setStatus("APPROVED");
            case "DECLINE" -> lr.setStatus("DECLINED");
            case "COMMENT" -> { /* status stays PENDING, just add comment */ }
            default -> throw new IllegalArgumentException("Unknown action: " + action);
        }

        if (req.response() != null && !req.response().isBlank()) {
            lr.setAdminResponse(req.response());
        }
        lr.setRespondedAt(LocalDateTime.now());
        leaveRequestRepository.save(lr);

        if ("APPROVE".equals(action)) {
            materializeHourlyLeaveBlocks(lr);
        }

        // Notify the requester (doctor or IP-staff)
        String notifType = switch (action) {
            case "APPROVE" -> "LEAVE_APPROVED";
            case "DECLINE" -> "LEAVE_DECLINED";
            default -> "ADMIN_MESSAGE";
        };
        String title = switch (action) {
            case "APPROVE" -> "Leave Approved";
            case "DECLINE" -> "Leave Declined";
            default -> "Admin Response to Your Request";
        };
        String body = req.response() != null && !req.response().isBlank()
                ? req.response()
                : (action.equals("APPROVE") ? "Your leave request has been approved." : "Your leave request was declined.");

        notificationService.createNotification(
                tenantPublicId,
                lr.getDoctorPublicId(),
                recipientTypeFor(lr),
                notifType,
                title,
                body,
                lr.getRequestPublicId()
        );

        log.info("leave_request_action tenant={} request={} action={}", tenantPublicId, requestPublicId, action);
        return toView(lr);
    }

    private String recipientTypeFor(LeaveRequest lr) {
        return "STAFF".equalsIgnoreCase(lr.getRequesterType()) ? "STAFF" : "DOCTOR";
    }

    /**
     * Approved hourly leave for a DOCTOR becomes slot blocks so booking and
     * availability screens automatically show that window as unavailable
     * (full-day leave keeps using the isDoctorOnLeave check instead).
     */
    private void materializeHourlyLeaveBlocks(LeaveRequest lr) {
        if (!"DOCTOR".equalsIgnoreCase(lr.getRequesterType() == null ? "DOCTOR" : lr.getRequesterType())) return;
        if (lr.getStartTime() == null || lr.getEndTime() == null) return;
        if (lr.getFromDate() == null) return;
        LocalDate to = lr.getToDate() != null ? lr.getToDate() : lr.getFromDate();
        for (LocalDate d = lr.getFromDate(); !d.isAfter(to); d = d.plusDays(1)) {
            if (d.isBefore(LocalDate.now())) continue; // blocks can't target past dates
            try {
                slotBlockService.createBlock(
                        lr.getTenantPublicId(),
                        lr.getDoctorPublicId(),
                        new com.sevacare.shared.dto.DoctorDtos.SlotBlockCreateRequest(
                                d.toString(),
                                lr.getStartTime(),
                                lr.getEndTime(),
                                "Approved leave " + lr.getRequestPublicId()
                        )
                );
            } catch (Exception e) {
                log.warn("hourly_leave_block_failed request={} date={} err={}", lr.getRequestPublicId(), d, e.getMessage());
            }
        }
    }

    /** Called by the scheduler every hour — auto-approves requests pending > 24 hours. */
    @Transactional
    public int autoApprovePendingRequests() {
        LocalDateTime cutoff = LocalDateTime.now().minusHours(24);
        List<LeaveRequest> stale = leaveRequestRepository.findPendingSubmittedBefore(cutoff);
        for (LeaveRequest lr : stale) {
            if ("MESSAGE".equalsIgnoreCase(lr.getLeaveType())) continue;
            lr.setStatus("AUTO_APPROVED");
            lr.setAdminResponse("Auto-approved: no admin response within 24 hours.");
            lr.setRespondedAt(LocalDateTime.now());
            leaveRequestRepository.save(lr);
            materializeHourlyLeaveBlocks(lr);

            notificationService.createNotification(
                    lr.getTenantPublicId(),
                    lr.getDoctorPublicId(),
                    recipientTypeFor(lr),
                    "LEAVE_APPROVED",
                    "Leave Auto-Approved",
                    "Your leave request (" + typeLabel(lr.getLeaveType()) + ") has been automatically approved as no admin response was received within 24 hours.",
                    lr.getRequestPublicId()
            );
            log.info("leave_auto_approved tenant={} doctor={} request={}", lr.getTenantPublicId(), lr.getDoctorPublicId(), lr.getRequestPublicId());
        }
        return stale.size();
    }

    /** Called by booking setup — returns true if the doctor is on approved leave for the given date. */
    @Transactional(readOnly = true)
    public boolean isDoctorOnLeave(String tenantPublicId, String doctorPublicId, LocalDate date) {
        return leaveRequestRepository.isDoctorOnLeave(tenantPublicId, doctorPublicId, date);
    }

    private NotificationDtos.LeaveRequestView toView(LeaveRequest lr) {
        return new NotificationDtos.LeaveRequestView(
                lr.getRequestPublicId(),
                lr.getTenantPublicId(),
                lr.getDoctorPublicId(),
                lr.getDoctorName(),
                lr.getLeaveType(),
                lr.getFromDate() != null ? lr.getFromDate().format(DATE_FMT) : null,
                lr.getToDate() != null ? lr.getToDate().format(DATE_FMT) : null,
                lr.getMessage(),
                lr.getStatus(),
                lr.getAdminResponse(),
                lr.getSubmittedAt() != null ? lr.getSubmittedAt().format(DT_FMT) : null,
                lr.getRespondedAt() != null ? lr.getRespondedAt().format(DT_FMT) : null,
                lr.getStartTime(),
                lr.getEndTime(),
                lr.getRequesterType() == null ? "DOCTOR" : lr.getRequesterType()
        );
    }

    private String typeLabel(String type) {
        return switch (type.toUpperCase()) {
            case "SICK" -> "Sick";
            case "VACATION" -> "Vacation";
            case "EMERGENCY" -> "Emergency";
            case "MESSAGE" -> "Message";
            default -> "Other";
        };
    }
}
