package com.sevacare.doctor.service;

import java.time.DayOfWeek;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.DoctorDtos;
import com.sevacare.shared.dto.PatientDtos;
import com.sevacare.tenant.service.HospitalManagementService;

/**
 * Doctor-controlled working hours — replaces the one-size-fits-all hardcoded
 * 09:00-14:00/17:00-21:00 window every doctor used to get (see
 * PatientDomainService.bookingSetup). Each doctor can define one or more
 * day-scoped (WEEKDAY/WEEKEND/EVERYDAY) session windows, min 2 hours each.
 * Stored in the doctor_availability table (backfilled with the old default
 * windows for every existing doctor by TenantSchemaMaintenanceService).
 */
@Service
public class DoctorAvailabilityService {

    private static final Logger log = LoggerFactory.getLogger(DoctorAvailabilityService.class);
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");
    private static final LocalTime LEGACY_MORNING_START = LocalTime.of(9, 0);
    private static final LocalTime LEGACY_MORNING_END = LocalTime.of(14, 0);
    private static final LocalTime LEGACY_EVENING_START = LocalTime.of(17, 0);
    private static final LocalTime LEGACY_EVENING_END = LocalTime.of(21, 0);

    private final JdbcTemplate jdbcTemplate;

    public DoctorAvailabilityService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public DoctorDtos.DoctorWorkingHoursView getWorkingHours(String tenantPublicId, String doctorPublicId) {
        String schema = HospitalManagementService.tenantSchema(tenantPublicId);
        List<DoctorDtos.DoctorWorkingHoursRule> rules = jdbcTemplate.query(
                "SELECT day_scope, session_label, start_time, end_time, from_date, to_date, " +
                "include_saturday, include_sunday FROM " + schema + ".doctor_availability " +
                "WHERE doctor_public_id = ? AND active = true ORDER BY from_date NULLS FIRST, start_time",
                (rs, i) -> new DoctorDtos.DoctorWorkingHoursRule(
                        rs.getString("day_scope"),
                        rs.getString("session_label"),
                        rs.getString("start_time").substring(0, 5),
                        rs.getString("end_time").substring(0, 5),
                        rs.getDate("from_date") == null ? null : rs.getDate("from_date").toLocalDate().toString(),
                        rs.getDate("to_date") == null ? null : rs.getDate("to_date").toLocalDate().toString(),
                        rs.getBoolean("include_saturday"),
                        rs.getBoolean("include_sunday")
                ),
                doctorPublicId
        );
        return new DoctorDtos.DoctorWorkingHoursView(doctorPublicId, rules);
    }

    @Transactional
    public DoctorDtos.DoctorWorkingHoursView replaceWorkingHours(
            String tenantPublicId, String doctorPublicId, DoctorDtos.DoctorWorkingHoursUpdateRequest request
    ) {
        for (DoctorDtos.DoctorWorkingHoursRule rule : request.rules()) {
            LocalTime start = parseTime(rule.startTime());
            LocalTime end = parseTime(rule.endTime());
            if (!end.isAfter(start) || Duration.between(start, end).toMinutes() < 120) {
                throw new IllegalArgumentException(
                        "Each availability window must be at least 2 hours (got " + rule.startTime() + "-" + rule.endTime() + ")");
            }
            LocalDate from = rule.fromDate() == null ? null : parseDate(rule.fromDate());
            LocalDate to = rule.toDate() == null ? null : parseDate(rule.toDate());
            if (from != null && to != null && to.isBefore(from)) {
                throw new IllegalArgumentException("To-date must not be before from-date (got " + from + " to " + to + ")");
            }
            if (!rule.saturdayIncluded() && !rule.sundayIncluded()
                    && from != null && to != null && !hasAnyWeekday(from, to)) {
                throw new IllegalArgumentException(
                        "Schedule " + from + " to " + to + " covers only weekend days but both Saturday and Sunday are excluded.");
            }
        }

        String schema = HospitalManagementService.tenantSchema(tenantPublicId);
        jdbcTemplate.update("DELETE FROM " + schema + ".doctor_availability WHERE doctor_public_id = ?", doctorPublicId);
        for (DoctorDtos.DoctorWorkingHoursRule rule : request.rules()) {
            jdbcTemplate.update(
                    "INSERT INTO " + schema + ".doctor_availability " +
                    "(doctor_public_id, day_scope, session_label, start_time, end_time, from_date, to_date, include_saturday, include_sunday) " +
                    "VALUES (?, ?, ?, ?::time, ?::time, ?::date, ?::date, ?, ?)",
                    doctorPublicId, rule.dayScope(), rule.sessionLabel(), rule.startTime(), rule.endTime(),
                    rule.fromDate(), rule.toDate(), rule.saturdayIncluded(), rule.sundayIncluded()
            );
        }
        log.info("doctor_working_hours_updated tenant={} doctor={} rules={}", tenantPublicId, doctorPublicId, request.rules().size());
        return getWorkingHours(tenantPublicId, doctorPublicId);
    }

    /** One doctor_availability row, plus the date-range matching rules. */
    private record Window(String scope, LocalTime start, LocalTime end, LocalDate from, LocalDate to,
                          boolean includeSat, boolean includeSun) {
        /** Range width in days; unbounded ranges sort last so specific ones win. */
        long span() {
            if (from != null && to != null) return to.toEpochDay() - from.toEpochDay();
            if (from != null || to != null) return Long.MAX_VALUE - 1;
            return Long.MAX_VALUE;
        }

        boolean matches(LocalDate day) {
            DayOfWeek dow = day.getDayOfWeek();
            if (from != null && day.isBefore(from)) return false;
            if (to != null && day.isAfter(to)) return false;
            if (dow == DayOfWeek.SATURDAY && !includeSat) return false;
            if (dow == DayOfWeek.SUNDAY && !includeSun) return false;
            // Legacy rows (no date range) may still carry a WEEKDAY/WEEKEND
            // scope; new rules are always EVERYDAY so this check is a no-op.
            if (from == null && to == null && !"EVERYDAY".equals(scope)) {
                boolean isWeekend = dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY;
                return "WEEKEND".equals(scope) == isWeekend;
            }
            return true;
        }
    }

    private List<Window> loadWindows(String schema, String doctorPublicId) {
        return jdbcTemplate.query(
                "SELECT day_scope, start_time, end_time, from_date, to_date, include_saturday, include_sunday " +
                "FROM " + schema + ".doctor_availability WHERE doctor_public_id = ? AND active = true",
                (rs, i) -> new Window(
                        rs.getString("day_scope"),
                        LocalTime.parse(rs.getString("start_time").substring(0, 5), TIME_FMT),
                        LocalTime.parse(rs.getString("end_time").substring(0, 5), TIME_FMT),
                        rs.getDate("from_date") == null ? null : rs.getDate("from_date").toLocalDate(),
                        rs.getDate("to_date") == null ? null : rs.getDate("to_date").toLocalDate(),
                        rs.getBoolean("include_saturday"),
                        rs.getBoolean("include_sunday")
                ),
                doctorPublicId
        );
    }

    /**
     * Windows that apply to one date. Narrowest matching date range wins: a
     * single-day schedule overrides the doctor's general (unbounded or
     * wide-range) schedule on that day.
     */
    private static List<Window> windowsForDate(List<Window> windows, LocalDate day) {
        List<Window> matching = new ArrayList<>();
        for (Window w : windows) {
            if (w.matches(day)) matching.add(w);
        }
        long bestSpan = matching.stream().mapToLong(Window::span).min().orElse(Long.MAX_VALUE);
        matching.removeIf(w -> w.span() != bestSpan);
        return matching;
    }

    /**
     * Per-date availability flags for the booking screen's date strip — one
     * call covering the whole strip instead of one slots call per date.
     */
    @Transactional(readOnly = true)
    public PatientDtos.DoctorAvailableDatesView availableDates(
            String tenantPublicId, String doctorPublicId, String fromDate, int days
    ) {
        LocalDate start = parseDate(fromDate);
        int span = Math.min(Math.max(days, 1), 31);
        String schema = HospitalManagementService.tenantSchema(tenantPublicId);
        List<Window> windows = loadWindows(schema, doctorPublicId);
        List<PatientDtos.DoctorDateAvailability> dates = new ArrayList<>(span);
        for (int i = 0; i < span; i++) {
            LocalDate day = start.plusDays(i);
            // No rules at all → legacy default hours apply, so every day is bookable.
            boolean available = windows.isEmpty() || !windowsForDate(windows, day).isEmpty();
            dates.add(new PatientDtos.DoctorDateAvailability(day.toString(), available));
        }
        return new PatientDtos.DoctorAvailableDatesView(tenantPublicId, doctorPublicId, dates);
    }

    /** Bookable morning/evening slots for one doctor on one date, honoring their working hours. */
    @Transactional(readOnly = true)
    public PatientDtos.DoctorSlotsView slotsForDate(String tenantPublicId, String doctorPublicId, String date) {
        LocalDate day = parseDate(date);
        String schema = HospitalManagementService.tenantSchema(tenantPublicId);
        List<Window> windows = loadWindows(schema, doctorPublicId);

        List<String> morning = new ArrayList<>();
        List<String> evening = new ArrayList<>();
        boolean matchedAny = false;
        for (Window w : windowsForDate(windows, day)) {
            matchedAny = true;
            List<String> bucket = w.start().isBefore(LocalTime.NOON) ? morning : evening;
            for (LocalTime t = w.start(); t.isBefore(w.end()); t = t.plusMinutes(15)) {
                bucket.add(t.format(TIME_FMT));
            }
        }

        if (!matchedAny && windows.isEmpty()) {
            // Safety net only — every doctor is backfilled with default rows at
            // startup, so this covers a doctor created between backfill runs.
            // Deliberately NOT applied when rules exist but none match the
            // date: an excluded Saturday/Sunday or an out-of-range date means
            // the doctor is genuinely unavailable, not on default hours.
            for (LocalTime t = LEGACY_MORNING_START; t.isBefore(LEGACY_MORNING_END); t = t.plusMinutes(15)) {
                morning.add(t.format(TIME_FMT));
            }
            for (LocalTime t = LEGACY_EVENING_START; t.isBefore(LEGACY_EVENING_END); t = t.plusMinutes(15)) {
                evening.add(t.format(TIME_FMT));
            }
        }

        return new PatientDtos.DoctorSlotsView(tenantPublicId, doctorPublicId, day.toString(), morning, evening);
    }

    /** True when the inclusive range contains at least one Monday-Friday day. */
    private static boolean hasAnyWeekday(LocalDate from, LocalDate to) {
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            DayOfWeek dow = d.getDayOfWeek();
            if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) return true;
            if (d.toEpochDay() - from.toEpochDay() > 7) break; // any 8-day range has a weekday
        }
        return false;
    }

    private LocalDate parseDate(String date) {
        try {
            return LocalDate.parse(date);
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("Invalid date. Expected yyyy-MM-dd");
        }
    }

    private LocalTime parseTime(String time) {
        try {
            return LocalTime.parse(time, TIME_FMT);
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("Invalid time. Expected HH:mm");
        }
    }
}
