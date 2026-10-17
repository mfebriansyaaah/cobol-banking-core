# Alert response

Status: inventory + procedure. Numeric thresholds are owner decisions
(Gate 0: SLOs); until they are approved, the table below lists what to
watch, where it surfaces, and the first action. Do not invent thresholds
in code — when owners approve them, record them here and in the deploy
record, never as magic numbers in scripts.

## Signals available today

| Signal | Source | First action on breach |
|---|---|---|
| `gateway_errors_total` by code | `GET /metrics` | Map the code: `DB_*` → check DB + pool; `INVALID_MFA` spike → possible credential stuffing → rate-limit review + dispute watch |
| Latency histograms (`gateway_latency_ms`) | `GET /metrics` | Compare against the approved SLO; check pool saturation (`pool_*` gauges) and slow-query log |
| Pool gauges (`pool_*`) + restart counter | `GET /metrics` | Restart counter rising → capture logs, inspect bridge/DB; saturation → scale or shed load per deploy runbook |
| `/ready` / `/health` probes | load balancer / monitor | `503` → see incident-response (SEV1/SEV2); cached-probe staleness → check DB reachability, not the app |
| Reconciliation mismatches | `RUN_RECONCILIATION` / `scheduled_reconcile.sh` | New mismatch → SEV2 triage; never adjust ledger to silence it |
| Outbox lag (`PENDING` age, dead letters) | `LIST_OUTBOX` | Worker down → restart via `scripts/outbox_worker.sh`; poison message → fix cause, never delete the row silently |
| Disk / backup age | cron + `backups/` manifest dates | Missing or stale backup → SEV2; run `backup.sh` now and fix the schedule |

## Adding a threshold (owner-approved only)

1. Owner signs the numeric threshold + window + severity.
2. Record it in the table above (threshold column) with date + approver.
3. Add the monitor check; keep the check next to this file, not in
   application code.
