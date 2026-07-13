package com.sevacare.api.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.security.TokenClaims;

/**
 * The server-side half of a session: an opaque, rotating refresh token.
 *
 * <p>Access JWTs die in ~an hour and cannot be recalled individually without a
 * lookup; the refresh token is the durable, revocable credential. The client
 * holds 256 random bits; only the SHA-256 lands in {@code auth_refresh_token},
 * so the table never contains anything a reader could sign in with.
 *
 * <p>Every refresh <b>rotates</b>: the old row is revoked and points at its
 * replacement. Presenting an already-rotated token is therefore either a replay
 * of a stolen token or a client bug — it is refused, and because the legitimate
 * chain moved on, a thief who raced the real user gets cut off at the next hop.
 */
@Service
public class RefreshTokenService {

    /** How long a session survives without the user signing in again. */
    public static final Duration REFRESH_TTL = Duration.ofDays(30);

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);
    private static final SecureRandom RANDOM = new SecureRandom();

    private final JdbcTemplate jdbcTemplate;

    public RefreshTokenService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** Mints and stores a refresh token for a fresh login. Returns the raw token for the client. */
    public String issue(TokenClaims claims) {
        String raw = newRawToken();
        jdbcTemplate.update(
                "INSERT INTO public.auth_refresh_token " +
                        "(token_hash, tenant_public_id, role, subject_public_id, expires_at) VALUES (?, ?, ?, ?, ?)",
                sha256Hex(raw), claims.tenantPublicId(), claims.role(), claims.subjectPublicId(),
                Timestamp.from(Instant.now().plus(REFRESH_TTL)));
        return raw;
    }

    /** A rotation result: whose session this is, and the replacement token. */
    public record Rotation(TokenClaims claims, String newRefreshToken) {
    }

    /**
     * Exchanges a live refresh token for a new one, revoking the old. Throws
     * {@link IllegalArgumentException} (→ 400, and the client re-logs-in) for a
     * token that is unknown, expired, or already used.
     */
    @Transactional
    public Rotation rotate(String rawToken) {
        String hash = sha256Hex(require(rawToken));
        List<Row> rows = findByHash(hash);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Session expired — please sign in again");
        }
        Row row = rows.get(0);
        Instant now = Instant.now();
        if (row.revokedAt() != null) {
            // A rotated token coming back is a replay — of a theft or of a bug.
            log.warn("refresh_token_replayed tenant={} subject={}", row.tenant(), row.subject());
            throw new IllegalArgumentException("Session expired — please sign in again");
        }
        if (row.expiresAt().toInstant().isBefore(now)) {
            throw new IllegalArgumentException("Session expired — please sign in again");
        }

        TokenClaims claims = new TokenClaims(row.tenant(), row.role(), row.subject());
        String newRaw = newRawToken();
        String newHash = sha256Hex(newRaw);
        jdbcTemplate.update(
                "INSERT INTO public.auth_refresh_token " +
                        "(token_hash, tenant_public_id, role, subject_public_id, expires_at) VALUES (?, ?, ?, ?, ?)",
                newHash, claims.tenantPublicId(), claims.role(), claims.subjectPublicId(),
                Timestamp.from(now.plus(REFRESH_TTL)));
        jdbcTemplate.update(
                "UPDATE public.auth_refresh_token SET revoked_at = ?, replaced_by = ? WHERE token_hash = ?",
                Timestamp.from(now), newHash, hash);
        return new Rotation(claims, newRaw);
    }

    /** Logout: the token simply stops existing as a credential. Unknown tokens are a no-op. */
    public void revoke(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            return;
        }
        jdbcTemplate.update(
                "UPDATE public.auth_refresh_token SET revoked_at = CURRENT_TIMESTAMP " +
                        "WHERE token_hash = ? AND revoked_at IS NULL",
                sha256Hex(rawToken.trim()));
    }

    /** Rows whose expiry passed are dead weight; sweep them nightly. */
    @Scheduled(cron = "0 40 3 * * *", zone = "Asia/Kolkata")
    public void pruneExpired() {
        int refresh = jdbcTemplate.update(
                "DELETE FROM public.auth_refresh_token WHERE expires_at < CURRENT_TIMESTAMP - INTERVAL '7 days'");
        int access = jdbcTemplate.update(
                "DELETE FROM public.revoked_access_token WHERE expires_at < CURRENT_TIMESTAMP");
        if (refresh > 0 || access > 0) {
            log.info("auth_token_prune refresh_rows={} access_rows={}", refresh, access);
        }
    }

    private record Row(String tenant, String role, String subject, Timestamp expiresAt, Timestamp revokedAt) {
    }

    private List<Row> findByHash(String hash) {
        return jdbcTemplate.query(
                "SELECT tenant_public_id, role, subject_public_id, expires_at, revoked_at " +
                        "FROM public.auth_refresh_token WHERE token_hash = ?",
                (rs, i) -> new Row(rs.getString(1), rs.getString(2), rs.getString(3),
                        rs.getTimestamp(4), rs.getTimestamp(5)),
                hash);
    }

    private static String require(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new IllegalArgumentException("Session expired — please sign in again");
        }
        return rawToken.trim();
    }

    private static String newRawToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static String sha256Hex(String value) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
