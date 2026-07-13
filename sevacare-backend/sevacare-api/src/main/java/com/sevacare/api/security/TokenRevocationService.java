package com.sevacare.api.security;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;

import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.github.benmanes.caffeine.cache.Caffeine;
import com.github.benmanes.caffeine.cache.LoadingCache;

/**
 * Real logout for the last hour of an access JWT's life.
 *
 * <p>Logout revokes the refresh token (the session is over) and drops the
 * current access token's {@code jti} here so it dies immediately instead of
 * coasting to its {@code exp}. Every authenticated request checks this set —
 * through a 60-second Caffeine cache, the same revocation bound the tenant
 * cache uses, so the cost is one DB read per token per minute, not per request.
 *
 * <p>Fails open by design: if the table is unreachable, requests proceed on
 * signature + expiry alone. Unlike authentication (where fail-open hands out
 * the default OTP), this guards a <em>revoked-early</em> edge whose window is
 * already bounded by the JWT's own expiry — refusing every request in an
 * outage would be the worse trade.
 */
@Service
public class TokenRevocationService {

    private final JdbcTemplate jdbcTemplate;

    private final LoadingCache<String, Boolean> revoked;

    public TokenRevocationService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
        this.revoked = Caffeine.newBuilder()
                .maximumSize(100_000)
                .expireAfterWrite(Duration.ofSeconds(60))
                .build(this::lookup);
    }

    public void revoke(String jti, Instant tokenExpiresAt) {
        if (jti == null || jti.isBlank()) {
            return;
        }
        jdbcTemplate.update(
                "INSERT INTO public.revoked_access_token (jti, expires_at) VALUES (?, ?) " +
                        "ON CONFLICT (jti) DO NOTHING",
                jti, Timestamp.from(tokenExpiresAt));
        revoked.put(jti, Boolean.TRUE);
    }

    public boolean isRevoked(String jti) {
        if (jti == null || jti.isBlank()) {
            return false;
        }
        Boolean hit = revoked.get(jti);
        return Boolean.TRUE.equals(hit);
    }

    private Boolean lookup(String jti) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM public.revoked_access_token WHERE jti = ?", Integer.class, jti);
            return count != null && count > 0;
        } catch (DataAccessException e) {
            return Boolean.FALSE;
        }
    }
}
