package com.sevacare.patient.service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.patient.entity.AppNotification;
import com.sevacare.patient.repository.AppNotificationRepository;
import com.sevacare.shared.dto.NotificationDtos;

@Service
public class NotificationDomainService {

    private static final Logger log = LoggerFactory.getLogger(NotificationDomainService.class);
    private static final DateTimeFormatter DT_FMT = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private final AppNotificationRepository notificationRepository;

    public NotificationDomainService(AppNotificationRepository notificationRepository) {
        this.notificationRepository = notificationRepository;
    }

    @Transactional
    public AppNotification createNotification(
            String tenantPublicId,
            String recipientId,
            String recipientType,
            String notifType,
            String title,
            String body,
            String referenceId
    ) {
        AppNotification n = new AppNotification();
        n.setNotificationPublicId("N-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16).toUpperCase());
        n.setTenantPublicId(tenantPublicId);
        n.setRecipientId(recipientId);
        n.setRecipientType(recipientType);
        n.setNotifType(notifType);
        n.setTitle(title);
        n.setBody(body);
        n.setReferenceId(referenceId);
        n.setRead(false);
        n.setCreatedAt(LocalDateTime.now());
        notificationRepository.save(n);
        log.debug("notification_created tenant={} recipient={} type={}", tenantPublicId, recipientId, notifType);
        return n;
    }

    @Transactional(readOnly = true)
    public NotificationDtos.NotificationCollection listForRecipient(
            String tenantPublicId, String recipientId, String recipientType) {
        try {
            List<NotificationDtos.NotificationView> views =
                    notificationRepository.findByTenantPublicIdAndRecipientIdAndRecipientTypeOrderByCreatedAtDesc(
                                    tenantPublicId, recipientId, recipientType)
                            .stream().map(this::toView).toList();
            long unread = notificationRepository.countByTenantPublicIdAndRecipientIdAndRecipientTypeAndReadFalse(
                    tenantPublicId, recipientId, recipientType);
            return new NotificationDtos.NotificationCollection(tenantPublicId, views, unread);
        } catch (Exception e) {
            // Gracefully handle missing table (migration may not have run yet)
            log.warn("notification_list_failed tenant={} recipient={} type={} error={}",
                    tenantPublicId, recipientId, recipientType, e.getMessage());
            return new NotificationDtos.NotificationCollection(tenantPublicId, List.of(), 0);
        }
    }

    @Transactional
    public void markRead(String tenantPublicId, String notificationPublicId) {
        notificationRepository.findByTenantPublicIdAndNotificationPublicId(tenantPublicId, notificationPublicId)
                .ifPresent(n -> {
                    n.setRead(true);
                    notificationRepository.save(n);
                });
    }

    @Transactional
    public void markAllRead(String tenantPublicId, String recipientId, String recipientType) {
        notificationRepository.markAllRead(tenantPublicId, recipientId, recipientType);
    }

    /** Returns true if a reminder notification for this appointment+type was already sent. */
    @Transactional(readOnly = true)
    public boolean reminderAlreadySent(String tenantPublicId, String referenceId, String notifType) {
        return notificationRepository.existsByTenantPublicIdAndReferenceIdAndNotifType(tenantPublicId, referenceId, notifType);
    }

    private NotificationDtos.NotificationView toView(AppNotification n) {
        return new NotificationDtos.NotificationView(
                n.getNotificationPublicId(),
                n.getRecipientId(),
                n.getRecipientType(),
                n.getNotifType(),
                n.getTitle(),
                n.getBody(),
                n.getReferenceId(),
                n.isRead(),
                n.getCreatedAt() != null ? n.getCreatedAt().format(DT_FMT) : null
        );
    }
}
