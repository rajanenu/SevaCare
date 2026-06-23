package com.sevacare.doctor.config;

import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@Configuration
@EntityScan(basePackages = "com.sevacare.doctor.entity")
@EnableJpaRepositories(basePackages = "com.sevacare.doctor.repository")
public class DoctorJpaConfiguration {
}
