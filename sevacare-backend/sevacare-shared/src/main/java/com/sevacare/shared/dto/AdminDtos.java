package com.sevacare.shared.dto;

import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.constraints.NotBlank;

public final class AdminDtos {

    private AdminDtos() {
    }

    public record AdminOverview(String tenantPublicId, List<Metric> metrics) {
    }

    public record Metric(String label, String value, String trend) {
    }

    public record CreateActorRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String name,
            String specialtyOrAgeBand,
            String mobileNumber
    ) {
    }

    public record StaffBookingStat(
            String staffId,
            String staffName,
            String mobileNumber,
            int todayCount,
            int weekCount,
            int monthCount,
            int yearCount
    ) {
    }

    // How patients are arriving: patient app, QR walk-in, or IP-Staff front-desk booking.
    public record BookingSourceCount(
            String source,
            String label,
            int today,
            int week,
            int month,
            int year
    ) {
    }

    public record BookingChannelStats(
            String tenantPublicId,
            List<BookingSourceCount> sources,
            int qrPendingRequests
    ) {
    }

    // ── Reports: what the hospital actually did in a window of time ─────────────
    //
    // Every number here is counted from this tenant's own appointment / patient /
    // prescription rows for the requested period. Revenue is the sum of the fee
    // the treating doctor charges, over the visits that were actually completed —
    // never a flat per-visit guess, and never an all-time counter dressed up as
    // "today".

    public record ReportDayPoint(String date, int booked, int completed) {
    }

    public record ReportDoctorRow(
            String doctorPublicId,
            String doctorName,
            String specialty,
            int visits,
            int completed,
            long revenueRupees
    ) {
    }

    public record HospitalReport(
            String tenantPublicId,
            String period,        // today | week | month | year
            String periodLabel,   // "This Week"
            String fromDate,      // yyyy-MM-dd, inclusive
            String toDate,        // yyyy-MM-dd, inclusive
            int totalVisits,
            int completedVisits,
            int upcomingVisits,
            int cancelledVisits,
            int newPatients,
            int prescriptionsIssued,
            long revenueRupees,
            int avgFeeRupees,
            int completionRatePct,
            String peakHour,      // "10:00 - 11:00", or null when nothing is booked
            List<ReportDayPoint> trend,
            List<ReportDoctorRow> doctors,
            List<BookingSourceCount> channels
    ) {
    }

    public record ManagedActor(String publicId, String tenantPublicId, String name, String action) {
    }

    public record DeleteActorResult(String publicId, String tenantPublicId, String action) {
    }

        public record AdminUserView(
            String adminPublicId,
            String tenantPublicId,
            String fullName,
            String name,
            String email,
            String mobileNumber,
            String secondaryMobile,
            boolean active,
            LocalDateTime createdAt,
            boolean isGeneric,
            String userType
        ) {
        }

        public record AdminUserCollection(String tenantPublicId, List<AdminUserView> admins) {
        }

        public record StaffUserCollection(String tenantPublicId, List<AdminUserView> staff) {
        }

        public record AdminUserUpsertRequest(
            @NotBlank String fullName,
            String name,
            String email,
            String mobileNumber,
            String secondaryMobile,
            Boolean active,
            String userType
        ) {
        }

    public record PatientSummary(
            String patientPublicId,
            String fullName,
            String mobileNumber,
            String gender,
            Integer age,
            String bloodGroup,
            String lastAppointment   // "YYYY-MM-DD HH:MM" or null
    ) {
    }

    public record PatientPage(
            List<PatientSummary> patients,
            long total,
            int page,
            int size
    ) {
    }

    /** Hospital-level support/contact email — distinct from any individual admin's personal email. */
    public record HospitalProfileView(String email) {
    }

    public record HospitalProfileUpdateRequest(String email) {
    }
}
