package com.sevacare.api.config;

import com.sevacare.shared.tenant.TenantContext;
import org.hibernate.engine.jdbc.connections.spi.MultiTenantConnectionProvider;
import org.hibernate.context.spi.CurrentTenantIdentifierResolver;
import org.springframework.boot.autoconfigure.orm.jpa.HibernatePropertiesCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

@Configuration
public class HibernateMultiTenantConfig {

    @Bean
    public MultiTenantConnectionProvider<String> multiTenantConnectionProvider(DataSource dataSource) {
        return new SchemaPerTenantConnectionProvider(dataSource);
    }

    @Bean
    public CurrentTenantIdentifierResolver<String> tenantIdentifierResolver() {
        return new CurrentTenantIdentifierResolver<>() {
            @Override
            public String resolveCurrentTenantIdentifier() {
                return TenantContext.tenantSchema();
            }

            @Override
            public boolean validateExistingCurrentSessions() {
                return true;
            }
        };
    }

    @Bean
    public HibernatePropertiesCustomizer hibernatePropertiesCustomizer(
            MultiTenantConnectionProvider<String> multiTenantConnectionProvider,
            CurrentTenantIdentifierResolver<String> tenantIdentifierResolver
    ) {
        return (properties) -> {
            properties.put(org.hibernate.cfg.AvailableSettings.MULTI_TENANT_CONNECTION_PROVIDER, multiTenantConnectionProvider);
            properties.put(org.hibernate.cfg.AvailableSettings.MULTI_TENANT_IDENTIFIER_RESOLVER, tenantIdentifierResolver);
            properties.put("hibernate.multiTenancy", "SCHEMA");
        };
    }

    static class SchemaPerTenantConnectionProvider implements MultiTenantConnectionProvider<String> {

        private final DataSource dataSource;

        SchemaPerTenantConnectionProvider(DataSource dataSource) {
            this.dataSource = dataSource;
        }

        @Override
        public Connection getAnyConnection() throws SQLException {
            return dataSource.getConnection();
        }

        @Override
        public void releaseAnyConnection(Connection connection) throws SQLException {
            connection.setSchema("public");
            connection.close();
        }

        @Override
        public Connection getConnection(String tenantIdentifier) throws SQLException {
            Connection connection = getAnyConnection();
            connection.setSchema(tenantIdentifier);
            return connection;
        }

        @Override
        public void releaseConnection(String tenantIdentifier, Connection connection) throws SQLException {
            connection.setSchema("public");
            releaseAnyConnection(connection);
        }

        @Override
        public boolean supportsAggressiveRelease() {
            return false;
        }

        @Override
        public boolean isUnwrappableAs(Class<?> unwrapType) {
            return false;
        }

        @Override
        public <T> T unwrap(Class<T> unwrapType) {
            return null;
        }
    }
}
