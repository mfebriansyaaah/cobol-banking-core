# Incident Response (PR-070)

## Severity

- **SEV-1** (money/data at risk): wrong ledger writes, PII leak, auth bypass,
  DB down. Page immediately, freeze deploys.
- **SEV-2** (degraded): provider down (fallback active), elevated 5xx,
  outbox backlog growing, pool saturation. Fix in-hours.
- **SEV-3** (cosmetic/single-user): one-off failures, stale snapshot, docs.

## Paging

Free-tier: Healthchecks.io grace alarms + Telegram/ntfy fan-out
(`docs/runbooks/operations.md`). No PII in pages — IDs and statuses only.
Prometheus alerts live in `monitoring/prometheus-alerts.yml`.

## Triage (first 15 minutes)

1. `/metrics` + `/ready`: error rate, pool state, mailer failures.
2. `git log --oneline -5`: did a deploy just land? (`rollback.md` if yes.)
3. Outbox dashboard: `FAILED`/`DEAD` rows with error text.
4. `journalctl`/gateway logs: `errorCode` values (structured, greppable).

## Rules

- Money doubt → freeze the path first (kill switch: `QUOTA_*_DAILY=0`,
  `OUTBOX_MAX_ATTEMPTS` bounds loops), diagnose after.
- Never run ad-hoc writes against production; reproduce on the snapshot DB.
- Every SEV-1/2 ends with a postmortem (cause, fix, gate that would have
  caught it) linked from the PR that fixes it.
