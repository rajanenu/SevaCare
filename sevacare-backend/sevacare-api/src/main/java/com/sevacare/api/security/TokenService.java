package com.sevacare.api.security;

import com.sevacare.shared.security.TokenClaims;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

@Component
public class TokenService {

    private final String secret;

    public TokenService(@Value("${sevacare.auth.secret:dev-sevacare-secret}") String secret) {
        this.secret = secret;
    }

    public String issue(TokenClaims claims) {
        String payload = claims.tenantPublicId() + "|" + claims.role() + "|" + claims.subjectPublicId();
        String encodedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(payload.getBytes(StandardCharsets.UTF_8));
        String signature = sign(encodedPayload);
        return encodedPayload + "." + signature;
    }

    public TokenClaims parse(String token) {
        String[] parts = token.split("\\.");
        if (parts.length != 2) {
            throw new IllegalArgumentException("Invalid token");
        }
        String encodedPayload = parts[0];
        String actualSignature = parts[1];
        String expectedSignature = sign(encodedPayload);
        if (!expectedSignature.equals(actualSignature)) {
            throw new IllegalArgumentException("Invalid token signature");
        }

        String payload = new String(Base64.getUrlDecoder().decode(encodedPayload), StandardCharsets.UTF_8);
        String[] values = payload.split("\\|");
        if (values.length != 3) {
            throw new IllegalArgumentException("Invalid token payload");
        }
        return new TokenClaims(values[0], values[1], values[2]);
    }

    private String sign(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] signature = mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(signature);
        } catch (Exception ex) {
            throw new IllegalStateException("Could not sign token", ex);
        }
    }
}
