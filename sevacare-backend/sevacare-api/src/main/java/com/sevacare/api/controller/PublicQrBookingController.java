package com.sevacare.api.controller;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.patient.service.AppointmentRequestService;
import com.sevacare.shared.dto.HospitalManagementDtos;
import com.sevacare.tenant.service.HospitalManagementService;

/**
 * Public, phone-scannable booking page reached by scanning a hospital's QR
 * code. Renders a self-contained mobile HTML form (no app install, no JS
 * framework, no CORS) and accepts a plain form POST. The submitted request is
 * routed to the chosen doctor's inbox via {@link AppointmentRequestService}.
 *
 * The QR encodes {@code http://<host>:<port>/api/v1/public/qrcode/{uuid}/book},
 * which any phone camera can open directly.
 */
@RestController
@RequestMapping("/api/v1/public/qrcode")
public class PublicQrBookingController {

    private static final MediaType HTML = MediaType.valueOf("text/html;charset=UTF-8");

    private final HospitalManagementService hospitalManagementService;
    private final AppointmentRequestService appointmentRequestService;

    public PublicQrBookingController(
            HospitalManagementService hospitalManagementService,
            AppointmentRequestService appointmentRequestService
    ) {
        this.hospitalManagementService = hospitalManagementService;
        this.appointmentRequestService = appointmentRequestService;
    }

    // ── Booking form ────────────────────────────────────────────────────────
    @GetMapping(value = "/{qrcodeUuid}/book", produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> bookingForm(@PathVariable String qrcodeUuid) {
        HospitalManagementDtos.QRCodeFormDataResponse data;
        try {
            data = hospitalManagementService.getQRCodeFormData(qrcodeUuid);
        } catch (Exception e) {
            return html(errorPage("Invalid QR Code",
                    "This QR code is not valid or has expired. Please scan a fresh code at the hospital."));
        }

        var doctors = data.availableDoctors();
        if (doctors == null || doctors.isEmpty()) {
            return html(errorPage(data.tenantName(),
                    "No doctors are available for online booking right now. Please try again later."));
        }

        StringBuilder options = new StringBuilder();
        for (var d : doctors) {
            String label = "Dr. " + esc(d.doctorName());
            if (d.specialty() != null && !d.specialty().isBlank()) {
                label += " — " + esc(d.specialty());
            }
            options.append("<option value=\"").append(esc(d.doctorPublicId())).append("\">")
                    .append(label).append("</option>");
        }

        String today = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE);
        return html(formPage(esc(data.tenantName()), options.toString(), today, null));
    }

    // ── Booking submission ──────────────────────────────────────────────────
    @PostMapping(value = "/{qrcodeUuid}/book",
            consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE,
            produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> submitBooking(
            @PathVariable String qrcodeUuid,
            @RequestParam(required = false) String patientName,
            @RequestParam(required = false) String patientMobile,
            @RequestParam(required = false) String patientAge,
            @RequestParam(required = false) String doctorPublicId,
            @RequestParam(required = false) String preferredDate,
            @RequestParam(required = false) String symptoms
    ) {
        var qrcode = hospitalManagementService.getQRCodeByUuid(qrcodeUuid);
        if (qrcode == null) {
            return html(errorPage("Invalid QR Code",
                    "This QR code is not valid or has expired. Please scan a fresh code at the hospital."));
        }
        var data = hospitalManagementService.getQRCodeFormData(qrcodeUuid);

        // Resolve the chosen doctor + specialty from the hospital's real doctors.
        String specialty = null;
        boolean doctorValid = false;
        for (var d : data.availableDoctors()) {
            if (d.doctorPublicId().equals(doctorPublicId)) {
                specialty = d.specialty() == null ? "" : d.specialty();
                doctorValid = true;
                break;
            }
        }

        int age = safeInt(patientAge);
        LocalDate date = safeDate(preferredDate);

        String problem = null;
        if (isBlank(patientName)) problem = "Please enter your name.";
        else if (isBlank(patientMobile) || patientMobile.replaceAll("\\D", "").length() < 10)
            problem = "Please enter a valid 10-digit mobile number.";
        else if (age <= 0) problem = "Please enter a valid age.";
        else if (!doctorValid) problem = "Please choose a doctor from the list.";
        else if (date == null) problem = "Please choose a preferred date.";
        else if (isBlank(symptoms)) problem = "Please describe your symptoms.";

        if (problem != null) {
            // Re-render the form with the error banner and the doctors preserved.
            StringBuilder options = new StringBuilder();
            for (var d : data.availableDoctors()) {
                String label = "Dr. " + esc(d.doctorName());
                if (d.specialty() != null && !d.specialty().isBlank()) label += " — " + esc(d.specialty());
                options.append("<option value=\"").append(esc(d.doctorPublicId())).append("\">")
                        .append(label).append("</option>");
            }
            return html(formPage(esc(data.tenantName()), options.toString(),
                    LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE), problem));
        }

        try {
            String normalizedMobile = patientMobile.replaceAll("\\D", "");
            var req = new HospitalManagementDtos.AppointmentRequestSubmitRequest(
                    patientName.trim(), normalizedMobile, age, symptoms.trim(), doctorPublicId, specialty, date);
            var view = appointmentRequestService.submitAppointmentRequest(
                    qrcode.tenantPublicId(), normalizedMobile, req);
            return html(successPage(esc(data.tenantName()), esc(view.requestPublicId())));
        } catch (Exception e) {
            return html(errorPage("Something went wrong",
                    "We couldn't submit your request. Please scan the QR code and try again."));
        }
    }

    // ── HTML rendering ──────────────────────────────────────────────────────
    private ResponseEntity<String> html(String body) {
        return ResponseEntity.ok().contentType(HTML).body(body);
    }

    private String formPage(String hospital, String doctorOptions, String today, String error) {
        String banner = error == null ? "" :
                "<div class=\"err\">" + esc(error) + "</div>";
        return SHELL
                .replace("{{TITLE}}", "Book Appointment — " + hospital)
                .replace("{{BODY}}",
                    "<div class=\"hero\">"
                  + "  <span class=\"badge\">SevaCare</span>"
                  + "  <h1>" + hospital + "</h1>"
                  + "  <p>Book your appointment in under a minute</p>"
                  + "</div>"
                  + "<form class=\"card\" method=\"POST\" action=\"\" accept-charset=\"UTF-8\">"
                  + banner
                  + "  <label>Full Name <span class=\"req\">*</span></label>"
                  + "  <input name=\"patientName\" required maxlength=\"80\" placeholder=\"Your full name\">"
                  + "  <label>Mobile Number <span class=\"req\">*</span></label>"
                  + "  <input name=\"patientMobile\" required type=\"tel\" inputmode=\"numeric\" pattern=\"[0-9]{10}\" maxlength=\"10\" placeholder=\"10-digit mobile\">"
                  + "  <label>Age <span class=\"req\">*</span></label>"
                  + "  <input name=\"patientAge\" required type=\"number\" min=\"1\" max=\"120\" placeholder=\"Your age\">"
                  + "  <label>Select Doctor <span class=\"req\">*</span></label>"
                  + "  <select name=\"doctorPublicId\" required>"
                  + "    <option value=\"\" disabled selected>Choose a doctor</option>"
                  + doctorOptions
                  + "  </select>"
                  + "  <label>Preferred Date <span class=\"req\">*</span></label>"
                  + "  <input name=\"preferredDate\" required type=\"date\" min=\"" + today + "\">"
                  + "  <label>Symptoms / Reason for Visit <span class=\"req\">*</span></label>"
                  + "  <textarea name=\"symptoms\" required maxlength=\"400\" placeholder=\"Briefly describe your symptoms\"></textarea>"
                  + "  <button class=\"btn\" type=\"submit\">Request Appointment</button>"
                  + "  <p class=\"foot\">Your request goes straight to the doctor, who will confirm your slot.</p>"
                  + "</form>");
    }

    private String successPage(String hospital, String requestId) {
        return SHELL
                .replace("{{TITLE}}", "Request Submitted — " + hospital)
                .replace("{{BODY}}",
                    "<div class=\"hero\">"
                  + "  <span class=\"badge\">SevaCare</span>"
                  + "  <h1>" + hospital + "</h1>"
                  + "</div>"
                  + "<div class=\"card center\">"
                  + "  <div class=\"tick\">&#10003;</div>"
                  + "  <h2>Request Submitted!</h2>"
                  + "  <p>Your appointment request has been sent to the doctor. They will review it and confirm your slot. You'll be contacted on the mobile number you provided.</p>"
                  + "  <div class=\"pill\">Request ID: " + requestId + "</div>"
                  + "  <a class=\"btn ghost\" href=\"\">Book another appointment</a>"
                  + "</div>");
    }

    private String errorPage(String title, String message) {
        return SHELL
                .replace("{{TITLE}}", esc(title))
                .replace("{{BODY}}",
                    "<div class=\"hero\">"
                  + "  <span class=\"badge\">SevaCare</span>"
                  + "  <h1>" + esc(title) + "</h1>"
                  + "</div>"
                  + "<div class=\"card center\">"
                  + "  <div class=\"tick warn\">!</div>"
                  + "  <p>" + esc(message) + "</p>"
                  + "</div>");
    }

    // Shared page shell with inline CSS (mobile-first, SevaCare purple theme).
    private static final String SHELL = """
        <!DOCTYPE html>
        <html lang="en"><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <title>{{TITLE}}</title>
        <style>
          *{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
          body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#F4F2FB;color:#1F1B2E}
          .wrap{max-width:480px;margin:0 auto;min-height:100vh}
          .hero{background:linear-gradient(135deg,#6D5AE6,#8B7BF0);color:#fff;padding:26px 22px 32px;border-radius:0 0 26px 26px}
          .badge{display:inline-block;background:rgba(255,255,255,.20);padding:5px 13px;border-radius:999px;font-size:12px;font-weight:700;letter-spacing:.5px}
          .hero h1{margin:14px 0 4px;font-size:22px;font-weight:800;line-height:1.2}
          .hero p{margin:0;opacity:.9;font-size:14px}
          .card{background:#fff;margin:-16px 16px 16px;border-radius:20px;padding:22px;box-shadow:0 10px 34px rgba(80,60,160,.12)}
          .card.center{text-align:center;margin-top:24px}
          label{display:block;font-size:13px;font-weight:700;margin:15px 0 6px;color:#4A4460}
          input,select,textarea{width:100%;padding:13px 14px;border:1.5px solid #E4E0F0;border-radius:12px;font-size:16px;background:#FBFAFF;color:#1F1B2E;outline:none;font-family:inherit}
          input:focus,select:focus,textarea:focus{border-color:#6D5AE6;background:#fff}
          textarea{resize:vertical;min-height:80px}
          .btn{display:block;text-align:center;width:100%;margin-top:22px;padding:15px;border:none;border-radius:14px;background:linear-gradient(135deg,#6D5AE6,#8B7BF0);color:#fff;font-size:16px;font-weight:800;cursor:pointer;text-decoration:none}
          .btn:active{opacity:.92}
          .btn.ghost{background:#F0EDFB;color:#6D5AE6;margin-top:18px}
          .foot{text-align:center;font-size:12px;color:#8A83A0;margin:16px 0 0}
          .req{color:#E5484D}
          .err{background:#FDECEC;color:#C13515;border:1px solid #F6C6C6;border-radius:12px;padding:11px 14px;font-size:14px;font-weight:600;margin-bottom:4px}
          .tick{width:72px;height:72px;border-radius:50%;background:#E7F8F0;color:#12A150;font-size:38px;font-weight:800;line-height:72px;margin:6px auto 14px}
          .tick.warn{background:#FDECEC;color:#E5484D}
          .card.center h2{margin:0 0 8px;font-size:20px}
          .card.center p{color:#6A6480;font-size:15px;line-height:1.5;margin:0}
          .pill{display:inline-block;margin-top:16px;background:#F0EDFB;color:#6D5AE6;padding:8px 16px;border-radius:999px;font-size:13px;font-weight:700}
        </style></head>
        <body><div class="wrap">{{BODY}}</div></body></html>
        """;

    // ── Helpers ─────────────────────────────────────────────────────────────
    private static boolean isBlank(String s) { return s == null || s.trim().isEmpty(); }

    private static int safeInt(String s) {
        try { return Integer.parseInt(s.trim()); } catch (Exception e) { return 0; }
    }

    private static LocalDate safeDate(String s) {
        try { return LocalDate.parse(s.trim()); } catch (Exception e) { return null; }
    }

    /** Minimal HTML escaping for interpolated text (names, specialties, messages). */
    private static String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }
}
