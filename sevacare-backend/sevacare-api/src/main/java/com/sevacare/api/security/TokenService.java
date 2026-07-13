package com.sevacare.api.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

import javax.crypto.SecretKey;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.sevacare.shared.security.TokenClaims;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

/**
 * Access tokens are real JWTs now: {@code sub}, {@code tenant}, {@code role},
 * {@code iat}, {@code exp} (~{@link #ACCESS_TTL}) and a {@code jti} so a single
 * token can be revoked at logout. The previous format was an HMAC over
 * {@code tenant|role|subject} with <b>no expiry at all</b> — a token captured
 * once (shared laptop, screenshot, proxy log) was valid forever, and "logout"
 * only deleted the client's copy.
 *
 * <p>Sessions outlive the hour via the rotating refresh token
 * ({@link RefreshTokenService}), which is stored server-side and revocable —
 * that is the lever that makes logout and forced sign-out real.
 *
 * <p>{@link #parse} throws on a bad signature <em>or an expired token</em>;
 * {@code TokenAuthenticationFilter} turns that into an anonymous request and
 * Spring Security answers 401, which the app treats as "refresh or re-login".
 */
@Component
public class TokenService {

    /** How long an access token lives. Short on purpose — the refresh token carries the session. */
    public static final Duration ACCESS_TTL = Duration.ofMinutes(60);

    private final SecretKey key;

    public TokenService(@Value("${sevacare.auth.secret:dev-sevacare-secret}") String secret) {
        // HS256 requires >= 256 bits of key. Deriving via SHA-256 keeps every
        // existing SEVACARE_AUTH_SECRET working regardless of its length.
        this.key = Keys.hmacShaKeyFor(sha256(secret));
    }

    /** The claims plus the token-level fields revocation needs. */
    public record ParsedToken(TokenClaims claims, String jti, Instant expiresAt) {
    }

    public String issue(TokenClaims claims) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(claims.subjectPublicId())
                .claim("tenant", claims.tenantPublicId())
                .claim("role", claims.role())
                .id(UUID.randomUUID().toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(ACCESS_TTL)))
                .signWith(key)
                .compact();
    }

    /** Verifies signature and expiry; throws {@link io.jsonwebtoken.JwtException} otherwise. */
    public TokenClaims parse(String token) {
        return parseDetailed(token).claims();
    }

    public ParsedToken parseDetailed(String token) {
        Claims payload = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        TokenClaims claims = new TokenClaims(
                payload.get("tenant", String.class),
                payload.get("role", String.class),
                payload.getSubject());
        return new ParsedToken(claims, payload.getId(), payload.getExpiration().toInstant());
    }

    private static byte[] sha256(String value) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
