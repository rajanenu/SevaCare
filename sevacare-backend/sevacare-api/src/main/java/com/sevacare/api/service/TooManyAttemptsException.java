package com.sevacare.api.service;

/** Too many wrong passcode attempts — the account is temporarily locked. Maps to 429. */
public class TooManyAttemptsException extends RuntimeException {

    public TooManyAttemptsException(String message) {
        super(message);
    }
}
