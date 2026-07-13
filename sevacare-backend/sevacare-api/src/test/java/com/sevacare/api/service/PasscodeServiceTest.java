package com.sevacare.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.lang.reflect.Proxy;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * The rules that make a 4-digit passcode survivable: the default only applies
 * to a mobile with no passcode row, wrong attempts lock the number, and an
 * unreadable credential store fails <em>closed</em> — never back to 0000.
 *
 * <p>Uses a hand-written {@link JdbcTemplate} fake rather than Mockito, which
 * cannot instrument concrete classes on the JVM these tests run under.
 */
class PasscodeServiceTest {

    private static final String MOBILE = "9844221599";
    private static final String HASH = new BCryptPasswordEncoder().encode("4321");

    /** One recorded write: the SQL and its bind values. */
    record Update(String sql, Object[] args) {
    }

    /**
     * Serves a configurable passcode row through the service's own RowMapper
     * (so the column order is tested too) and records every UPDATE/INSERT.
     */
    static class FakeJdbc extends JdbcTemplate {
        String hash;
        Integer failedAttempts;
        Timestamp lockedUntil;
        boolean failOnRead;
        final List<Update> updates = new ArrayList<>();

        void givenRow(String hash, int failedAttempts, Timestamp lockedUntil) {
            this.hash = hash;
            this.failedAttempts = failedAttempts;
            this.lockedUntil = lockedUntil;
        }

        @Override
        @SuppressWarnings("null")
        public <T> List<T> query(String sql, RowMapper<T> rowMapper, Object... args) {
            if (failOnRead) {
                throw new DataAccessResourceFailureException("db down");
            }
            if (hash == null) {
                return List.of();
            }
            ResultSet rs = (ResultSet) Proxy.newProxyInstance(
                    getClass().getClassLoader(), new Class<?>[] {ResultSet.class},
                    (proxy, method, a) -> switch (method.getName()) {
                        case "getString" -> hash;
                        case "getInt" -> failedAttempts;
                        case "getTimestamp" -> lockedUntil;
                        default -> throw new UnsupportedOperationException(method.getName());
                    });
            try {
                return List.of(rowMapper.mapRow(rs, 0));
            } catch (java.sql.SQLException e) {
                throw new IllegalStateException(e);
            }
        }

        @Override
        @SuppressWarnings("null")
        public int update(String sql, Object... args) {
            updates.add(new Update(sql, args));
            return 1;
        }

        Update lastUpdate() {
            assertThat(updates).isNotEmpty();
            return updates.get(updates.size() - 1);
        }
    }

    private final FakeJdbc jdbc = new FakeJdbc();
    private final PasscodeService service = new PasscodeService(jdbc);

    // ── Default mode ─────────────────────────────────────────────────────────

    @Test
    void defaultOtpAcceptedWhenNoPasscodeSet() {
        assertThatCode(() -> service.verify(MOBILE, "0000")).doesNotThrowAnyException();
    }

    @Test
    void wrongDefaultOtpRejected() {
        assertThatThrownBy(() -> service.verify(MOBILE, "1234"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid OTP");
    }

    // ── Passcode mode ────────────────────────────────────────────────────────

    @Test
    void correctPasscodeAccepted() {
        jdbc.givenRow(HASH, 0, null);
        assertThatCode(() -> service.verify(MOBILE, "4321")).doesNotThrowAnyException();
    }

    @Test
    void defaultOtpStopsWorkingOncePasscodeIsSet() {
        jdbc.givenRow(HASH, 0, null);
        assertThatThrownBy(() -> service.verify(MOBILE, "0000"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Incorrect passcode");
    }

    @Test
    void fifthWrongAttemptLocksTheNumber() {
        jdbc.givenRow(HASH, 4, null);
        assertThatThrownBy(() -> service.verify(MOBILE, "9999"))
                .isInstanceOf(TooManyAttemptsException.class);
        Update update = jdbc.lastUpdate();
        assertThat(update.sql()).contains("locked_until = ?");
        assertThat(update.args()[0]).isEqualTo(5);
        assertThat(update.args()[1]).isInstanceOf(Timestamp.class);
    }

    @Test
    void activeLockRejectsEvenTheCorrectPasscode() {
        jdbc.givenRow(HASH, 5, Timestamp.from(Instant.now().plusSeconds(600)));
        assertThatThrownBy(() -> service.verify(MOBILE, "4321"))
                .isInstanceOf(TooManyAttemptsException.class);
    }

    @Test
    void expiredLockStartsAFreshAttemptWindow() {
        jdbc.givenRow(HASH, 5, Timestamp.from(Instant.now().minusSeconds(60)));
        // One mistake after the lock lifts must not re-lock immediately.
        assertThatThrownBy(() -> service.verify(MOBILE, "9999"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("attempts left");
        Update update = jdbc.lastUpdate();
        assertThat(update.sql()).contains("locked_until = NULL");
        assertThat(update.args()[0]).isEqualTo(1);
    }

    @Test
    void successAfterMistakesClearsTheCounter() {
        jdbc.givenRow(HASH, 3, null);
        service.verify(MOBILE, "4321");
        assertThat(jdbc.lastUpdate().sql()).contains("failed_attempts = 0");
    }

    // ── Fail closed ──────────────────────────────────────────────────────────

    @Test
    void unreadableStoreFailsClosedNotBackToDefault() {
        jdbc.failOnRead = true;
        assertThatThrownBy(() -> service.verify(MOBILE, "0000"))
                .isInstanceOf(AuthUnavailableException.class);
    }

    // ── Setting a passcode ───────────────────────────────────────────────────

    @Test
    void setPasscodeRequiresCurrentCredential() {
        assertThatThrownBy(() -> service.setPasscode(MOBILE, "1111", "5678", "self:test"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat(jdbc.updates).isEmpty();
    }

    @Test
    void setPasscodeRejectsNonFourDigitCodes() {
        for (String bad : new String[] {"123", "12345", "abcd", "12a4"}) {
            assertThatThrownBy(() -> service.setPasscode(MOBILE, "0000", bad, "self:test"))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("4 digits");
        }
    }

    @Test
    void setPasscodeRejectsTheSharedDefault() {
        assertThatThrownBy(() -> service.setPasscode(MOBILE, "0000", "0000", "self:test"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("shared default");
    }

    @Test
    void setPasscodeUpsertsAHashNeverThePlaintext() {
        service.setPasscode(MOBILE, "0000", "5678", "self:test");
        Update update = jdbc.lastUpdate();
        assertThat(update.sql()).contains("INSERT INTO public.user_passcode");
        String storedHash = (String) update.args()[1];
        assertThat(storedHash).startsWith("$2").doesNotContain("5678");
        assertThat(new BCryptPasswordEncoder().matches("5678", storedHash)).isTrue();
    }
}
