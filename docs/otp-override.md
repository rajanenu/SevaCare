# Changing a user's OTP

The platform default OTP is `0000`. It applies to every mobile number that has
no row in `public.user_otp_override`. To give one person a different code, add a
row keyed by their mobile number — it takes effect on their next login attempt,
no redeploy needed.

Works for every role (patient, doctor, hospital admin, IP-Staff, platform admin)
and across tenants, because the key is the mobile number.

## Set (or change) an OTP for one user

```sql
INSERT INTO public.user_otp_override (mobile_number, otp, note)
VALUES ('9876543210', '4321', 'Reception desk — Dr. Rao')
ON CONFLICT (mobile_number)
DO UPDATE SET otp = EXCLUDED.otp,
              note = EXCLUDED.note,
              updated_at = CURRENT_TIMESTAMP;
```

## Reset a user back to the default `0000`

```sql
DELETE FROM public.user_otp_override WHERE mobile_number = '9876543210';
```

## See who currently has a custom OTP

```sql
SELECT mobile_number, otp, note, updated_at
FROM public.user_otp_override
ORDER BY updated_at DESC;
```

## Notes

- `otp` is `VARCHAR(6)`, so 4-digit codes fit; the login screen currently
  accepts exactly 4 digits, so keep overrides to 4 digits.
- The OTP is stored in clear text. It is a shared demo/staff credential, not a
  password — do not reuse it for anything that matters.
- The `/auth/otp/request` response no longer echoes the OTP back to the client.
  Whoever runs this query is responsible for telling the user their code.
