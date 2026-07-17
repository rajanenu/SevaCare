package com.sevacare.api.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.sevacare.shared.dto.DiscoveryDtos;

/**
 * Onboarding documents are stored in the database row itself, never on the local
 * filesystem: Cloud Run's disk is per-instance and wiped on every restart, so a
 * file written there is unreadable from the next instance and lost on deploy.
 * They are small one-time uploads (licences, registration certificates), so bytea
 * is the cheap, durable option — backed up with the DB, no object store to pay for.
 * Legacy rows from older local-dev builds still carry a storage_path; reads fall
 * back to it when the row has no bytes.
 */
@Service
public class OnboardingDocumentService {

    private final JdbcTemplate jdbcTemplate;

    public OnboardingDocumentService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public List<DiscoveryDtos.OnboardingDocumentView> storeDocuments(String requestPublicId, List<MultipartFile> files) {
        List<DiscoveryDtos.OnboardingDocumentView> created = new ArrayList<>();
        for (MultipartFile file : files) {
            if (file == null || file.isEmpty()) {
                continue;
            }

            String documentPublicId = nextDocumentPublicId();
            String originalName = sanitizeFileName(file.getOriginalFilename());
            String storedFileName = requestPublicId + "_" + UUID.randomUUID() + "_" + originalName;

            byte[] bytes;
            try {
                bytes = file.getBytes();
            } catch (IOException exception) {
                throw new IllegalStateException("Could not read uploaded document", exception);
            }

            jdbcTemplate.update(
                    """
                    INSERT INTO public.tenant_onboarding_document
                        (document_public_id, request_public_id, original_file_name, stored_file_name, content_type, file_size, file_bytes)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    documentPublicId,
                    requestPublicId,
                    originalName,
                    storedFileName,
                    normalizeContentType(file.getContentType()),
                    file.getSize(),
                    bytes
            );

            created.add(new DiscoveryDtos.OnboardingDocumentView(
                    documentPublicId,
                    originalName,
                    normalizeContentType(file.getContentType()),
                    file.getSize()
            ));
        }

        return created;
    }

    @Transactional(readOnly = true)
    public List<DiscoveryDtos.OnboardingDocumentView> listDocuments(String requestPublicId) {
        return jdbcTemplate.query(
                """
                SELECT document_public_id, original_file_name, COALESCE(content_type, 'application/octet-stream') AS content_type, file_size
                FROM public.tenant_onboarding_document
                WHERE request_public_id = ?
                ORDER BY uploaded_at ASC
                """,
                (rs, rowNum) -> new DiscoveryDtos.OnboardingDocumentView(
                        rs.getString("document_public_id"),
                        rs.getString("original_file_name"),
                        rs.getString("content_type"),
                        rs.getLong("file_size")
                ),
                requestPublicId
        );
    }

    @Transactional(readOnly = true)
    public StoredDocument mustGetDocument(String requestPublicId, String documentPublicId) {
        List<StoredDocument> documents = jdbcTemplate.query(
                """
                SELECT document_public_id, request_public_id, original_file_name, COALESCE(content_type, 'application/octet-stream') AS content_type, file_size, file_bytes, storage_path
                FROM public.tenant_onboarding_document
                WHERE request_public_id = ? AND document_public_id = ?
                """,
                (rs, rowNum) -> new StoredDocument(
                        rs.getString("document_public_id"),
                        rs.getString("request_public_id"),
                        rs.getString("original_file_name"),
                        rs.getString("content_type"),
                        rs.getLong("file_size"),
                        resolveContent(rs.getBytes("file_bytes"), rs.getString("storage_path"))
                ),
                requestPublicId,
                documentPublicId
        );

        if (documents.isEmpty() || documents.get(0).content() == null) {
            throw new IllegalArgumentException("Document not found: " + documentPublicId);
        }
        return documents.get(0);
    }

    private byte[] resolveContent(byte[] fileBytes, String legacyStoragePath) {
        if (fileBytes != null && fileBytes.length > 0) {
            return fileBytes;
        }
        if (legacyStoragePath == null || legacyStoragePath.isBlank()) {
            return null;
        }
        try {
            Path legacy = Path.of(legacyStoragePath);
            return Files.isReadable(legacy) ? Files.readAllBytes(legacy) : null;
        } catch (IOException exception) {
            return null;
        }
    }

    private String nextDocumentPublicId() {
        Long value = jdbcTemplate.queryForObject("SELECT nextval('public.onboarding_document_public_id_seq')", Long.class);
        if (value == null) {
            throw new IllegalStateException("Could not generate onboarding document id");
        }
        return "ONDOC-" + String.format("%04d", value);
    }

    private String sanitizeFileName(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            return "document.bin";
        }

        String cleaned = fileName.replace('\\', '_').replace('/', '_').replace("..", "_").trim();
        return cleaned.isBlank() ? "document.bin" : cleaned;
    }

    private String normalizeContentType(String contentType) {
        return (contentType == null || contentType.isBlank()) ? "application/octet-stream" : contentType;
    }

    public record StoredDocument(
            String documentPublicId,
            String requestPublicId,
            String originalFileName,
            String contentType,
            long fileSize,
            byte[] content
    ) {
    }
}
