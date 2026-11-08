# Operations Runbook (PR-095)

## Cron jobs (all free-tier)

| Job             | Command                                                                 | Check                             |
| --------------- | ----------------------------------------------------------------------- | --------------------------------- |
| Outbox dispatch | `OUTBOX_TRANSPORT=smtp ... node middleware/workers/outbox.js --once` | `OUTBOX_CHECK_ID`                 |
| FX sync         | `FX_CRON_ACTOR=... node scripts/cron/fetch_fx_rates.mjs`                | `FX_CHECK_ID` (wire when created) |
| Backup drill    | `scripts/ci/backup_restore_drill.sh`                                    | manual                            |

Create a free check at Healthchecks.io; set `<JOB>_CHECK_ID`. Missing ID =
no ping (jobs never fail on monitoring).

## Alerts

- `ALERT_TELEGRAM_CHAT_ID` (+ `TELEGRAM_BOT_TOKEN`) and/or
  `ALERT_NTFY_TOPIC` (`NTFY_SERVER` default ntfy.sh).
- Events: `OUTBOX_DEAD` (id + purpose only), worker crashes, drill failures.
- Alerts carry IDs/statuses, never PII, never bodies. Timeouts never fail
  the raising job.

## Incident: mail not flowing

1. `/metrics`: `gateway_mailer_failed_total` climbing?
2. Outbox dashboard: rows `FAILED` with error text.
3. `MAILPIT_HOST`/`SMTP_HOST` reachable? Relay suppression list?
4. Kill switch first if spam-loop suspected (`OUTBOX_MAX_ATTEMPTS` bounds it).
