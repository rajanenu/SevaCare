package com.sevacare.api.config;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.core.task.support.TaskExecutorAdapter;
import org.springframework.scheduling.annotation.EnableAsync;

import com.github.benmanes.caffeine.cache.Caffeine;

import java.time.Duration;
import java.util.concurrent.Executors;

@Configuration
@EnableAsync
@EnableCaching
public class PlatformConfiguration {

    /**
     * How long a suspended tenant can still be served.
     *
     * <p>Every authenticated request resolves its tenant through {@code tenantSchemas},
     * which used to sit in an unbounded {@link
     * org.springframework.cache.concurrent.ConcurrentMapCacheManager} with no TTL and
     * — since there was no {@code @CacheEvict} anywhere in the codebase — no eviction
     * at all. The lookup only ever matches an *active* tenant, so the cache was the
     * only thing keeping a suspended one alive: marking a tenant {@code inactive} did
     * nothing, and their admin kept reading patient records until the process was
     * restarted. There was no way to revoke a customer.
     *
     * <p>An evict alone does not fix that, because it only clears the map on the one
     * Cloud Run instance that served the write; the other instances keep serving the
     * suspended tenant forever. Only a TTL makes every instance converge, so the TTL
     * is the correctness guarantee and the evict is just the fast path.
     *
     * <p>This is not the TTL that was banned from the pharmacy catalog. That one was
     * a *staleness* cache over data that changes every sale, and the fix was to key
     * it on a version read from the data. This is a *revocation* bound over a row
     * that changes when a customer is onboarded or cut off — minutes-fresh is the
     * requirement, and the ceiling on how long a cut-off customer keeps working.
     */
    private static final Duration TENANT_TTL = Duration.ofSeconds(60);

    @Bean(name = "applicationTaskExecutor")
    AsyncTaskExecutor applicationTaskExecutor() {
        return new TaskExecutorAdapter(Executors.newVirtualThreadPerTaskExecutor());
    }

    @Bean
    CacheManager cacheManager() {
        // Only the cache that something actually reads. The previous manager also
        // declared tenantDiscovery, doctorDirectory, patientViews and adminViews;
        // nothing has ever been @Cacheable on any of them. A cache name nobody uses
        // reads like a performance story that was never told.
        //
        // TenantModuleService stays deliberately uncached — see the note on that
        // class. Its read is a primary-key lookup, and a stale module flag makes the
        // pharmacy tab flicker in and out across instances.
        CaffeineCacheManager manager = new CaffeineCacheManager("tenantSchemas");
        manager.setCaffeine(Caffeine.newBuilder()
                .expireAfterWrite(TENANT_TTL)
                // A cache keyed by tenant is bounded by the customer count in practice,
                // but an unbounded map keyed by anything a caller supplies is a memory
                // leak waiting for its first bad client.
                .maximumSize(10_000)
                .recordStats());
        // A name that was never asked for is a typo, not a cache.
        manager.setAllowNullValues(false);
        return manager;
    }
}
