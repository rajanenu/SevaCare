package com.sevacare.api.service;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

/**
 * Resolves the login credential a mobile number must present.
 *
 * <p>Every user shares the platform default OTP ({@code 0000}) until they set
 * their own 4-digit passcode from the Profile screen — after which the default
 * stops working for that number. One row in {@code public.user_passcode} covers
 * a person across roles and tenants, because the mobile number is the identity.
 * No SMS is ever sent; the passcode <em>is</em> the credential.
 *
 * <p>Two rules this class must never lose:
 * <ul>
 *   <li><b>Fail closed.</b> If the passcode table cannot be read we cannot know
 *   whether this user set a passcode, so accepting the default would let an
 *   outage downgrade every protected account back to {@code 0000}. The old
 *   {@code OtpService} failed open here, deliberately; that was wrong for an
 *   authentication decision and is reversed.</li>
 *   <li><b>The lockout is the security.</b> A 4-digit space is 10,000 codes, so
 *   BCrypt alone protects nothing — {@value #MAX_ATTEMPTS} wrong attempts lock
 *   the number for {@link #LOCK} (persisted in the DB, so it holds across Cloud
 *   Run instances). Without it the passcode falls to brute force in minutes.</li>
 * </ul>
 */
@Service
public class PasscodeService {

    /** Applies to every mobile number without a passcode row. */
    public static final String DEFAULT_OTP = "0000";

    static final int MAX_ATTEMPTS = 5;
    static final Duration LOCK = Duration.ofMinutes(15);

    private static final Pattern FOUR_DIGITS = Pattern.compile("\\d{4}");
    private static final Logger log = LoggerFactory.getLogger(PasscodeService.class);

    /** What the login screen should ask for. Carried on the OTP-request response. */
    public enum CredentialMode {
        /** No passcode set — the shared default OTP applies and the UI says "OTP". */
        DEFAULT_OTP,
        /** The user set their own code — the UI asks for "your 4-digit passcode". */
        PASSCODE
    }

    private record PasscodeRow(String hash, int failedAttempts, Timestamp lockedUntil) {
    }

    private final JdbcTemplate jdbcTemplate;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public PasscodeService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** Which credential this mobile must present — drives the login screen copy. */
    public CredentialMode mode(String mobileNumber) {
        return find(normalize(mobileNumber)) == null ? CredentialMode.DEFAULT_OTP : CredentialMode.PASSCODE;
    }

    public boolean hasPasscode(String mobileNumber) {
        return mode(mobileNumber) == CredentialMode.PASSCODE;
    }

    /**
     * Verifies the submitted code, enforcing the lockout. Throws with a
     * user-facing message on every failure path; returning normally means the
     * caller is authenticated.
     */
    public void verify(String mobileNumber, String submittedCode) {
        String mobile = normalize(mobileNumber);
        String submitted = submittedCode == null ? "" : submittedCode.trim();
        if (submitted.isEmpty()) {
            throw new IllegalArgumentException("Enter the code to continue.");
        }

        PasscodeRow row;
        try {
            row = find(mobile);
        } catch (DataAccessException e) {
            log.error("passcode_lookup_failed mobile_present={} message={}", !mobile.isEmpty(), e.getMessage());
            throw new AuthUnavailableException("Sign-in is temporarily unavailable. Please try again in a moment.");
        }

        if (row == null) {
            // Default mode. No lockout: the default is a shared, known value, so
            // counting attempts against it protects nothing and would only let a
            // stranger lock a legitimate user out.
            if (!DEFAULT_OTP.equals(submitted)) {
                throw new IllegalArgumentException("Invalid OTP");
            }
            return;
        }

        Instant now = Instant.now();
        boolean wasLocked = row.lockedUntil() != null;
        if (wasLocked && now.isBefore(row.lockedUntil().toInstant())) {
            long minutesLeft = Math.max(1, Duration.between(now, row.lockedUntil().toInstant()).toMinutes() + 1);
            throw new TooManyAttemptsException(
                    "Too many wrong attempts. Try again in " + minutesLeft + " minute" + (minutesLeft == 1 ? "" : "s") + ".");
        }

        if (encoder.matches(submitted, row.hash())) {
            if (row.failedAttempts() > 0 || wasLocked) {
                jdbcTemplate.update(
                        "UPDATE public.user_passcode SET failed_attempts = 0, locked_until = NULL WHERE mobile_number = ?",
                        mobile);
            }
            return;
        }

        // An expired lock starts a fresh attempt window rather than re-locking
        // on the first mistake after it lifts.
        int attempts = (wasLocked ? 0 : row.failedAttempts()) + 1;
        if (attempts >= MAX_ATTEMPTS) {
            jdbcTemplate.update(
                    "UPDATE public.user_passcode SET failed_attempts = ?, locked_until = ? WHERE mobile_number = ?",
                    attempts, Timestamp.from(now.plus(LOCK)), mobile);
            throw new TooManyAttemptsException(
                    "Too many wrong attempts. Try again in " + LOCK.toMinutes() + " minutes.");
        }
        jdbcTemplate.update(
                "UPDATE public.user_passcode SET failed_attempts = ?, locked_until = NULL WHERE mobile_number = ?",
                attempts, mobile);
        int remaining = MAX_ATTEMPTS - attempts;
        throw new IllegalArgumentException(
                "Incorrect passcode. " + remaining + " attempt" + (remaining == 1 ? "" : "s") + " left.");
    }

    /**
     * Sets or changes the caller's own passcode. The current credential (default
     * OTP or existing passcode) must verify first — with the same lockout, so
     * this endpoint is not a cheaper brute-force target than login.
     */
    public void setPasscode(String mobileNumber, String currentCode, String newPasscode, String updatedBy) {
        String mobile = normalize(mobileNumber);
        if (mobile.isEmpty()) {
            throw new IllegalArgumentException("Mobile number is required.");
        }
        verify(mobile, currentCode);
        String candidate = newPasscode == null ? "" : newPasscode.trim();
        if (!FOUR_DIGITS.matcher(candidate).matches()) {
            throw new IllegalArgumentException("Passcode must be exactly 4 digits.");
        }
        if (DEFAULT_OTP.equals(candidate)) {
            throw new IllegalArgumentException("0000 is the shared default — please choose a different code.");
        }
        jdbcTemplate.update(
                "INSERT INTO public.user_passcode (mobile_number, passcode_hash, updated_by) VALUES (?, ?, ?) " +
                        "ON CONFLICT (mobile_number) DO UPDATE SET passcode_hash = EXCLUDED.passcode_hash, " +
                        "failed_attempts = 0, locked_until = NULL, updated_at = CURRENT_TIMESTAMP, " +
                        "updated_by = EXCLUDED.updated_by",
                mobile, encoder.encode(candidate), updatedBy);
        log.info("passcode_set updated_by={}", updatedBy);
    }

    /**
     * Clears a passcode so the number falls back to the default OTP — the
     * recovery path for a forgotten code. Only ever called by an admin for their
     * own tenant's users, or by a platform admin (authorization is the caller's
     * job; this method just records who).
     */
    public boolean resetPasscode(String mobileNumber, String resetBy) {
        String mobile = normalize(mobileNumber);
        int deleted = jdbcTemplate.update("DELETE FROM public.user_passcode WHERE mobile_number = ?", mobile);
        if (deleted > 0) {
            log.info("passcode_reset reset_by={}", resetBy);
        }
        return deleted > 0;
    }

    private PasscodeRow find(String mobile) {
        if (mobile.isEmpty()) {
            return null;
        }
        List<PasscodeRow> rows = jdbcTemplate.query(
                "SELECT passcode_hash, failed_attempts, locked_until FROM public.user_passcode WHERE mobile_number = ?",
                (rs, i) -> new PasscodeRow(rs.getString(1), rs.getInt(2), rs.getTimestamp(3)),
                mobile);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private static String normalize(String mobileNumber) {
        return mobileNumber == null ? "" : mobileNumber.trim();
    }
}
