package com.sevacare.pharmacy;

import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * Pharmacy entities and repositories live under each bounded context
 * ({@code catalog.entity}, {@code inventory.repository}, …) rather than in one
 * module-wide package, so both scans are rooted at the module and pick up every
 * context. Sibling modules each declare their own equivalent; Spring Boot
 * accumulates the packages rather than letting the last one win.
 *
 * <p>Empty today. It exists now so that adding the first context is a matter of
 * adding classes, not of discovering why they were never scanned.
 */
@Configuration
@EntityScan(basePackages = "com.sevacare.pharmacy")
@EnableJpaRepositories(basePackages = "com.sevacare.pharmacy")
public class PharmacyJpaConfiguration {
}
