package com.sevacare.shared.security;

public record TokenClaims(String tenantPublicId, String role, String subjectPublicId) {
}
