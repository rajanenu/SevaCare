package com.sevacare.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication(scanBasePackages = "com.sevacare")
@EnableScheduling
public class SevaCareApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(SevaCareApiApplication.class, args);
    }
}
