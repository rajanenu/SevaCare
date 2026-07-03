package com.sevacare.doctor.service;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.DoctorDtos;
import com.sevacare.shared.tenant.TenantContext;

/**
 * Doctor slot blocking — lets a doctor mark a partial-day window (e.g. the
 * next 2 hours, a half day) as unavailable. Blocked windows are surfaced to
 * patient/IP-Staff booking as unavailable slots and enforced at booking time.
 *
 * Stored per tenant schema in the slot_block table; queries run through
 * JdbcTemplate with {@link TenantContext} the same way other cross-module
 * tenant reads do, so the service stays reusable for future modules
 * (medicines, insurance) that need availability data.
 */
@Service
public class SlotBlockService {

    private static final Logger log = LoggerFactory.getLogger(SlotBlockService.class);
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final JdbcTemplate jdbcTemplate;

    public SlotBlockService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public DoctorDtos.SlotBlockView createBlock(String tenantPublicId, String doctorPublicId, DoctorDtos.SlotBlockCreateRequest request) {
        LocalDate date = parseDate(request.date());
        LocalTime start = parseTime(request.startTime());
        LocalTime end = parseTime(request.endTime());
        if (!end.isAfter(start)) {
            throw new IllegalArgumentException("End time must be after start time");
        }
        if (date.isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("Cannot block slots for past dates");
        }

        String schema = TenantContext.tenantSchema();
        String blockId = "SB-" + UUID.randomUUID().toString().replace("-", "").substring(0, 10).toUpperCase();
        String reason = request.reason() == null ? "" : request.reason().trim();

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".slot_block (block_public_id, tenant_public_id, doctor_public_id, block_date, start_time, end_time, reason) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                blockId, tenantPublicId, doctorPublicId, date, start.format(TIME_FMT), end.format(TIME_FMT), reason
        );
        log.info("slot_block_created tenant={} doctor={} block={} date={} window={}-{}",
                tenantPublicId, doctorPublicId, blockId, date, start, end);
        return new DoctorDtos.SlotBlockView(blockId, doctorPublicId, date.toString(), start.format(TIME_FMT), end.format(TIME_FMT), reason);
    }

    @Transactional(readOnly = true)
    public DoctorDtos.SlotBlockCollection listBlocks(String tenantPublicId, String doctorPublicId) {
        String schema = TenantContext.tenantSchema();
        List<DoctorDtos.SlotBlockView> blocks = jdbcTemplate.query(
                "SELECT block_public_id, doctor_public_id, block_date, start_time, end_time, reason FROM " + schema + ".slot_block " +
                "WHERE doctor_public_id = ? AND block_date >= CURRENT_DATE ORDER BY block_date, start_time",
                (rs, i) -> new DoctorDtos.SlotBlockView(
                        rs.getString("block_public_id"),
                        rs.getString("doctor_public_id"),
                        rs.getDate("block_date").toLocalDate().toString(),
                        rs.getString("start_time"),
                        rs.getString("end_time"),
                        rs.getString("reason")
                ),
                doctorPublicId
        );
        return new DoctorDtos.SlotBlockCollection(tenantPublicId, doctorPublicId, blocks);
    }

    @Transactional
    public void deleteBlock(String tenantPublicId, String doctorPublicId, String blockPublicId) {
        String schema = TenantContext.tenantSchema();
        int deleted = jdbcTemplate.update(
                "DELETE FROM " + schema + ".slot_block WHERE block_public_id = ? AND doctor_public_id = ?",
                blockPublicId, doctorPublicId
        );
        if (deleted == 0) {
            throw new IllegalArgumentException("Slot block not found");
        }
        log.info("slot_block_deleted tenant={} doctor={} block={}", tenantPublicId, doctorPublicId, blockPublicId);
    }

    /** Expands the doctor's blocked windows on a date into HH:mm slot marks (15-minute grid). */
    @Transactional(readOnly = true)
    public List<String> blockedSlotsForDate(String tenantPublicId, String doctorPublicId, String date) {
        LocalDate day = parseDate(date);
        String schema = TenantContext.tenantSchema();
        List<String[]> windows = jdbcTemplate.query(
                "SELECT start_time, end_time FROM " + schema + ".slot_block WHERE doctor_public_id = ? AND block_date = ?",
                (rs, i) -> new String[] { rs.getString("start_time"), rs.getString("end_time") },
                doctorPublicId, day
        );
        List<String> slots = new ArrayList<>();
        for (String[] window : windows) {
            LocalTime start = parseTime(window[0]);
            LocalTime end = parseTime(window[1]);
            // Align to the 15-minute grid so partial windows still cover their slots
            LocalTime cursor = start.withMinute((start.getMinute() / 15) * 15);
            while (cursor.isBefore(end)) {
                String mark = cursor.format(TIME_FMT);
                if (!slots.contains(mark)) {
                    slots.add(mark);
                }
                cursor = cursor.plusMinutes(15);
            }
        }
        slots.sort(String::compareTo);
        return slots;
    }

    /** Availability overview for every active doctor of the tenant on a date — used by IP-Staff before booking. */
    @Transactional(readOnly = true)
    public DoctorDtos.DoctorAvailabilityCollection availabilityForDate(String tenantPublicId, String date) {
        LocalDate day = parseDate(date);
        String schema = TenantContext.tenantSchema();

        List<DoctorDtos.DoctorAvailabilityView> doctors = jdbcTemplate.query(
                "SELECT doctor_public_id, full_name, specialty FROM " + schema + ".doctor WHERE active = true ORDER BY full_name",
                (rs, i) -> new DoctorDtos.DoctorAvailabilityView(
                        rs.getString("doctor_public_id"),
                        rs.getString("full_name"),
                        rs.getString("specialty"),
                        day.toString(),
                        false,
                        List.of(),
                        "AVAILABLE"
                )
        );

        List<DoctorDtos.DoctorAvailabilityView> enriched = new ArrayList<>();
        for (DoctorDtos.DoctorAvailabilityView doctor : doctors) {
            boolean onLeave = isDoctorOnLeaveSql(schema, tenantPublicId, doctor.doctorPublicId(), day);
            List<DoctorDtos.SlotBlockView> blocks = jdbcTemplate.query(
                    "SELECT block_public_id, doctor_public_id, block_date, start_time, end_time, reason FROM " + schema + ".slot_block " +
                    "WHERE doctor_public_id = ? AND block_date = ? ORDER BY start_time",
                    (rs, i) -> new DoctorDtos.SlotBlockView(
                            rs.getString("block_public_id"),
                            rs.getString("doctor_public_id"),
                            rs.getDate("block_date").toLocalDate().toString(),
                            rs.getString("start_time"),
                            rs.getString("end_time"),
                            rs.getString("reason")
                    ),
                    doctor.doctorPublicId(), day
            );
            String status = onLeave ? "ON_LEAVE" : (blocks.isEmpty() ? "AVAILABLE" : "PARTIALLY_AVAILABLE");
            enriched.add(new DoctorDtos.DoctorAvailabilityView(
                    doctor.doctorPublicId(), doctor.fullName(), doctor.specialty(), day.toString(), onLeave, blocks, status));
        }
        return new DoctorDtos.DoctorAvailabilityCollection(tenantPublicId, day.toString(), enriched);
    }

    private boolean isDoctorOnLeaveSql(String schema, String tenantPublicId, String doctorPublicId, LocalDate date) {
        // Full-day leave only — hourly leave shows up as slot blocks instead
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".leave_request WHERE tenant_public_id = ? AND doctor_public_id = ? " +
                "AND status IN ('APPROVED','AUTO_APPROVED') AND leave_type <> 'MESSAGE' " +
                "AND start_time IS NULL AND requester_type = 'DOCTOR' AND from_date <= ? AND to_date >= ?",
                Integer.class, tenantPublicId, doctorPublicId, date, date
        );
        return count != null && count > 0;
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
