package com.sevacare.api.config;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.core.task.support.TaskExecutorAdapter;
import org.springframework.scheduling.annotation.EnableAsync;

import java.util.concurrent.Executors;

@Configuration
@EnableAsync
@EnableCaching
public class PlatformConfiguration {

    @Bean(name = "applicationTaskExecutor")
    AsyncTaskExecutor applicationTaskExecutor() {
        return new TaskExecutorAdapter(Executors.newVirtualThreadPerTaskExecutor());
    }

    @Bean
    CacheManager cacheManager() {
        return new ConcurrentMapCacheManager("tenantDiscovery", "tenantSchemas", "doctorDirectory", "patientViews", "adminViews");
    }
}
