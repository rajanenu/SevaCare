package com.sevacare.api.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.patient.service.AppointmentRequestService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.HospitalManagementDtos;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.service.HospitalManagementService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class HospitalManagementController {

    private final HospitalManagementService hospitalManagementService;
    private final AppointmentRequestService appointmentRequestService;

    public HospitalManagementController(
            HospitalManagementService hospitalManagementService,
            AppointmentRequestService appointmentRequestService
    ) {
        this.hospitalManagementService = hospitalManagementService;
        this.appointmentRequestService = appointmentRequestService;
    }

    // ==================== Hospital Admin Enrollment ====================
    @PostMapping("/admin/{tenantPublicId}/hospital-admins/enroll")
    @PreAuthorize("hasRole('PLATFORM_ADMIN') or hasRole('ADMIN')")
    public ContractResponse<HospitalManagementDtos.HospitalAdminEnrollView> enrollHospitalAdmin(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody HospitalManagementDtos.HospitalAdminEnrollRequest req
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(hospitalManagementService.enrollHospitalAdmin(tenantPublicId, req));
    }

    @GetMapping("/admin/{tenantPublicId}/hospital-admins")
    @PreAuthorize("hasRole('PLATFORM_ADMIN') or hasRole('ADMIN')")
    public ContractResponse<HospitalManagementDtos.HospitalAdminEnrollCollection> listHospitalAdmins(
            @PathVariable String tenantPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(hospitalManagementService.listHospitalAdmins(tenantPublicId));
    }

    // ==================== Doctor Enrollment ====================
    @PostMapping("/admin/{tenantPublicId}/doctors/enroll")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<HospitalManagementDtos.DoctorEnrollView> enrollDoctor(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody HospitalManagementDtos.DoctorEnrollRequest req
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(hospitalManagementService.enrollDoctor(tenantPublicId, req));
    }

    @GetMapping("/admin/{tenantPublicId}/doctors")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<HospitalManagementDtos.DoctorEnrollCollection> listDoctors(
            @PathVariable String tenantPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(hospitalManagementService.listDoctors(tenantPublicId));
    }

    // ==================== QR Code Management ====================
    @PostMapping("/admin/{tenantPublicId}/qrcode/generate")
    @PreAuthorize("hasRole('ADMIN')")
    public ContractResponse<HospitalManagementDtos.HospitalQRCodeGenerateResponse> generateQRCode(
            @PathVariable String tenantPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(hospitalManagementService.generateOrGetQRCode(tenantPublicId));
    }

    // ==================== QR Code Pre-filled Form Data (PUBLIC) ====================
    @GetMapping("/public/qrcode/{qrcodeUuid}/form-data")
    public ContractResponse<HospitalManagementDtos.QRCodeFormDataResponse> getQRCodeFormData(
            @PathVariable String qrcodeUuid
    ) {
        return ContractResponse.of(hospitalManagementService.getQRCodeFormData(qrcodeUuid));
    }

    // ==================== Appointment Request Management ====================
    @PostMapping("/public/qrcode/{qrcodeUuid}/appointment-request")
    public ContractResponse<HospitalManagementDtos.AppointmentRequestView> submitAppointmentRequest(
            @PathVariable String qrcodeUuid,
            @Valid @RequestBody HospitalManagementDtos.AppointmentRequestSubmitRequest req
    ) {
        var qrcode = hospitalManagementService.getQRCodeByUuid(qrcodeUuid);
        if (qrcode == null) {
            throw new IllegalArgumentException("QR Code not found");
        }

        // For now, using a placeholder mobile; in production, this would come from authenticated session
        String patientMobile = req.patientName().replaceFirst("\\s+.*", "").toLowerCase();
        return ContractResponse.of(
            appointmentRequestService.submitAppointmentRequest(qrcode.tenantPublicId(), patientMobile, req)
        );
    }

    @GetMapping("/doctors/{tenantPublicId}/{doctorPublicId}/appointment-requests")
    @PreAuthorize("hasRole('DOCTOR')")
    public ContractResponse<HospitalManagementDtos.AppointmentRequestCollection> getDoctorAppointmentRequests(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(
            appointmentRequestService.getDoctorRequests(tenantPublicId, doctorPublicId)
        );
    }

    @PostMapping("/doctors/{tenantPublicId}/{doctorPublicId}/appointment-requests/{requestPublicId}/confirm")
    @PreAuthorize("hasRole('DOCTOR')")
    public ContractResponse<HospitalManagementDtos.AppointmentRequestConfirmResponse> confirmAppointmentRequest(
            @PathVariable String tenantPublicId,
            @PathVariable String doctorPublicId,
            @PathVariable String requestPublicId,
            @Valid @RequestBody HospitalManagementDtos.AppointmentRequestConfirmRequest confirmReq
    ) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
        return ContractResponse.of(
            appointmentRequestService.confirmAndCreateAppointment(tenantPublicId, doctorPublicId, requestPublicId, confirmReq)
        );
    }
}
