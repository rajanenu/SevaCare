package com.sevacare.api.security;

import java.io.IOException;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Per-IP throttle on the endpoints an anonymous stranger can hammer: login
 * (where a 4-digit credential space means every free attempt matters), the
 * public QR-booking and chatbot routes (trivial DoS), and the passcode-change
 * endpoint. Fixed one-minute windows in a bounded Caffeine map.
 *
 * <p>Per <em>instance</em>, so N Cloud Run instances multiply the ceiling by N —
 * acceptable, because the per-mobile lockout in {@code PasscodeService} is
 * DB-backed and holds globally; this filter only takes the free volume away.
 * Registered outside the Spring Security chain, ahead of it, so a flood is
 * rejected before it costs a token parse or a tenant lookup.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);

    /**
     * POST attempts per IP per minute on auth + account-passcode routes. Sized
     * for a clinic's morning rush behind one shared WiFi IP (each login is two
     * POSTs), not for a lone attacker — the per-mobile DB lockout is what stops
     * a determined guesser.
     */
    static final int AUTH_LIMIT_PER_MINUTE = 30;
    /** POST attempts per IP per minute on public booking/chatbot routes. */
    static final int PUBLIC_LIMIT_PER_MINUTE = 30;

    private final Cache<String, AtomicInteger> windows = Caffeine.newBuilder()
            .maximumSize(50_000)
            .expireAfterWrite(Duration.ofMinutes(2))
            .build();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        int limit = limitFor(request);
        if (limit > 0) {
            String key = clientIp(request) + ":" + (System.currentTimeMillis() / 60_000);
            AtomicInteger counter = windows.get(key, k -> new AtomicInteger());
            if (counter.incrementAndGet() > limit) {
                log.warn("rate_limited ip={} path={}", clientIp(request), request.getRequestURI());
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                response.getWriter().write(
                        "{\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Too many requests. Please wait a minute and try again.\"}");
                return;
            }
        }
        chain.doFilter(request, response);
    }

    private static int limitFor(HttpServletRequest request) {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            return 0;
        }
        String path = request.getRequestURI();
        if (path.startsWith("/api/v1/auth/") || path.startsWith("/api/v1/account/passcode")) {
            return AUTH_LIMIT_PER_MINUTE;
        }
        if (path.startsWith("/api/v1/public/")) {
            return PUBLIC_LIMIT_PER_MINUTE;
        }
        return 0;
    }

    private static String clientIp(HttpServletRequest request) {
        // Behind Cloud Run the client is the first entry of X-Forwarded-For;
        // locally the header is absent and the socket address is the truth.
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            int comma = forwarded.indexOf(',');
            return (comma > 0 ? forwarded.substring(0, comma) : forwarded).trim();
        }
        return request.getRemoteAddr();
    }
}
