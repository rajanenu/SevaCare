package com.sevacare.shared.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;

public final class DoctorDtos {

    private DoctorDtos() {
    }

    public record DoctorDashboardView(String doctorPublicId, String tenantPublicId, int totalAppointments, int pendingNotes, String nextPatientPublicId, String nextPatientName,
            java.util.List<PatientDtos.AppointmentEntityView> patientQueue) {
        public DoctorDashboardView(String doctorPublicId, String tenantPublicId, int totalAppointments, int pendingNotes, String nextPatientPublicId, String nextPatientName) {
            this(doctorPublicId, tenantPublicId, totalAppointments, pendingNotes, nextPatientPublicId, nextPatientName, java.util.List.of());
        }
    }

    public record DisablePatientRequest(String reason) {
    }

    public record DisablePatientResult(String tenantPublicId, String patientPublicId, String status, String reason) {
    }

    public record DoctorOnboardingRequest(
            @NotBlank String fullName,
            @NotBlank String specialization,
            @Pattern(regexp = "^[0-9]{10}$") String mobileNumber,
            @Min(18) int age,
            @NotBlank String gender,
            @NotBlank String licenseNumber,
            @Min(0) int experienceYears,
            @NotBlank String address,
            @NotBlank String city,
            @NotBlank String state,
            @Min(10) int appointmentIntervalMinutes,
            @Pattern(regexp = "^\\d{2}:\\d{2}$") String lunchBreakStartTime,
            @Pattern(regexp = "^\\d{2}:\\d{2}$") String lunchBreakEndTime,
            @Min(1) int maxAppointmentsPerDay,
            @NotEmpty String workingDays
    ) {
    }

    public record DoctorScheduleRequest(
            @Min(10) int appointmentIntervalMinutes,
            @Pattern(regexp = "^\\d{2}:\\d{2}$") String lunchBreakStartTime,
            @Pattern(regexp = "^\\d{2}:\\d{2}$") String lunchBreakEndTime,
            @Min(1) int maxAppointmentsPerDay,
            @NotEmpty String workingDays,
            @Pattern(regexp = "^\\d{2}:\\d{2}$") String clinicStartTime,
            @Pattern(regexp = "^\\d{2}:\\d{2}$") String clinicEndTime
    ) {
    }

    public record DoctorOnboardingResult(
            String doctorPublicId,
            String tenantPublicId,
            String status,
            String message
    ) {
    }

    public record DoctorUpsertRequest(
            @NotBlank String fullName,
            @NotBlank String specialty,
            @NotBlank String availability,
            @NotBlank String fee,
            @Pattern(regexp = "^$|^[0-9]{10}$") String mobileNumber,
            boolean active,
            Integer age,
            String address,
            String aboutMe,
            LocalDate availableFrom,
            Boolean readyToLookPatients,
            // SLOT, TOKEN, or BOTH. Null/blank treated as BOTH.
            String bookingMode,
            Integer experienceYears,
            String qualification
    ) {
    }

    public record DoctorView(
            String doctorPublicId,
            String tenantPublicId,
            String fullName,
            String specialty,
            String availability,
            String fee,
            String mobileNumber,
            boolean active,
            Integer age,
            String address,
            String aboutMe,
            LocalDate availableFrom,
            Boolean readyToLookPatients,
            String bookingMode,
            Integer experienceYears,
            String qualification
    ) {
    }

    public record DoctorCollection(String tenantPublicId, java.util.List<DoctorView> doctors) {
    }

    // ── Slot blocking (partial-day unavailability) ────────────────────────────

    public record SlotBlockCreateRequest(
            @NotBlank @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}$") String date,
            @NotBlank @Pattern(regexp = "^\\d{2}:\\d{2}$") String startTime,
            @NotBlank @Pattern(regexp = "^\\d{2}:\\d{2}$") String endTime,
            String reason
    ) {
    }

    public record SlotBlockView(
            String blockPublicId,
            String doctorPublicId,
            String date,
            String startTime,
            String endTime,
            String reason
    ) {
    }

    public record SlotBlockCollection(String tenantPublicId, String doctorPublicId, java.util.List<SlotBlockView> blocks) {
    }

    // ── Availability overview (leave + blocks) — consumed by IP-Staff booking ──

    public record DoctorAvailabilityView(
            String doctorPublicId,
            String fullName,
            String specialty,
            String date,
            boolean onLeave,
            java.util.List<SlotBlockView> blocks,
            String status
    ) {
    }

    public record DoctorAvailabilityCollection(String tenantPublicId, String date, java.util.List<DoctorAvailabilityView> doctors) {
    }

    // ── Working hours (doctor-controlled schedule used for real slot generation) ──
    // Distinct from DoctorAvailabilityView/Collection above, which is a per-date
    // leave+blocks overview, not a recurring schedule.

    public record DoctorWorkingHoursRule(
            // Legacy scope kept for rows written before date-range rules;
            // new rules always send EVERYDAY and rely on the date fields below.
            @NotBlank @Pattern(regexp = "WEEKDAY|WEEKEND|EVERYDAY") String dayScope,
            @NotBlank String sessionLabel,
            @NotBlank @Pattern(regexp = "^\\d{2}:\\d{2}$") String startTime,
            @NotBlank @Pattern(regexp = "^\\d{2}:\\d{2}$") String endTime,
            // Date-range scoping: null fromDate = applies from any date,
            // null toDate = no end date (ongoing). When several rules match a
            // date, the narrowest range wins, so a single-day rule overrides
            // the general schedule.
            @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}$") String fromDate,
            @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}$") String toDate,
            // null is treated as true (included).
            Boolean includeSaturday,
            Boolean includeSunday
    ) {
        public boolean saturdayIncluded() { return includeSaturday == null || includeSaturday; }
        public boolean sundayIncluded() { return includeSunday == null || includeSunday; }
    }

    public record DoctorWorkingHoursUpdateRequest(
            @NotEmpty java.util.List<DoctorWorkingHoursRule> rules
    ) {
    }

    public record DoctorWorkingHoursView(
            String doctorPublicId,
            java.util.List<DoctorWorkingHoursRule> rules
    ) {
    }
}
