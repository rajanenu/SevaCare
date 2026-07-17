package com.sevacare.api.config;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.http.HttpStatus;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import com.sevacare.api.security.ModuleAccessFilter;
import com.sevacare.api.security.TenantAccessFilter;
import com.sevacare.api.security.TokenAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfiguration {

    @Value("${sevacare.cors.allowed-origins:http://localhost:8087}")
    private String allowedOrigins;

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http, TenantHeaderFilter tenantHeaderFilter,
                                            TokenAuthenticationFilter tokenAuthenticationFilter,
                                            TenantAccessFilter tenantAccessFilter,
                                            ModuleAccessFilter moduleAccessFilter) throws Exception {
        return http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                        .requestMatchers("/api/v1/public/**", "/api/v1/auth/**").permitAll()
                        // Guarded by its own shared-secret header (SEVACARE_JOBS_TOKEN),
                        // checked in the controller in constant time; unset = 404.
                        .requestMatchers("/internal/jobs/**").permitAll()
                        .anyRequest().authenticated())
                // An unauthenticated caller must get 401, not Spring's default
                // 403 — the app auto-logs-out on 401 only, so a token that no
                // longer parses used to strand the user on a broken screen.
                .exceptionHandling(ex -> ex.authenticationEntryPoint(
                        new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
                .addFilterBefore(tenantHeaderFilter, UsernamePasswordAuthenticationFilter.class)
                .addFilterAfter(tokenAuthenticationFilter, TenantHeaderFilter.class)
                // Before any module or controller logic: the tenant in the header is
                // whatever the client typed, so pin it to the tenant in the token or
                // one hospital can read another's records — see TenantAccessFilter.
                .addFilterAfter(tenantAccessFilter, TokenAuthenticationFilter.class)
                // Last, because it needs a tenant that is now known to be the caller's
                // own. A module the tenant does not have answers 404, as though it were
                // never built — see ModuleAccessFilter.
                .addFilterAfter(moduleAccessFilter, TenantAccessFilter.class)
                .build();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOriginPatterns(List.of(allowedOrigins.split(",")));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("*"));
        // ETag is not a CORS-safelisted response header: without naming it here the
        // browser hides it from the web app, and the pharmacy counter can never send
        // back the If-None-Match that earns it a 304.
        configuration.setExposedHeaders(List.of("Authorization", "ETag"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
