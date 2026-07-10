package com.sevacare.api.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Resolves the OTP a given mobile number must present at login.
 *
 * Every user shares the platform default OTP unless an operator has recorded an
 * override for that mobile number in {@code public.user_otp_override} — that is
 * how a hospital staff member can be handed a personal code without a code
 * change or redeploy.
 */
@Service
public class OtpService {

    /** Applies to every mobile number without an override row. */
    public static final String DEFAULT_OTP = "0000";

    private static final Logger log = LoggerFactory.getLogger(OtpService.class);

    private final JdbcTemplate jdbcTemplate;

    public OtpService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public String expectedOtp(String mobileNumber) {
        if (mobileNumber == null || mobileNumber.isBlank()) {
            return DEFAULT_OTP;
        }
        try {
            List<String> rows = jdbcTemplate.queryForList(
                    "SELECT otp FROM public.user_otp_override WHERE mobile_number = ?",
                    String.class,
                    mobileNumber.trim());
            if (!rows.isEmpty() && rows.get(0) != null && !rows.get(0).isBlank()) {
                return rows.get(0).trim();
            }
        } catch (DataAccessException e) {
            // An unreachable override table must never lock everyone out.
            log.warn("otp_override_lookup_failed message={}", e.getMessage());
        }
        return DEFAULT_OTP;
    }

    public boolean matches(String mobileNumber, String submittedOtp) {
        if (submittedOtp == null) {
            return false;
        }
        return expectedOtp(mobileNumber).equals(submittedOtp.trim());
    }
}
