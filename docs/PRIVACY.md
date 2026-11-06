# Privacy & PII Policy (PR-087, UU PDP)

Integrations never trade personal data for convenience. Raw identity values
are hashed at rest, redacted in logs, and sent to a provider only with
consent and a documented purpose.

## Storage minimization

| Data | Stored as | Raw persists? |
| --- | --- | --- |
| NIK | HMAC-SHA256 (`nikHandle`, server secret) + `nik_last4` | Never (`users.nik_hash`, `identity_verifications.result_code` holds last4) |
| Phone | SHA-256 hash (`phone_hash`) + linked `chat_id` | Never (`phone_links`) |
| OTP code | SHA-256 `code_hash` only | Never (`otp_challenges`) |
| KTP image | Deleted after OCR; never uploaded to a cloud OCR | No image column exists |
| Consent | `consent_records(purpose, version, granted_at, revoked_at)` | Purpose + version only |

OTP challenges expire after 10 minutes and lock after 5 failed attempts.
(The plan suggested 5 minutes; 10 keeps one TTL with the link-token flow
while staying single-digit minutes and bounded. Attempts/lockout match.)

## Consent

- NIK is validated locally by default. The remote validator (`nusakit.js`)
  runs only with explicit `consent: true` **and** a configured endpoint on
  the `NUSAKIT_ALLOWLIST`.
- `consent_records` maps the plan's `consent_at`/`consent_version` to
  `granted_at`/`version`; revocation sets `revoked_at`. No new migration was
  needed (table landed in PR-085); deletion of the user cascades all rows.
- Data-subject deletion = delete the user row; `phone_links`,
  `identity_verifications`, `manual_reviews`, `consent_records`,
  `otp_challenges` all cascade.

## Provider data flows (free tier)

| Provider | What leaves the process |
| --- | --- |
| Email (log/mailpit/smtp) | Recipient + subject/body (delivery needs them) |
| Telegram | `chat_id` + message text (linked chat only) |
| free_sms | Phone + text (env relay only) |
| Nusakit | NIK, only with consent + allowlisted endpoint |
| Local NIK / OCR mock | Nothing leaves the process |

## Log policy

`middleware/src/integrations/redact.js` is the single scrubber:

- NIK → `************<last4>`; phone → `…<last4>`; chat_id → tail only.
- OTP codes and tokens → `[redacted]`, always, even partially.
- `scanForPii` backs the privacy suite: every provider log line is scanned,
  zero findings required.

One deliberate exception: email `to` is kept in mailer/outbox logs (the
recipient is required for delivery ops and the mailer suite locks the
contract). The address is the account key, never a secret authenticator;
codes are still never logged (outside `MAIL_DEBUG=1` in non-production).

## Retention

- OTP challenges: 10-minute life; expired rows are inert (status machine).
- Verification codes in `verification_logs`: consumed/single-use.
- KTP material: no persistence by design; manual-review reasons keep text
  only, never images.
