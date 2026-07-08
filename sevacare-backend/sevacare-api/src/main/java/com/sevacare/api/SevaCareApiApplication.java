package com.sevacare.api;

import java.util.TimeZone;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication(scanBasePackages = "com.sevacare")
@EnableScheduling
public class SevaCareApiApplication {

    public static void main(String[] args) {
        // All hospitals are in India; the app stores/compares naive LocalDateTimes,
        // so the JVM must run in IST everywhere (Cloud Run containers default to
        // UTC, which made every "created just now" render as ~5.5 hours ago).
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Kolkata"));
        System.setProperty("user.timezone", "Asia/Kolkata");
        SpringApplication.run(SevaCareApiApplication.class, args);
    }
}
