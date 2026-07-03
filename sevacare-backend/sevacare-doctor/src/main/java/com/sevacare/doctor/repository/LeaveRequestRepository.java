package com.sevacare.doctor.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.sevacare.doctor.entity.LeaveRequest;

public interface LeaveRequestRepository extends JpaRepository<LeaveRequest, String> {

    List<LeaveRequest> findByTenantPublicIdAndDoctorPublicIdOrderBySubmittedAtDesc(String tenantPublicId, String doctorPublicId);

    List<LeaveRequest> findByTenantPublicIdOrderBySubmittedAtDesc(String tenantPublicId);

    Optional<LeaveRequest> findByTenantPublicIdAndRequestPublicId(String tenantPublicId, String requestPublicId);

    // Find PENDING requests submitted more than 24 hours ago (for auto-approval)
    @Query("SELECT lr FROM LeaveRequest lr WHERE lr.status = 'PENDING' AND lr.submittedAt <= :cutoff")
    List<LeaveRequest> findPendingSubmittedBefore(@Param("cutoff") LocalDateTime cutoff);

    // Check if doctor is on approved FULL-DAY leave covering a given date.
    // Hourly leave (startTime set) doesn't take the doctor out for the whole
    // day — it materializes as slot blocks on approval instead.
    @Query("""
            SELECT COUNT(lr) > 0 FROM LeaveRequest lr
            WHERE lr.tenantPublicId = :tenantPublicId
              AND lr.doctorPublicId = :doctorPublicId
              AND lr.status IN ('APPROVED','AUTO_APPROVED')
              AND lr.leaveType <> 'MESSAGE'
              AND lr.startTime IS NULL
              AND lr.requesterType = 'DOCTOR'
              AND lr.fromDate <= :date
              AND lr.toDate >= :date
            """)
    boolean isDoctorOnLeave(@Param("tenantPublicId") String tenantPublicId,
                             @Param("doctorPublicId") String doctorPublicId,
                             @Param("date") java.time.LocalDate date);
}
