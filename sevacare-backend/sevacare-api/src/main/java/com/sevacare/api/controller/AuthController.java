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

        // Fail fast: validate registered mobile for doctor and admin roles before sending OTP
        if ("doctor".equals(request.role()) || "admin".equals(request.role())) {
            String schema = tenantRegistryService.resolveTenantSchema(request.tenantPublicId());
            try {
                TenantContext.set(request.tenantPublicId(), schema);
                if ("doctor".equals(request.role())) {
                    doctorDomainService.findDoctorForLogin(request.tenantPublicId(), request.mobileNumber());
                } else {
                    adminDomainService.findAdminForLogin(request.tenantPublicId(), request.mobileNumber());
                }
            } finally {
                TenantContext.clear();
            }
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
            String subjectName = platformAdminService.findPlatformAdminNameByMobile(request.mobileNumber());
            String token = tokenService.issue(new TokenClaims(PlatformAdminService.PLATFORM_TENANT_PUBLIC_ID, request.role(), subjectPublicId));
            return ContractResponse.of(new AuthDtos.AuthenticatedSession(PlatformAdminService.PLATFORM_TENANT_PUBLIC_ID, request.role(), subjectPublicId, token, false, subjectName));
        }

        if (!LOCAL_OTP.equals(request.otp())) {
            throw new IllegalArgumentException("Invalid OTP");
        }

        String schema = tenantRegistryService.resolveTenantSchema(request.tenantPublicId());
        try {
            TenantContext.set(request.tenantPublicId(), schema);
            record SubjectInfo(String publicId, String name) {}
            SubjectInfo subject = switch (request.role()) {
                case "patient" -> {
                    var p = patientDomainService.findOrCreatePatientForLogin(request.tenantPublicId(), request.mobileNumber());
                    yield new SubjectInfo(p.getPatientPublicId(), p.getFullName() != null ? p.getFullName() : "Patient");
                }
                case "doctor" -> {
                    var d = doctorDomainService.findDoctorForLogin(request.tenantPublicId(), request.mobileNumber());
                    yield new SubjectInfo(d.getDoctorPublicId(), d.getFullName() != null ? d.getFullName() : "Doctor");
                }
                case "admin" -> {
                    var a = adminDomainService.findAdminForLogin(request.tenantPublicId(), request.mobileNumber());
                    yield new SubjectInfo(a.getAdminPublicId(), a.getFullName() != null ? a.getFullName() : "Admin");
                }
                default -> throw new IllegalArgumentException("Unsupported role");
            };
            boolean isGenericAdmin = "admin".equals(request.role())
                    && AdminDomainService.GENERIC_ADMIN_MOBILE.equals(request.mobileNumber());
            String token = tokenService.issue(new TokenClaims(request.tenantPublicId(), request.role(), subject.publicId()));
            return ContractResponse.of(new AuthDtos.AuthenticatedSession(request.tenantPublicId(), request.role(), subject.publicId(), token, isGenericAdmin, subject.name()));
        } finally {
            TenantContext.clear();
        }
    }
}
