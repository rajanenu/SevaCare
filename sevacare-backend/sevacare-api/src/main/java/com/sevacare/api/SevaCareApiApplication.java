package com.sevacare.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "com.sevacare")
public class SevaCareApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(SevaCareApiApplication.class, args);
    }
}
