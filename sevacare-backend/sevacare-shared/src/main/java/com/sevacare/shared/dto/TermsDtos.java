package com.sevacare.shared.dto;

import java.time.LocalDateTime;
import java.util.List;

/**
 * The agreement between SevaCare and the business using it — a hospital, a clinic
 * or a medical store.
 *
 * <p>The document is served by the API rather than baked into the app so that a
 * customer reading the terms and a customer accepting them are always looking at
 * the same words, and so a revised version reaches an installed APK without a
 * release.
 */
public final class TermsDtos {

    private TermsDtos() {
    }

    public record TermsSection(String heading, List<String> paragraphs) {
    }

    public record TermsDocument(
            String version,
            String effectiveDate,
            String summary,
            List<TermsSection> sections
    ) {
    }

    /**
     * @param upToDate false when this tenant has accepted nothing, or accepted an
     *                 older version than the one now in force — either way, ask.
     */
    public record TermsAcceptanceView(
            String tenantPublicId,
            String currentVersion,
            String acceptedVersion,
            LocalDateTime acceptedAt,
            String acceptedBy,
            boolean upToDate
    ) {
    }

    public record TermsAcceptRequest(String version, String acceptedBy) {
    }
}
