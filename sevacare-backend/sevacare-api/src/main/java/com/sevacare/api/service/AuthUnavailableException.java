package com.sevacare.api.service;

/**
 * The credential store could not be read, so the caller cannot be verified.
 * Authentication fails <em>closed</em>: an unreachable passcode table must never
 * degrade into "everyone's code is the default". Maps to 503.
 */
public class AuthUnavailableException extends RuntimeException {

    public AuthUnavailableException(String message) {
        super(message);
    }
}
