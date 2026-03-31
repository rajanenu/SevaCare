package com.sevacare.api.service;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.sevacare.shared.dto.DiscoveryDtos;

@Service
public class OnboardingDocumentService {

    private final JdbcTemplate jdbcTemplate;
    private final Path onboardingDirectory;

    public OnboardingDocumentService(
            JdbcTemplate jdbcTemplate,
            @Value("${sevacare.storage.onboarding-dir:${user.home}/sevacare-storage/onboarding}") String onboardingDir
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.onboardingDirectory = Path.of(onboardingDir).toAbsolutePath().normalize();
    }

    @Transactional
    public List<DiscoveryDtos.OnboardingDocumentView> storeDocuments(String requestPublicId, List<MultipartFile> files) {
        ensureDirectoryExists();

        List<DiscoveryDtos.OnboardingDocumentView> created = new ArrayList<>();
        for (MultipartFile file : files) {
            if (file == null || file.isEmpty()) {
                continue;
            }

            String documentPublicId = nextDocumentPublicId();
            String originalName = sanitizeFileName(file.getOriginalFilename());
            String storedFileName = requestPublicId + "_" + UUID.randomUUID() + "_" + originalName;
            Path destination = onboardingDirectory.resolve(storedFileName).normalize();

            if (!destination.startsWith(onboardingDirectory)) {
                throw new IllegalArgumentException("Invalid file path");
            }

            try (InputStream input = file.getInputStream()) {
                Files.copy(input, destination, StandardCopyOption.REPLACE_EXISTING);
            } catch (IOException exception) {
                throw new IllegalStateException("Could not store uploaded document", exception);
            }

            jdbcTemplate.update(
                    """
                    INSERT INTO public.tenant_onboarding_document
                        (document_public_id, request_public_id, original_file_name, stored_file_name, content_type, file_size, storage_path)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    documentPublicId,
                    requestPublicId,
                    originalName,
                    storedFileName,
                    normalizeContentType(file.getContentType()),
                    file.getSize(),
                    destination.toString()
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
                SELECT document_public_id, request_public_id, original_file_name, COALESCE(content_type, 'application/octet-stream') AS content_type, file_size, storage_path
                FROM public.tenant_onboarding_document
                WHERE request_public_id = ? AND document_public_id = ?
                """,
                (rs, rowNum) -> new StoredDocument(
                        rs.getString("document_public_id"),
                        rs.getString("request_public_id"),
                        rs.getString("original_file_name"),
                        rs.getString("content_type"),
                        rs.getLong("file_size"),
                        Path.of(rs.getString("storage_path"))
                ),
                requestPublicId,
                documentPublicId
        );

        if (documents.isEmpty()) {
            throw new IllegalArgumentException("Document not found: " + documentPublicId);
        }
        return documents.get(0);
    }

    private String nextDocumentPublicId() {
        Long value = jdbcTemplate.queryForObject("SELECT nextval('public.onboarding_document_public_id_seq')", Long.class);
        if (value == null) {
            throw new IllegalStateException("Could not generate onboarding document id");
        }
        return "ONDOC-" + String.format("%04d", value);
    }

    private void ensureDirectoryExists() {
        try {
            Files.createDirectories(onboardingDirectory);
        } catch (IOException exception) {
            throw new IllegalStateException("Could not initialize onboarding storage directory", exception);
        }
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
            Path storagePath
    ) {
    }
}
