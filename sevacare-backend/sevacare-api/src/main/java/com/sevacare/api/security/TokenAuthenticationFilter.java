package com.sevacare.api.security;

import com.sevacare.shared.security.TokenClaims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class TokenAuthenticationFilter extends OncePerRequestFilter {

    private final TokenService tokenService;
    private final TokenRevocationService tokenRevocationService;

    public TokenAuthenticationFilter(TokenService tokenService, TokenRevocationService tokenRevocationService) {
        this.tokenService = tokenService;
        this.tokenRevocationService = tokenRevocationService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authorization != null && authorization.startsWith("Bearer ")) {
            String token = authorization.substring(7);
            // A token that is malformed, tampered with, expired, or signed by a
            // previous secret must leave the request anonymous so Spring Security
            // answers 401 — and the app refreshes or re-logs-in. Letting the
            // exception escape the filter chain instead produced an opaque 500
            // the client never recovered from.
            try {
                TokenService.ParsedToken parsed = tokenService.parseDetailed(token);
                TokenClaims claims = parsed.claims();
                String role = claims.role();
                if (tokenRevocationService.isRevoked(parsed.jti())) {
                    // Logged out for real: the JWT would verify, but its session ended.
                    SecurityContextHolder.clearContext();
                } else if (role != null && !role.isBlank() && claims.subjectPublicId() != null) {
                    UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                            claims.subjectPublicId(),
                            token,
                            List.of(new SimpleGrantedAuthority("ROLE_" + role.trim().toUpperCase()))
                    );
                    authentication.setDetails(claims);
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            } catch (RuntimeException e) {
                logger.debug("token_rejected reason=" + e.getMessage());
                SecurityContextHolder.clearContext();
            }
        }

        filterChain.doFilter(request, response);
    }
}
