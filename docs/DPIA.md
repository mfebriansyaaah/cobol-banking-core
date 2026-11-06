# DPIA — Identity Verification Integrations (PR-089, UU PDP)

## Purpose & legal basis

- Purpose: verify that a banking user controls the claimed identity (fraud
  prevention, account security). Nothing else.
- Basis: user consent per verification (explicit for remote NIK checks) +
  the bank's legitimate interest in preventing fraud. Consent records live in
  `consent_records(purpose, version, granted_at, revoked_at)`.

## Data & minimization

- NIK: HMAC-SHA256 + last4 only. Phone: hash + linked chat_id. OTP: hash.
  KTP images: never persisted, never sent to a cloud OCR.
- Remote NIK validation sends the NIK to exactly one allowlisted endpoint,
  only with per-call consent; default is the local structural validator
  (no data leaves the process).

## Processors & transfers

- Free-tier relays (SMS/Telegram Bot API): carry phone/chat_id + message
  text. No NIK, no KTP. Telegram/free_sms are delivery pipes, not verifiers.
- No cross-border analysis beyond what the pipes inherently do; if a pipe
  changes jurisdiction, re-assess before switching.

## Retention & rights

- OTP challenges: 10-minute life, inert after. Consent: `revoked_at` on
  withdrawal. Deletion: delete the user row — every identity table cascades.
- Access/correction/deletion requests: served from `users` + linked rows;
  no backups hold PII beyond the DB retention window (documented in runbooks).

## Risks & mitigations

- Provider breach of a phone number → numbers are hashed at rest; blast
  radius is delivery metadata, not identity proof.
- Consent fatigue → remote checks are opt-in per call with a visible purpose.
- Reviewer abuse → every decision records reviewer + reason + timestamp;
  review routes need fresh step-up auth.
