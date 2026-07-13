package com.sevacare.api.controller;

import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.api.service.AccountMobileResolver;
import com.sevacare.api.service.PasscodeService;
import com.sevacare.shared.dto.AuthDtos;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.security.TokenClaims;

import jakarta.validation.Valid;

/**
 * The signed-in user's own account. Deliberately <em>not</em> under the
 * permit-all {@code /api/v1/auth/**}: changing a passcode requires a live
 * session, and the mobile number it applies to is resolved from the token's
 * claims — never taken from the request — so a caller can only ever change
 * their own code.
 */
@RestController
@RequestMapping("/api/v1/account")
public class AccountController {

    private final AccountMobileResolver accountMobileResolver;
    private final PasscodeService passcodeService;

    public AccountController(AccountMobileResolver accountMobileResolver, PasscodeService passcodeService) {
        this.accountMobileResolver = accountMobileResolver;
        this.passcodeService = passcodeService;
    }

    /** Whether this session's mobile still uses the default OTP or set a passcode. */
    @GetMapping("/passcode")
    public ContractResponse<AuthDtos.PasscodeStatus> passcodeStatus(Authentication authentication) {
        String mobile = ownMobile(authentication);
        return ContractResponse.of(new AuthDtos.PasscodeStatus(passcodeService.mode(mobile).name()));
    }

    /**
     * Set or change the caller's own passcode. The current credential (default
     * OTP, or the existing passcode) must verify first, with the login lockout
     * applying — so this is no cheaper to brute-force than the login itself.
     */
    @PostMapping("/passcode")
    public ContractResponse<AuthDtos.PasscodeStatus> changePasscode(
            Authentication authentication,
            @Valid @RequestBody AuthDtos.PasscodeChangeRequest request) {
        TokenClaims claims = claims(authentication);
        String mobile = accountMobileResolver.mobileFor(claims);
        if (mobile == null || mobile.isBlank()) {
            throw new IllegalArgumentException("No mobile number is on file for this account.");
        }
        passcodeService.setPasscode(mobile, request.currentCode(), request.newPasscode(),
                "self:" + claims.subjectPublicId());
        return ContractResponse.of(new AuthDtos.PasscodeStatus(PasscodeService.CredentialMode.PASSCODE.name()));
    }

    private String ownMobile(Authentication authentication) {
        String mobile = accountMobileResolver.mobileFor(claims(authentication));
        if (mobile == null || mobile.isBlank()) {
            throw new IllegalArgumentException("No mobile number is on file for this account.");
        }
        return mobile;
    }

    private static TokenClaims claims(Authentication authentication) {
        if (authentication == null || !(authentication.getDetails() instanceof TokenClaims claims)) {
            throw new AccessDeniedException("Session required");
        }
        return claims;
    }
}
