package db.migration;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Ports the operator-set plaintext OTP overrides into the hashed
 * {@code user_passcode} table, then drops the plaintext table. A Java migration
 * because BCrypt is not available in SQL without the pgcrypto extension, and the
 * codes were set deliberately per user — silently reverting them to the shared
 * default would reopen exactly the accounts an operator chose to protect.
 *
 * <p>Ported codes keep their original length (the override column allowed up to
 * six digits); only newly set passcodes are constrained to four.
 */
public class V39__Port_otp_overrides_to_passcodes extends BaseJavaMigration {

    @Override
    public void migrate(Context context) throws Exception {
        record Override(String mobile, String otp, String note) {
        }

        List<Override> overrides = new ArrayList<>();
        try (Statement statement = context.getConnection().createStatement();
                ResultSet rs = statement.executeQuery(
                        "SELECT mobile_number, otp, note FROM public.user_otp_override")) {
            while (rs.next()) {
                overrides.add(new Override(rs.getString(1), rs.getString(2), rs.getString(3)));
            }
        }

        if (!overrides.isEmpty()) {
            BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
            try (PreparedStatement insert = context.getConnection().prepareStatement(
                    "INSERT INTO public.user_passcode (mobile_number, passcode_hash, note, updated_by) " +
                            "VALUES (?, ?, ?, 'migration:V39') " +
                            "ON CONFLICT (mobile_number) DO NOTHING")) {
                for (Override override : overrides) {
                    if (override.otp() == null || override.otp().isBlank()) {
                        continue;
                    }
                    insert.setString(1, override.mobile());
                    insert.setString(2, encoder.encode(override.otp().trim()));
                    insert.setString(3, override.note());
                    insert.addBatch();
                }
                insert.executeBatch();
            }
        }

        try (Statement statement = context.getConnection().createStatement()) {
            statement.execute("DROP TABLE public.user_otp_override");
        }
    }
}
