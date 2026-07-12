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
    public record PharmacyOtpResponse(List<PharmacyLoginOption> shops, String otpHint) {
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

    public record OtpRequestAccepted(String tenantPublicId, String role, String mobileNumber, String otpHint) {
    }

    public record OtpVerifyRequest(
            @NotBlank String tenantPublicId,
            @NotBlank String role,
            @NotBlank String mobileNumber,
            @NotBlank String otp
    ) {
    }

    public record AuthenticatedSession(String tenantPublicId, String role, String subjectPublicId, String token, boolean isGeneric, String subjectName, String userType) {
    }
}
