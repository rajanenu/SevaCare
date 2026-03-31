package com.sevacare.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication(scanBasePackages = "com.sevacare")
@EntityScan(basePackages = "com.sevacare")
@EnableJpaRepositories(basePackages = "com.sevacare")
public class SevaCareApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(SevaCareApiApplication.class, args);
    }
}
