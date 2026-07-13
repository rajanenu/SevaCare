package com.sevacare.api.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Appends to {@code public.audit_log} — the record of who touched which
 * patient's data, and when. The table is append-only under a DB trigger, so a
 * row written here can never be edited or deleted, only added to.
 *
 * <p>Never throws: the audit write happens after the response is already
 * decided, and a logging failure must not turn a served request into an error.
 * It is logged at ERROR instead, because a silent audit gap is exactly what an
 * audit exists to prevent.
 */
@Service
public class AuditService {

    private static final Logger log = LoggerFactory.getLogger(AuditService.class);

    private final JdbcTemplate jdbcTemplate;

    public AuditService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void record(String tenantPublicId, String actorRole, String actorPublicId,
                       String action, String subjectType, String subjectId,
                       String path, String clientIp) {
        try {
            jdbcTemplate.update(
                    "INSERT INTO public.audit_log " +
                            "(tenant_public_id, actor_role, actor_public_id, action, subject_type, subject_id, path, client_ip) " +
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    truncate(tenantPublicId, 32), truncate(actorRole, 32), truncate(actorPublicId, 64),
                    truncate(action, 64), truncate(subjectType, 32), truncate(subjectId, 64),
                    truncate(path, 255), truncate(clientIp, 45));
        } catch (DataAccessException e) {
            log.error("audit_write_failed action={} path={}", action, path, e);
        }
    }

    private static String truncate(String value, int max) {
        if (value == null) {
            return null;
        }
        return value.length() <= max ? value : value.substring(0, max);
    }
}
