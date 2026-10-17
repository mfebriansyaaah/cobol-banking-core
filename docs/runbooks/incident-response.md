# Incident response

Status: procedure. Severity definitions and contact/roster details are
owner decisions (Gate 0); the workflow below applies once they exist.

## Severity

| Level | Meaning | Example |
|---|---|---|
| SEV1 | Money or data integrity at risk; service down | Unbalanced journal posted, restore needed, DB down |
| SEV2 | Degraded or control blind | Outbox stalled, reconcile mismatches spiking, probe failing |
| SEV3 | Contained defect, no integrity impact | Single failed deploy, flaky suite |

## Workflow

1. **Detect** — alert (see `alert-response.md`), probe failure, or customer
   dispute spike. Note the time; use UTC.
2. **Triage** — confirm scope with read-only checks first:
   `GET /ready`, `GET /metrics` (SUPER_ADMIN), `RUN_RECONCILIATION`
   output, `scripts/scheduled_reconcile.sh` logs. Do not restart or
   rewrite state before evidence is captured.
3. **Contain** — for integrity risk: stop writers (gateway pool drain /
   stop service), freeze affected accounts (`PLACE_HOLD`), revoke
   sessions/tokens if credentials are suspect.
4. **Recover** — money movement is never edited in place: reverse with
   `REVERSE_TRANSFER`, resolve exceptions via `ACK/RESOLVE_EXCEPTION`,
   or restore from backup (`backup-restore.md`). Record every action.
5. **Review** — file the timeline, root cause, and control gap as an ADR;
   add a regression test; update this runbook.

## Evidence to capture

- `git rev-parse HEAD`, `./ci.sh` tail, relevant `audit_trail` rows
  (query by `action`, `entity_id`, time window), outbox states,
  reconciliation run id, backup manifest used (if any).

## What never happens

- No direct SQL writes to `ledger`, `audit_trail`, or `journal_entries`
  outside the COBOL bridge (triggers will refuse some of it, and the
  rest destroys the audit chain).
- No `main` rewrites; recovery is forward-only plus tested restore.
