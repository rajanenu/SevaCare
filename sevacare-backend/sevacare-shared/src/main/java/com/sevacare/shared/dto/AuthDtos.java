package com.sevacare.shared.dto;

import jakarta.validation.constraints.NotBlank;

public final class AuthDtos {

    private AuthDtos() {
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

    public record AuthenticatedSession(String tenantPublicId, String role, String subjectPublicId, String token, boolean isGeneric) {
    }
}
