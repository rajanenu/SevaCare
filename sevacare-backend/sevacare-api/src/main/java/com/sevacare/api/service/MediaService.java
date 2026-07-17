package com.sevacare.api.service;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The deduplicated, content-addressed media store (public.media). Image bytes
 * are keyed by their own SHA-256, so identical uploads collapse to a single row
 * and the key doubles as an immutable HTTP ETag. Everything lives inside Cloud
 * SQL — no object store to pay for — while getting the bytes out of the
 * base64 TEXT columns and off the JSON wire. See MediaController for delivery
 * and MediaBackfillService for migrating legacy base64.
 */
@Service
public class MediaService {

    /** data:<content-type>;base64,<payload> — the shape a browser/file-picker emits. */
    private static final Pattern DATA_URI =
            Pattern.compile("^data:([^;,]+)(?:;charset=[^;,]+)?;base64,(.*)$", Pattern.DOTALL);

    private final JdbcTemplate jdbc;

    public MediaService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record MediaBlob(byte[] bytes, String contentType) {}

    /** Stored bytes + their detected content type, from a raw or data-URI base64 string. */
    public record DecodedImage(byte[] bytes, String contentType) {}

    /**
     * Store bytes, returning their SHA-256 (hex). Idempotent: a second call with
     * the same bytes is a no-op and returns the same sha (the row is the key).
     */
    @Transactional
    public String put(byte[] bytes, String contentType) {
        String sha = sha256Hex(bytes);
        // ON CONFLICT DO NOTHING: the content address is the primary key, so an
        // identical image is already stored and needs no second copy.
        jdbc.update(
                """
                INSERT INTO public.media (sha256, content_type, byte_size, bytes)
                VALUES (?, ?, ?, ?)
                ON CONFLICT (sha256) DO NOTHING
                """,
                sha, normalizeContentType(contentType), bytes.length, bytes);
        return sha;
    }

    /** Decode a raw or data-URI base64 string and store it; returns the sha or null when blank. */
    public String putBase64(String base64OrDataUri) {
        DecodedImage decoded = decode(base64OrDataUri);
        if (decoded == null) {
            return null;
        }
        return put(decoded.bytes(), decoded.contentType());
    }

    public Optional<MediaBlob> get(String sha256) {
        if (sha256 == null || sha256.isBlank()) {
            return Optional.empty();
        }
        List<MediaBlob> rows = jdbc.query(
                "SELECT bytes, content_type FROM public.media WHERE sha256 = ?",
                (rs, i) -> new MediaBlob(rs.getBytes("bytes"), rs.getString("content_type")),
                sha256);
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** Parse a data-URI or bare base64 string into bytes + content type; null when blank/invalid. */
    public static DecodedImage decode(String base64OrDataUri) {
        if (base64OrDataUri == null || base64OrDataUri.isBlank()) {
            return null;
        }
        String contentType = "image/jpeg";
        String payload = base64OrDataUri.trim();
        Matcher m = DATA_URI.matcher(payload);
        if (m.matches()) {
            contentType = m.group(1).trim();
            payload = m.group(2);
        }
        try {
            byte[] bytes = Base64.getDecoder().decode(payload.replaceAll("\\s", ""));
            if (bytes.length == 0) {
                return null;
            }
            return new DecodedImage(bytes, contentType);
        } catch (IllegalArgumentException notBase64) {
            return null;
        }
    }

    private static String normalizeContentType(String contentType) {
        if (contentType == null || contentType.isBlank()) {
            return "image/jpeg";
        }
        String trimmed = contentType.trim();
        return trimmed.length() > 100 ? trimmed.substring(0, 100) : trimmed;
    }

    public static String sha256Hex(byte[] bytes) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
            StringBuilder sb = new StringBuilder(64);
            for (byte b : digest) {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit(b & 0xF, 16));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
