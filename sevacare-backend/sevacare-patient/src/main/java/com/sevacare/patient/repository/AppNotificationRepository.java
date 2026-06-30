package com.sevacare.patient.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.sevacare.patient.entity.AppNotification;

public interface AppNotificationRepository extends JpaRepository<AppNotification, String> {

    List<AppNotification> findByTenantPublicIdAndRecipientIdAndRecipientTypeOrderByCreatedAtDesc(
            String tenantPublicId, String recipientId, String recipientType);

    long countByTenantPublicIdAndRecipientIdAndRecipientTypeAndReadFalse(
            String tenantPublicId, String recipientId, String recipientType);

    Optional<AppNotification> findByTenantPublicIdAndNotificationPublicId(String tenantPublicId, String notificationPublicId);

    @Modifying
    @Query("""
            UPDATE AppNotification n SET n.read = true
            WHERE n.tenantPublicId = :tenantPublicId
              AND n.recipientId = :recipientId
              AND n.recipientType = :recipientType
              AND n.read = false
            """)
    void markAllRead(@Param("tenantPublicId") String tenantPublicId,
                     @Param("recipientId") String recipientId,
                     @Param("recipientType") String recipientType);

    // Check whether we already sent a reminder for this appointment slot
    boolean existsByTenantPublicIdAndReferenceIdAndNotifType(String tenantPublicId, String referenceId, String notifType);
}
