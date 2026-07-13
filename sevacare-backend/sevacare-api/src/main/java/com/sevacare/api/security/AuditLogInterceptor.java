package com.sevacare.api.security;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.http.HttpMethod;
import org.springframework.lang.NonNull;
import org.springframework.lang.Nullable;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import com.sevacare.api.service.AuditService;
import com.sevacare.shared.security.TokenClaims;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * The PHI audit trail: every successful read or write of patient data leaves
 * an append-only {@code audit_log} row answering "who touched this record,
 * and when" — the question DPDP (and any incident investigation) asks first.
 *
 * <p>An interceptor rather than a servlet filter on purpose:
 * {@link #afterCompletion} runs inside the security filter chain, so the
 * authentication (and its {@link TokenClaims}) is still on the thread, and the
 * response status is final — only requests that actually succeeded are logged
 * as data access. Routes are matched here, in one place, instead of sprinkling
 * an {@code audit(...)} call through a hundred controller methods that the
 * hundred-and-first would forget.
 *
 * <p>Polling reads (the live queue board refreshes every 20 s) are recorded
 * like any other: a read is a read, whoever's screen initiated it.
 */
@Component
public class AuditLogInterceptor implements HandlerInterceptor {

    /**
     * What counts as PHI, matched against the request path; first match wins.
     * A route not listed here is not audited — when a new controller exposes
     * patient data, its path belongs in this table.
     */
    private static final List<Rule> RULES = List.of(
            // Patient self-service: /patients/{tenant}/{patientId}/...
            new Rule(Pattern.compile("^/api/v1/patients/[^/]+/([^/]+)"), "PATIENT", false),
            // Patient registration (HospitalManagementController)
            new Rule(Pattern.compile("^/api/v1/patients$"), "PATIENT", false),
            // Admin: patient list, patient/doctor records, appointment book
            new Rule(Pattern.compile("^/api/v1/admin/[^/]+/patients$"), "PATIENT", false),
            new Rule(Pattern.compile("^/api/v1/admin/[^/]+/records(?:/([^/]+))?"), "PATIENT_RECORD", false),
            new Rule(Pattern.compile("^/api/v1/admin/[^/]+/appointments(?:/([^/]+))?"), "APPOINTMENT", false),
            // Doctor: their patients, queue, prescriptions, appointment updates
            new Rule(Pattern.compile("^/api/v1/doctors/[^/]+/[^/]+/patients(?:/([^/]+))?"), "PATIENT", false),
            new Rule(Pattern.compile("^/api/v1/doctors/[^/]+/[^/]+/queue"), "QUEUE", false),
            new Rule(Pattern.compile("^/api/v1/doctors/[^/]+/[^/]+/prescriptions"), "PRESCRIPTION", false),
            new Rule(Pattern.compile("^/api/v1/doctors/[^/]+/[^/]+/appointments/([^/]+)"), "APPOINTMENT", false),
            new Rule(Pattern.compile("^/api/v1/doctors/[^/]+/[^/]+/dashboard"), "QUEUE", false),
            // Prescription detail / PDF download
            new Rule(Pattern.compile("^/api/v1/prescriptions/[^/]+/([^/]+)"), "PRESCRIPTION", false),
            // Pharmacy: sales, khata and returns carry customer names + mobiles
            new Rule(Pattern.compile("^/api/v1/pharmacy/[^/]+/(?:sales|credit|returns)(?:/([^/]+))?"), "SALE", false),
            // Anonymous QR booking WRITES patient data; the GET only serves the form
            new Rule(Pattern.compile("^/api/v1/public/qrcode/[^/]+/book$"), "APPOINTMENT", true)
    );

    private record Rule(Pattern pattern, String subjectType, boolean writeOnly) {
    }

    private final AuditService auditService;

    public AuditLogInterceptor(AuditService auditService) {
        this.auditService = auditService;
    }

    @Override
    public void afterCompletion(@NonNull HttpServletRequest request, @NonNull HttpServletResponse response,
                                @NonNull Object handler, @Nullable Exception ex) {
        int status = response.getStatus();
        if (status < 200 || status >= 300) {
            return; // A refused request read nothing.
        }
        String path = request.getRequestURI();
        String method = request.getMethod();
        for (Rule rule : RULES) {
            Matcher matcher = rule.pattern().matcher(path);
            if (!matcher.find()) {
                continue;
            }
            if (rule.writeOnly() && HttpMethod.GET.matches(method)) {
                return;
            }
            String subjectId = matcher.groupCount() >= 1 ? matcher.group(1) : null;
            TokenClaims claims = claimsOnThread();
            auditService.record(
                    claims != null ? claims.tenantPublicId() : null,
                    claims != null ? claims.role() : "PUBLIC",
                    claims != null ? claims.subjectPublicId() : null,
                    rule.subjectType() + "_" + verb(method),
                    rule.subjectType(),
                    subjectId,
                    path,
                    clientIp(request));
            return;
        }
    }

    /** The actor as the signed token stated it — never anything the client typed. */
    private static TokenClaims claimsOnThread() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getDetails() instanceof TokenClaims claims) {
            return claims;
        }
        return null;
    }

    private static String verb(String method) {
        return switch (method) {
            case "GET" -> "READ";
            case "POST" -> "CREATE";
            case "PUT", "PATCH" -> "UPDATE";
            case "DELETE" -> "DELETE";
            default -> method;
        };
    }

    private static String clientIp(HttpServletRequest request) {
        // Behind Cloud Run the client is the first entry of X-Forwarded-For;
        // locally there is no such header and the remote address is the truth.
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
