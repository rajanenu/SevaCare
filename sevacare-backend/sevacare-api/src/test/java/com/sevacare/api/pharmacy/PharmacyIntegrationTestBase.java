package com.sevacare.api.pharmacy;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;

import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.service.TenantMigrationService;

/**
 * These tests live in {@code sevacare-api} rather than in {@code sevacare-pharmacy}
 * because that is where the application context actually is: the schema-per-tenant
 * Hibernate connection provider, the Flyway wiring, the transaction manager. A
 * test that stands up its own approximation of that context proves the
 * approximation works, which is the least useful thing it could prove.
 *
 * <p>Real Postgres, real migrations, real triggers, real row locks, and no
 * {@code @Transactional} on the tests themselves — the rollback and immutability
 * guarantees under test are exactly the ones a test-managed transaction would
 * paper over.
 */
@SpringBootTest(properties = {
        // The outbox dispatcher would otherwise start delivering the events these
        // tests publish, on a scheduler thread, while they are asserting on them.
        "sevacare.events.enabled=false"
})
abstract class PharmacyIntegrationTestBase {

    protected static final String TENANT_PUBLIC_ID = "T-9001";
    protected static final String TENANT_SCHEMA = "tenant_t_9001";
    protected static final String COUNTER = "COUNTER";

    private static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine")
                    .withDatabaseName("seva_care_test");

    static {
        // Started once for the whole suite and reused across test classes, which
        // Spring's context cache makes free. Ryuk stops it when the JVM exits.
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    protected JdbcTemplate jdbcTemplate;

    @Autowired
    private TenantMigrationService tenantMigrationService;

    @BeforeEach
    void provisionTenantAndClearPharmacyTables() {
        jdbcTemplate.update(
                "INSERT INTO public.tenant_registry " +
                "(tenant_public_id, tenant_name, tenant_theme_key, tenant_schema_name, tenant_status, " +
                " city, pin_code, pharmacy_profile_key) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?) " +
                "ON CONFLICT (tenant_public_id) DO UPDATE SET pharmacy_profile_key = EXCLUDED.pharmacy_profile_key",
                TENANT_PUBLIC_ID, "Ledger Test Pharmacy", "default", TENANT_SCHEMA, "active",
                "Hyderabad", "500001", "MEDICAL_STORE");

        TenantRegistry tenant = new TenantRegistry();
        tenant.setTenantPublicId(TENANT_PUBLIC_ID);
        tenant.setTenantSchemaName(TENANT_SCHEMA);
        tenantMigrationService.migrate(tenant);

        TenantContext.set(TENANT_PUBLIC_ID, TENANT_SCHEMA);

        // TRUNCATE rather than DELETE: row-level triggers do not fire for it, so
        // the batch_balance tripwire does not have to be disarmed to reset state.
        jdbcTemplate.execute(
                "TRUNCATE " + TENANT_SCHEMA + ".customer_return_line, " + TENANT_SCHEMA + ".customer_return, " +
                TENANT_SCHEMA + ".credit_payment, " +
                TENANT_SCHEMA + ".day_close, " + TENANT_SCHEMA + ".grn_line, " +
                TENANT_SCHEMA + ".goods_receipt, " + TENANT_SCHEMA + ".supplier, " +
                TENANT_SCHEMA + ".sale_line, " + TENANT_SCHEMA + ".sale, " +
                TENANT_SCHEMA + ".stock_ledger, " + TENANT_SCHEMA + ".batch_balance, " +
                TENANT_SCHEMA + ".batch, " + TENANT_SCHEMA + ".sku_pack, " + TENANT_SCHEMA + ".sku_alias, " +
                TENANT_SCHEMA + ".medicine_sku, " + TENANT_SCHEMA + ".pharmacy_config, " +
                TENANT_SCHEMA + ".outbox_event, " + TENANT_SCHEMA + ".outbox_event_consumption " +
                "RESTART IDENTITY CASCADE");
        jdbcTemplate.execute("ALTER SEQUENCE " + TENANT_SCHEMA + ".sku_public_id_seq RESTART WITH 1");
        jdbcTemplate.execute("ALTER SEQUENCE " + TENANT_SCHEMA + ".batch_public_id_seq RESTART WITH 1");
        jdbcTemplate.execute("ALTER SEQUENCE " + TENANT_SCHEMA + ".sale_public_id_seq RESTART WITH 1");
        jdbcTemplate.execute("ALTER SEQUENCE " + TENANT_SCHEMA + ".supplier_public_id_seq RESTART WITH 1");
        jdbcTemplate.execute("ALTER SEQUENCE " + TENANT_SCHEMA + ".grn_public_id_seq RESTART WITH 1");
        jdbcTemplate.execute("ALTER SEQUENCE " + TENANT_SCHEMA + ".customer_return_public_id_seq RESTART WITH 1");
    }

    @AfterEach
    void clearTenantContext() {
        TenantContext.clear();
    }

    protected long ledgerSum(String batchPublicId) {
        Long sum = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(qty_delta), 0) FROM " + TENANT_SCHEMA + ".stock_ledger " +
                "WHERE batch_public_id = ?", Long.class, batchPublicId);
        return sum == null ? 0L : sum;
    }

    protected int ledgerRowCount() {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + TENANT_SCHEMA + ".stock_ledger", Integer.class);
        return count == null ? 0 : count;
    }

    protected int outboxCountOfType(String eventType) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + TENANT_SCHEMA + ".outbox_event WHERE event_type = ?",
                Integer.class, eventType);
        return count == null ? 0 : count;
    }
}
