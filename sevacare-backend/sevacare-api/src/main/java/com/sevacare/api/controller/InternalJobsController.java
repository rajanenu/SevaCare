package com.sevacare.api.controller;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.api.security.RefreshTokenService;
import com.sevacare.api.service.IdempotencyService;
import com.sevacare.api.service.ScheduledTasksService;
import com.sevacare.patient.service.WhatsAppService;
import com.sevacare.pharmacy.refill.service.RefillReminderService;
import com.sevacare.tenant.event.OutboxEventDispatcher;

/**
 * Cloud Run throttles CPU to near-zero between requests under request-based
 * billing, so the {@code @Scheduled} timers in this codebase fire late or not at
 * all on a quiet instance — and the quiet hours are exactly when the prune jobs
 * are due. This endpoint makes every background job runnable *inside a request*:
 * one Cloud Scheduler job (free tier) POSTs here every few minutes and the work
 * runs with full CPU. The {@code @Scheduled} annotations stay for local dev, and
 * double-running is safe by design: the outboxes claim rows with
 * {@code FOR UPDATE SKIP LOCKED}, the notification jobs dedupe on
 * reminderAlreadySent, and the prunes are DELETEs of already-dead rows.
 *
 * <p>Auth is a shared secret ({@code SEVACARE_JOBS_TOKEN}) compared in constant
 * time. Unset token = endpoint answers 404, so a deployment that never configures
 * the scheduler exposes nothing.
 */
@RestController
@RequestMapping("/internal/jobs")
public class InternalJobsController {

    private static final Logger log = LoggerFactory.getLogger(InternalJobsController.class);
    private static final ZoneId IST = ZoneId.of("Asia/Kolkata");

    private final OutboxEventDispatcher outboxEventDispatcher;
    private final WhatsAppService whatsAppService;
    private final ScheduledTasksService scheduledTasksService;
    private final RefreshTokenService refreshTokenService;
    private final IdempotencyService idempotencyService;
    private final RefillReminderService refillReminderService;
    private final String jobsToken;

    public InternalJobsController(
            OutboxEventDispatcher outboxEventDispatcher,
            WhatsAppService whatsAppService,
            ScheduledTasksService scheduledTasksService,
            RefreshTokenService refreshTokenService,
            IdempotencyService idempotencyService,
            RefillReminderService refillReminderService,
            @Value("${sevacare.jobs.token:}") String jobsToken
    ) {
        this.outboxEventDispatcher = outboxEventDispatcher;
        this.whatsAppService = whatsAppService;
        this.scheduledTasksService = scheduledTasksService;
        this.refreshTokenService = refreshTokenService;
        this.idempotencyService = idempotencyService;
        this.refillReminderService = refillReminderService;
        this.jobsToken = jobsToken == null ? "" : jobsToken.trim();
    }

    @PostMapping("/run")
    public ResponseEntity<Map<String, String>> runDueJobs(
            @RequestHeader(value = "X-Jobs-Token", required = false) String presentedToken) {
        if (jobsToken.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        if (!constantTimeEquals(jobsToken, presentedToken)) {
            log.warn("internal_jobs_denied reason=bad_token");
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        Map<String, String> outcomes = new LinkedHashMap<>();
        run(outcomes, "outbox_dispatch", outboxEventDispatcher::dispatchAll);
        run(outcomes, "whatsapp_drain", whatsAppService::drainOutbox);
        run(outcomes, "leave_auto_approve", scheduledTasksService::autoApproveLeaveRequests);
        run(outcomes, "appointment_reminders", scheduledTasksService::sendAppointmentReminders);
        run(outcomes, "prescription_notifications", scheduledTasksService::sendPrescriptionNotifications);

        // Refill nudges are a morning ritual, not a firehose: run from 8am IST on
        // (the service's own per-tenant day guard makes repeat ticks no-ops, and
        // every statement it runs is idempotent anyway).
        if (LocalTime.now(IST).getHour() >= 8) {
            run(outcomes, "pharmacy_refill_scan", refillReminderService::scanAllTenants);
        }

        // The prunes were nightly crons; keep them to the small hours rather than
        // deleting on every tick. Re-running within the hour is a no-op DELETE.
        if (LocalTime.now(IST).getHour() == 3) {
            run(outcomes, "auth_token_prune", refreshTokenService::pruneExpired);
            run(outcomes, "idempotency_key_prune", idempotencyService::pruneExpired);
            run(outcomes, "whatsapp_outbox_prune", whatsAppService::pruneOld);
        }
        return ResponseEntity.ok(outcomes);
    }

    private void run(Map<String, String> outcomes, String name, Runnable job) {
        try {
            job.run();
            outcomes.put(name, "ok");
        } catch (Exception e) {
            // One broken job must not stop the rest of the sweep.
            outcomes.put(name, "failed");
            log.error("internal_job_failed job={}", name, e);
        }
    }

    private boolean constantTimeEquals(String expected, String presented) {
        if (presented == null || presented.isBlank()) {
            return false;
        }
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                presented.trim().getBytes(StandardCharsets.UTF_8));
    }
}
