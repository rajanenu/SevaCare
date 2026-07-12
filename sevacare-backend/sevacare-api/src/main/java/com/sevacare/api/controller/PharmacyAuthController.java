package com.sevacare.api.controller;

import java.util.List;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.api.service.PharmacyAuthService;
import com.sevacare.shared.dto.AuthDtos;
import com.sevacare.shared.dto.ContractResponse;

import jakarta.validation.Valid;

/**
 * The standalone medical store's front door. Public (sits under the permit-all
 * {@code /api/v1/auth/**}) because a shop owner has no session yet — the whole
 * point is to get them one without first choosing a hospital.
 *
 * <p>Two steps: {@code request-otp} resolves which store(s) the mobile runs and
 * returns them; {@code verify} checks the OTP against the chosen store and mints
 * a counter session. Separate from {@link AuthController} on purpose — the shop
 * login must never depend on hospital search.
 */
@RestController
@RequestMapping("/api/v1/auth/pharmacy")
public class PharmacyAuthController {

    private final PharmacyAuthService pharmacyAuthService;

    public PharmacyAuthController(PharmacyAuthService pharmacyAuthService) {
        this.pharmacyAuthService = pharmacyAuthService;
    }

    @PostMapping("/request-otp")
    public ContractResponse<AuthDtos.PharmacyOtpResponse> requestOtp(
            @Valid @RequestBody AuthDtos.PharmacyOtpRequest request) {
        List<AuthDtos.PharmacyLoginOption> shops = pharmacyAuthService.shopsForMobile(request.mobileNumber());
        if (shops.isEmpty()) {
            throw new IllegalArgumentException(
                    "This mobile number isn't registered to any medical store. "
                    + "Ask your store owner to add you, or onboard your store first.");
        }
        // OTP delivery would fire here per store; locally every number accepts the
        // platform default. Never echo the OTP back — the client just shows the step.
        return ContractResponse.of(new AuthDtos.PharmacyOtpResponse(shops, null));
    }

    @PostMapping("/verify")
    public ContractResponse<AuthDtos.AuthenticatedSession> verify(
            @Valid @RequestBody AuthDtos.PharmacyVerifyRequest request) {
        return ContractResponse.of(pharmacyAuthService.verify(
                request.mobileNumber(), request.otp(), request.tenantPublicId()));
    }
}
