package com.sevacare.api.controller;

import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(ApiExceptionHandler::formatFieldError)
                .toList();

        log.warn("api_validation_failed details={}", details);

        return ResponseEntity.badRequest().body(new ApiError(
                Instant.now().toString(),
                HttpStatus.BAD_REQUEST.value(),
                "VALIDATION_ERROR",
                "Request validation failed",
                details
        ));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiError> handleIllegalArgument(IllegalArgumentException ex) {
        log.warn("api_bad_request message={}", ex.getMessage());
        return ResponseEntity.badRequest().body(new ApiError(
                Instant.now().toString(),
                HttpStatus.BAD_REQUEST.value(),
                "BAD_REQUEST",
                ex.getMessage(),
                List.of()
        ));
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ApiError> handleIllegalState(IllegalStateException ex) {
        log.warn("api_conflict message={}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.CONFLICT).body(new ApiError(
                Instant.now().toString(),
                HttpStatus.CONFLICT.value(),
                "CONFLICT",
                ex.getMessage(),
                List.of()
        ));
    }

    /**
     * A malformed date/time in a query param or body is a caller mistake, not a
     * server fault — without this it surfaced as an opaque 500.
     */
    @ExceptionHandler(DateTimeParseException.class)
    public ResponseEntity<ApiError> handleDateTimeParse(DateTimeParseException ex) {
        log.warn("api_bad_date value={}", ex.getParsedString());
        return ResponseEntity.badRequest().body(new ApiError(
                Instant.now().toString(),
                HttpStatus.BAD_REQUEST.value(),
                "BAD_REQUEST",
                "Invalid date or time value: " + ex.getParsedString(),
                List.of()
        ));
    }

    /** Unparseable JSON body, or a body omitted where one is required. */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> handleUnreadableBody(HttpMessageNotReadableException ex) {
        log.warn("api_unreadable_body message={}", ex.getMessage());
        return ResponseEntity.badRequest().body(new ApiError(
                Instant.now().toString(),
                HttpStatus.BAD_REQUEST.value(),
                "BAD_REQUEST",
                "Request body is missing or malformed",
                List.of()
        ));
    }

    /** A required query parameter was omitted. */
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ApiError> handleMissingParam(MissingServletRequestParameterException ex) {
        log.warn("api_missing_param name={}", ex.getParameterName());
        return ResponseEntity.badRequest().body(new ApiError(
                Instant.now().toString(),
                HttpStatus.BAD_REQUEST.value(),
                "BAD_REQUEST",
                "Missing required parameter: " + ex.getParameterName(),
                List.of()
        ));
    }

    /**
     * An unmatched URL. Without this the catch-all below turned every typo and
     * probe into a logged 500.
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(NoResourceFoundException ex) {
        log.debug("api_not_found path={}", ex.getResourcePath());
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiError(
                Instant.now().toString(),
                HttpStatus.NOT_FOUND.value(),
                "NOT_FOUND",
                "No such endpoint",
                List.of()
        ));
    }

    /**
     * Method security throws this before Spring's entry point can run, so the
     * anonymous case has to be separated here: no session at all is a 401 (the
     * app logs out and asks for OTP), a valid session on the wrong endpoint is
     * a 403.
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean anonymous = auth == null
                || !auth.isAuthenticated()
                || auth instanceof AnonymousAuthenticationToken;
        HttpStatus status = anonymous ? HttpStatus.UNAUTHORIZED : HttpStatus.FORBIDDEN;
        log.warn("api_access_denied anonymous={} message={}", anonymous, ex.getMessage());
        return ResponseEntity.status(status).body(new ApiError(
                Instant.now().toString(),
                status.value(),
                anonymous ? "UNAUTHORIZED" : "FORBIDDEN",
                anonymous ? "Session expired — please sign in again" : "Access denied",
                List.of()
        ));
    }

    /** Passcode lockout — the caller must wait, not retry. */
    @ExceptionHandler(com.sevacare.api.service.TooManyAttemptsException.class)
    public ResponseEntity<ApiError> handleTooManyAttempts(com.sevacare.api.service.TooManyAttemptsException ex) {
        log.warn("api_too_many_attempts message={}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(new ApiError(
                Instant.now().toString(),
                HttpStatus.TOO_MANY_REQUESTS.value(),
                "TOO_MANY_ATTEMPTS",
                ex.getMessage(),
                List.of()
        ));
    }

    /** The same Idempotency-Key arrived while its original is still executing. */
    @ExceptionHandler(com.sevacare.api.service.DuplicateRequestException.class)
    public ResponseEntity<ApiError> handleDuplicateRequest(com.sevacare.api.service.DuplicateRequestException ex) {
        log.warn("api_duplicate_request message={}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.CONFLICT).body(new ApiError(
                Instant.now().toString(),
                HttpStatus.CONFLICT.value(),
                "DUPLICATE_REQUEST",
                ex.getMessage(),
                List.of()
        ));
    }

    /**
     * The credential store could not be read. Authentication fails closed — 503,
     * never a silent fallback to the default OTP.
     */
    @ExceptionHandler(com.sevacare.api.service.AuthUnavailableException.class)
    public ResponseEntity<ApiError> handleAuthUnavailable(com.sevacare.api.service.AuthUnavailableException ex) {
        log.error("api_auth_unavailable message={}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(new ApiError(
                Instant.now().toString(),
                HttpStatus.SERVICE_UNAVAILABLE.value(),
                "AUTH_UNAVAILABLE",
                ex.getMessage(),
                List.of()
        ));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleUnexpected(Exception ex) {
        log.error("api_unexpected_error", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(new ApiError(
                Instant.now().toString(),
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                "INTERNAL_SERVER_ERROR",
                "An unexpected server error occurred",
                List.of()
        ));
    }

    private static String formatFieldError(FieldError error) {
        return error.getField() + ": " + (error.getDefaultMessage() == null ? "invalid value" : error.getDefaultMessage());
    }

    public record ApiError(
            String timestamp,
            int status,
            String code,
            String message,
            List<String> details
    ) {
    }
}
