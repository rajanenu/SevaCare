package com.sevacare.api.service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.sevacare.doctor.service.LeaveRequestService;
import com.sevacare.patient.entity.Appointment;
import com.sevacare.patient.repository.AppointmentRepository;
import com.sevacare.patient.repository.PrescriptionRepository;
import com.sevacare.patient.service.NotificationDomainService;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;
import com.sevacare.shared.tenant.TenantContext;

@Component
public class ScheduledTasksService {

    private static final Logger log = LoggerFactory.getLogger(ScheduledTasksService.class);
    private static final DateTimeFormatter DT_PARSE = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    private final LeaveRequestService leaveRequestService;
    private final NotificationDomainService notificationService;
    private final AppointmentRepository appointmentRepository;
    private final PrescriptionRepository prescriptionRepository;
    private final TenantRegistryRepository tenantRegistryRepository;

    public ScheduledTasksService(
            LeaveRequestService leaveRequestService,
            NotificationDomainService notificationService,
            AppointmentRepository appointmentRepository,
            PrescriptionRepository prescriptionRepository,
            TenantRegistryRepository tenantRegistryRepository
    ) {
        this.leaveRequestService = leaveRequestService;
        this.notificationService = notificationService;
        this.appointmentRepository = appointmentRepository;
        this.prescriptionRepository = prescriptionRepository;
        this.tenantRegistryRepository = tenantRegistryRepository;
    }

    /** Every hour: auto-approve leave requests pending > 24 hours. */
    @Scheduled(fixedRate = 3_600_000, initialDelay = 300_000)
    public void autoApproveLeaveRequests() {
        try {
            int count = leaveRequestService.autoApprovePendingRequests();
            if (count > 0) {
                log.info("scheduler_auto_approve count={}", count);
            }
        } catch (Exception e) {
            log.error("scheduler_auto_approve_error", e);
        }
    }

    /**
     * Every 30 minutes: send appointment reminder notifications to patients
     * whose next appointment is within 24 hours but hasn't been notified yet.
     */
    @Scheduled(fixedRate = 1_800_000, initialDelay = 300_000)
    public void sendAppointmentReminders() {
        List<TenantRegistry> tenants = tenantRegistryRepository.findByTenantStatus("active");
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime cutoff = now.plusHours(24);

        for (TenantRegistry tenant : tenants) {
            String tenantPublicId = tenant.getTenantPublicId();
            String schema = tenant.getTenantSchemaName();
            try {
                TenantContext.set(tenantPublicId, schema);
                processRemindersForTenant(tenantPublicId, now, cutoff);
            } catch (Exception e) {
                log.error("scheduler_reminder_error tenant={}", tenantPublicId, e);
            } finally {
                TenantContext.clear();
            }
        }
    }

    /**
     * Every hour: notify patients when a new prescription is shared by their doctor.
     * Checks prescriptions created in the last 65 minutes (slight overlap to avoid missing any).
     */
    @Scheduled(fixedRate = 3_600_000, initialDelay = 300_000)
    public void sendPrescriptionNotifications() {
        List<TenantRegistry> tenants = tenantRegistryRepository.findByTenantStatus("active");
        LocalDateTime since = LocalDateTime.now().minusMinutes(65);

        for (TenantRegistry tenant : tenants) {
            String tenantPublicId = tenant.getTenantPublicId();
            String schema = tenant.getTenantSchemaName();
            try {
                TenantContext.set(tenantPublicId, schema);
                processPrescriptionsForTenant(tenantPublicId, since);
            } catch (Exception e) {
                log.error("scheduler_prescription_notif_error tenant={}", tenantPublicId, e);
            } finally {
                TenantContext.clear();
            }
        }
    }

    private void processRemindersForTenant(String tenantPublicId, LocalDateTime now, LocalDateTime cutoff) {
        // Filtered in the database on (tenant, status, slot range) — appointment_slot
        // is "yyyy-MM-dd HH:mm", so a string BETWEEN is also a chronological one.
        // Pulling the tenant's entire appointment history every 30 minutes and
        // filtering in memory got slower with every booking the hospital ever took.
        List<Appointment> upcoming = appointmentRepository
                .findByTenantPublicIdAndAppointmentStatusAndAppointmentSlotBetween(
                        tenantPublicId, "upcoming", now.format(DT_PARSE), cutoff.format(DT_PARSE));

        for (Appointment appt : upcoming) {
            if (notificationService.reminderAlreadySent(tenantPublicId, appt.getAppointmentPublicId(), "APPOINTMENT_REMINDER")) {
                continue;
            }
            try {
                LocalDateTime slot = LocalDateTime.parse(appt.getAppointmentSlot(), DT_PARSE);
                long hoursAway = java.time.Duration.between(LocalDateTime.now(), slot).toHours();
                String timeLabel = hoursAway <= 1 ? "in less than 1 hour" : "in ~" + hoursAway + " hours";

                notificationService.createNotification(
                        tenantPublicId,
                        appt.getPatientPublicId(),
                        "PATIENT",
                        "APPOINTMENT_REMINDER",
                        "Upcoming Appointment Reminder",
                        "Your appointment with Dr. " + appt.getDoctorPublicId() + " is scheduled " + timeLabel + ". Please be ready.",
                        appt.getAppointmentPublicId()
                );
                log.debug("appointment_reminder_sent tenant={} patient={} appt={}", tenantPublicId, appt.getPatientPublicId(), appt.getAppointmentPublicId());
            } catch (Exception e) {
                log.warn("appointment_reminder_failed appt={}", appt.getAppointmentPublicId(), e);
            }
        }
    }

    private void processPrescriptionsForTenant(String tenantPublicId, LocalDateTime since) {
        prescriptionRepository.findByTenantPublicIdAndCreatedAtAfter(tenantPublicId, since)
                .forEach(p -> {
                    if (notificationService.reminderAlreadySent(tenantPublicId, p.getPrescriptionPublicId(), "PRESCRIPTION_SHARED")) {
                        return;
                    }
                    notificationService.createNotification(
                            tenantPublicId,
                            p.getPatientPublicId(),
                            "PATIENT",
                            "PRESCRIPTION_SHARED",
                            "New Prescription Available",
                            "Dr. " + (p.getDoctorName() != null ? p.getDoctorName() : "your doctor") + " has shared a new prescription for you. Tap to view.",
                            p.getPrescriptionPublicId()
                    );
                    log.debug("prescription_notif_sent tenant={} patient={} rx={}", tenantPublicId, p.getPatientPublicId(), p.getPrescriptionPublicId());
                });
    }
}
