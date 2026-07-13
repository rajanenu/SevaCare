package com.sevacare.shared.dto;

import java.util.List;

import jakarta.validation.constraints.NotBlank;

public final class AuthDtos {

    private AuthDtos() {
    }

    // ── Standalone pharmacy login ────────────────────────────────────────────
    // A medical store signs in by mobile number alone; the backend resolves which
    // store(s) that number runs. No hospital search, no tenant code to remember —
    // the shop identity is the person's phone. See PharmacyAuthController.

    public record PharmacyOtpRequest(@NotBlank String mobileNumber) {
    }

    /** One store a mobile number can sign into. */
    public record PharmacyLoginOption(String tenantPublicId, String shopName, String userType) {
    }

    /** The store(s) resolved for a mobile, returned before the OTP step. */
    public record PharmacyOtpResponse(List<PharmacyLoginOption> shops, String otpHint, String credentialMode) {
    }

    public record PharmacyVerifyRequest(
            @NotBlank String mobileNumber,
            @NotBlank String otp,
            @NotBlank String tenantPublicId
    ) {
    }

    public record OtpRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String role,
            @NotBlank String mobileNumber
    ) {
    }

    /**
     * {@code credentialMode} tells the login screen what to ask for:
     * {@code DEFAULT_OTP} keeps today's "OTP sent to your mobile" copy, while
     * {@code PASSCODE} means this user set their own code and the screen should
     * say "Enter your 4-digit passcode" — nothing was, or ever is, sent by SMS.
     */
    public record OtpRequestAccepted(String tenantPublicId, String role, String mobileNumber, String otpHint,
            String credentialMode) {
    }

    public record OtpVerifyRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String role,
            @NotBlank String mobileNumber,
            @NotBlank String otp
    ) {
    }

    /**
     * {@code token} is a short-lived access JWT (~60 min); {@code refreshToken}
     * is the opaque, rotating, server-side-revocable credential that keeps the
     * session alive past it. See {@code RefreshTokenService}.
     */
    public record AuthenticatedSession(String tenantPublicId, String role, String subjectPublicId, String token, boolean isGeneric, String subjectName, String userType, String refreshToken) {
    }

    /** Exchange a live refresh token for a fresh access token (and a rotated refresh token). */
    public record RefreshRequest(@NotBlank String refreshToken) {
    }

    public record RefreshedSession(String token, String refreshToken) {
    }

    /** Logout: revokes the refresh token; the bearer access token is revoked from the header. */
    public record LogoutRequest(String refreshToken) {
    }

    // ── Passcode (self-set 4-digit login code) ──────────────────────────────

    /** Set or change the caller's own passcode; the current credential must verify first. */
    public record PasscodeChangeRequest(@NotBlank String currentCode, @NotBlank String newPasscode) {
    }

    /** Admin/platform-admin reset: clears the passcode so the default OTP applies again. */
    public record PasscodeResetRequest(@NotBlank String mobileNumber) {
    }

    /** {@code credentialMode} is DEFAULT_OTP or PASSCODE — see {@link OtpRequestAccepted}. */
    public record PasscodeStatus(String credentialMode) {
    }
}
