# Email Deliverability (PR-089)

Verification codes are useless in spam. Production mail needs all three:

## DNS (checked by `scripts/dev/check_email_dns.sh <domain>`)

- **SPF**: `TXT` record authorizing the sending hosts (`v=spf1 ... -all`).
- **DKIM**: provider-signed (`<selector>._domainkey` `TXT`); the signer is
  the SMTP relay, configured in the relay dashboard, not in this repo.
- **DMARC**: `_dmarc` `TXT` (`v=DMARC1; p=quarantine|reject; rua=...`).
- **rDNS/PTR**: sending IP resolves back (relay provider's job; verify).

## Bounce & complaint handling

- Hard bounces and complaints suppress the address (never retry a dead
  address — it burns reputation). Suppression lives in the relay; the
  gateway treats repeated `mail_failed` for one recipient as a signal to stop
  re-queueing (outbox worker backs off).
- Inbound webhooks (bounce/complaint) from the relay should feed suppression;
  until wired, review `mail_failed` lines weekly.

## Staging

- Mailpit only (`EMAIL_PROVIDER=mailpit`); production credentials must never
  exist in staging. `email_otp_flow.sh` proves delivery without real mail.
