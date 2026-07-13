package com.sevacare.api.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.admin.service.AdminDomainService;
import com.sevacare.api.security.RefreshTokenService;
import com.sevacare.api.security.TokenRevocationService;
import com.sevacare.api.security.TokenService;
import com.sevacare.api.service.PasscodeService;
import com.sevacare.doctor.service.DoctorDomainService;
import com.sevacare.patient.service.PatientDomainService;
import com.sevacare.shared.dto.AuthDtos;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.security.TokenClaims;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.service.PlatformAdminService;
import com.sevacare.tenant.service.TenantRegistryService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final TenantRegistryService tenantRegistryService;
    private final PatientDomainService patientDomainService;
    private final DoctorDomainService doctorDomainService;
    private final AdminDomainService adminDomainService;
    private final PlatformAdminService platformAdminService;
    private final TokenService tokenService;
    private final RefreshTokenService refreshTokenService;
    private final TokenRevocationService tokenRevocationService;
    private final PasscodeService passcodeService;

    public AuthController(
            TenantRegistryService tenantRegistryService,
            PatientDomainService patientDomainService,
            DoctorDomainService doctorDomainService,
            AdminDomainService adminDomainService,
            PlatformAdminService platformAdminService,
            TokenService tokenService,
            RefreshTokenService refreshTokenService,
            TokenRevocationService tokenRevocationService,
            PasscodeService passcodeService
    ) {
        this.tenantRegistryService = tenantRegistryService;
        this.patientDomainService = patientDomainService;
        this.doctorDomainService = doctorDomainService;
        this.adminDomainService = adminDomainService;
        this.platformAdminService = platformAdminService;
        this.tokenService = tokenService;
        this.refreshTokenService = refreshTokenService;
        this.tokenRevocationService = tokenRevocationService;
        this.passcodeService = passcodeService;
    }

    @PostMapping("/otp/request")
    public ContractResponse<AuthDtos.OtpRequestAccepted> requestOtp(@Valid @RequestBody AuthDtos.OtpRequest request) {
        if ("platform_admin".equals(request.role())) {
            if (!platformAdminService.hasActivePlatformAdminByMobile(request.mobileNumber())) {
                throw new IllegalArgumentException("Unauthorized platform admin mobile number");
            }
            return ContractResponse.of(new AuthDtos.OtpRequestAccepted(
                    request.tenantPublicId(),
                    request.role(),
                    request.mobileNumber(),
                    null,
                    passcodeService.mode(request.mobileNumber()).name()
            ));
        }

        if (!"platform_admin".equals(request.role())) {
            tenantRegistryService.mustFindActiveTenant(request.tenantPublicId());
        }

        // Fail fast: validate registered mobile for doctor, admin, and staff roles before sending OTP
        if ("doctor".equals(request.role()) || "admin".equals(request.role()) || "staff".equals(request.role())) {
            String schema = tenantRegistryService.resolveTenantSchema(request.tenantPublicId());
            try {
                TenantContext.set(request.tenantPublicId(), schema);
                if ("doctor".equals(request.role())) {
                    doctorDomainService.findDoctorForLogin(request.tenantPublicId(), request.mobileNumber());
                } else if ("admin".equals(request.role())) {
                    adminDomainService.findAdminForLogin(request.tenantPublicId(), request.mobileNumber());
                } else {
                    // 'staff' role: find admin_user record and enforce user_type = STAFF
                    var a = adminDomainService.findAdminForLogin(request.tenantPublicId(), request.mobileNumber());
                    if (!"STAFF".equals(a.getUserType())) {
                        throw new IllegalArgumentException(
                                "This mobile number is not registered as IP-Staff for this hospital. Please contact your hospital admin.");
                    }
                }
            } finally {
                TenantContext.clear();
            }
        }

        return ContractResponse.of(new AuthDtos.OtpRequestAccepted(
                request.tenantPublicId(),
                request.role(),
                request.mobileNumber(),
                null,
                passcodeService.mode(request.mobileNumber()).name()
        ));
    }

    @PostMapping("/otp/verify")
    public ContractResponse<AuthDtos.AuthenticatedSession> verifyOtp(@Valid @RequestBody AuthDtos.OtpVerifyRequest request) {
        if ("platform_admin".equals(request.role())) {
            if (!platformAdminService.hasActivePlatformAdminByMobile(request.mobileNumber())) {
                throw new IllegalArgumentException("Unauthorized platform admin mobile number");
            }
            passcodeService.verify(request.mobileNumber(), request.otp());
            String subjectPublicId = platformAdminService.findPlatformAdminPublicIdByMobile(request.mobileNumber());
            String subjectName = platformAdminService.findPlatformAdminNameByMobile(request.mobileNumber());
            TokenClaims platformClaims = new TokenClaims(PlatformAdminService.PLATFORM_TENANT_PUBLIC_ID, request.role(), subjectPublicId);
            String token = tokenService.issue(platformClaims);
            String refreshToken = refreshTokenService.issue(platformClaims);
            return ContractResponse.of(new AuthDtos.AuthenticatedSession(PlatformAdminService.PLATFORM_TENANT_PUBLIC_ID, request.role(), subjectPublicId, token, false, subjectName, "ADMIN", refreshToken));
        }

        passcodeService.verify(request.mobileNumber(), request.otp());

        String schema = tenantRegistryService.resolveTenantSchema(request.tenantPublicId());
        try {
            TenantContext.set(request.tenantPublicId(), schema);
            record SubjectInfo(String publicId, String name, String userType) {}
            SubjectInfo subject = switch (request.role()) {
                case "patient" -> {
                    var p = patientDomainService.findOrCreatePatientForLogin(request.tenantPublicId(), request.mobileNumber());
                    yield new SubjectInfo(p.getPatientPublicId(), p.getFullName() != null ? p.getFullName() : "Patient", "PATIENT");
                }
                case "doctor" -> {
                    var d = doctorDomainService.findDoctorForLogin(request.tenantPublicId(), request.mobileNumber());
                    yield new SubjectInfo(d.getDoctorPublicId(), d.getFullName() != null ? d.getFullName() : "Doctor", "DOCTOR");
                }
                case "admin" -> {
                    var a = adminDomainService.findAdminForLogin(request.tenantPublicId(), request.mobileNumber());
                    yield new SubjectInfo(a.getAdminPublicId(), a.getFullName() != null ? a.getFullName() : "Admin", a.getUserType());
                }
                case "staff" -> {
                    // IP-Staff: reuse findAdminForLogin + enforce user_type = STAFF
                    var a = adminDomainService.findAdminForLogin(request.tenantPublicId(), request.mobileNumber());
                    if (!"STAFF".equals(a.getUserType())) {
                        throw new IllegalArgumentException(
                                "This mobile number is not registered as IP-Staff for this hospital. Please contact your hospital admin.");
                    }
                    yield new SubjectInfo(a.getAdminPublicId(), a.getFullName() != null ? a.getFullName() : "IP-Staff", a.getUserType());
                }
                default -> throw new IllegalArgumentException("Unsupported role");
            };
            // Staff logs in via 'staff' role request but carries 'admin' JWT role so security gates work
            String jwtRole = "staff".equals(request.role()) ? "admin" : request.role();
            TokenClaims claims = new TokenClaims(request.tenantPublicId(), jwtRole, subject.publicId());
            String token = tokenService.issue(claims);
            String refreshToken = refreshTokenService.issue(claims);
            return ContractResponse.of(new AuthDtos.AuthenticatedSession(request.tenantPublicId(), jwtRole, subject.publicId(), token, false, subject.name(), subject.userType(), refreshToken));
        } finally {
            TenantContext.clear();
        }
    }

    /**
     * Exchanges a live refresh token for a fresh access JWT. The refresh token
     * rotates on every use, so a replayed (stolen) one is refused and the
     * legitimate session keeps moving. 400 here means "sign in again".
     */
    @PostMapping("/refresh")
    public ContractResponse<AuthDtos.RefreshedSession> refresh(@Valid @RequestBody AuthDtos.RefreshRequest request) {
        RefreshTokenService.Rotation rotation = refreshTokenService.rotate(request.refreshToken());
        String token = tokenService.issue(rotation.claims());
        return ContractResponse.of(new AuthDtos.RefreshedSession(token, rotation.newRefreshToken()));
    }

    /**
     * Real logout: the refresh token is revoked server-side and, if a bearer
     * token accompanies the call, its {@code jti} is revoked too — so neither
     * credential survives past this request. Deliberately never fails: logout
     * must work even with a dead session.
     */
    @PostMapping("/logout")
    public ContractResponse<Boolean> logout(
            @RequestBody(required = false) AuthDtos.LogoutRequest request,
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        if (request != null) {
            refreshTokenService.revoke(request.refreshToken());
        }
        if (authorization != null && authorization.startsWith("Bearer ")) {
            try {
                TokenService.ParsedToken parsed = tokenService.parseDetailed(authorization.substring(7));
                tokenRevocationService.revoke(parsed.jti(), parsed.expiresAt());
            } catch (RuntimeException ignored) {
                // An unparseable/expired access token needs no revoking.
            }
        }
        return ContractResponse.of(Boolean.TRUE);
    }
}
