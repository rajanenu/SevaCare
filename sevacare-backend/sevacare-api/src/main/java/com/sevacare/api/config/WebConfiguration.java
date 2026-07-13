package com.sevacare.api.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.lang.NonNull;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import com.sevacare.api.security.AuditLogInterceptor;

@Configuration
public class WebConfiguration implements WebMvcConfigurer {

    private final AuditLogInterceptor auditLogInterceptor;

    public WebConfiguration(AuditLogInterceptor auditLogInterceptor) {
        this.auditLogInterceptor = auditLogInterceptor;
    }

    @Override
    public void addInterceptors(@NonNull InterceptorRegistry registry) {
        // The PHI audit trail sees every handler; the interceptor itself decides
        // which paths are patient data. See AuditLogInterceptor.
        registry.addInterceptor(auditLogInterceptor).addPathPatterns("/api/v1/**");
    }
}
