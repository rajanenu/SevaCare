package com.sevacare.api.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.admin.service.AdminDomainService;
import com.sevacare.api.security.TokenService;
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

    private static final String LOCAL_OTP = "0000";

    private final TenantRegistryService tenantRegistryService;
    private final PatientDomainService patientDomainService;
    private final DoctorDomainService doctorDomainService;
    private final AdminDomainService adminDomainService;
    private final PlatformAdminService platformAdminService;
    private final TokenService tokenService;

    public AuthController(
            TenantRegistryService tenantRegistryService,
            PatientDomainService patientDomainService,
            DoctorDomainService doctorDomainService,
            AdminDomainService adminDomainService,
            PlatformAdminService platformAdminService,
            TokenService tokenService
    ) {
        this.tenantRegistryService = tenantRegistryService;
        this.patientDomainService = patientDomainService;
        this.doctorDomainService = doctorDomainService;
        this.adminDomainService = adminDomainService;
        this.platformAdminService = platformAdminService;
        this.tokenService = tokenService;
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
                    LOCAL_OTP
            ));
        }

        if (!"platform_admin".equals(request.role())) {
            tenantRegistryService.mustFindActiveTenant(request.tenantPublicId());
        }
        return ContractResponse.of(new AuthDtos.OtpRequestAccepted(
                request.tenantPublicId(),
                request.role(),
                request.mobileNumber(),
                LOCAL_OTP
        ));
    }

    @PostMapping("/otp/verify")
    public ContractResponse<AuthDtos.AuthenticatedSession> verifyOtp(@Valid @RequestBody AuthDtos.OtpVerifyRequest request) {
        if ("platform_admin".equals(request.role())) {
            if (!platformAdminService.hasActivePlatformAdminByMobile(request.mobileNumber())) {
                throw new IllegalArgumentException("Unauthorized platform admin mobile number");
            }
            if (!LOCAL_OTP.equals(request.otp())) {
                throw new IllegalArgumentException("Invalid OTP");
            }
            String subjectPublicId = platformAdminService.findPlatformAdminPublicIdByMobile(request.mobileNumber());
            String token = tokenService.issue(new TokenClaims(PlatformAdminService.PLATFORM_TENANT_PUBLIC_ID, request.role(), subjectPublicId));
            return ContractResponse.of(new AuthDtos.AuthenticatedSession(PlatformAdminService.PLATFORM_TENANT_PUBLIC_ID, request.role(), subjectPublicId, token, false));
        }

        if (!LOCAL_OTP.equals(request.otp())) {
            throw new IllegalArgumentException("Invalid OTP");
        }

        String schema = tenantRegistryService.resolveTenantSchema(request.tenantPublicId());
        try {
            TenantContext.set(request.tenantPublicId(), schema);
            String subjectPublicId = switch (request.role()) {
                case "patient" -> patientDomainService.findOrCreatePatientForLogin(request.tenantPublicId(), request.mobileNumber()).getPatientPublicId();
                case "doctor" -> doctorDomainService.findFirstDoctorForTenant(request.tenantPublicId()).getDoctorPublicId();
                case "admin" -> adminDomainService.findAdminForLogin(request.tenantPublicId(), request.mobileNumber()).getAdminPublicId();
                default -> throw new IllegalArgumentException("Unsupported role");
            };
            boolean isGenericAdmin = "admin".equals(request.role())
                    && AdminDomainService.GENERIC_ADMIN_MOBILE.equals(request.mobileNumber());
            String token = tokenService.issue(new TokenClaims(request.tenantPublicId(), request.role(), subjectPublicId));
            return ContractResponse.of(new AuthDtos.AuthenticatedSession(request.tenantPublicId(), request.role(), subjectPublicId, token, isGenericAdmin));
        } finally {
            TenantContext.clear();
        }
    }
}
