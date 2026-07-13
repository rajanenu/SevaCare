package com.sevacare.api.service;

/**
 * The same Idempotency-Key arrived while its first request is still executing.
 * Answered with 409 — the client should wait for the original, not run again.
 */
public class DuplicateRequestException extends RuntimeException {

    public DuplicateRequestException(String message) {
        super(message);
    }
}
