# SLO, RPO/RTO and Alerting (Gate 0)

Status: proposed defaults, owner approval required before production.

## Service level objectives
| Metric | Target | Measurement |
|---|---|---|
| Availability (gateway /health) | 99.9% monthly | uptime probe |
| Transfer latency p95 | < 500 ms | gateway histogram |
| Transfer latency p99 | < 2000 ms | gateway histogram |
| Error rate (5xx) | < 0.1% | `gateway_errors_total` |
| Backup success | 100% nightly | `scripts/nightly.sh` exit code |

## RPO / RTO
| Scenario | RPO | RTO | Mechanism |
|---|---|---|---|
| Single table corruption | 0 (point-in-time) | < 30 min | `scripts/restore.sh` from latest dump |
| Full DB loss | <= 24 h | < 4 h | nightly backup + restore |
| Region loss | <= 24 h | < 8 h | off-site backup copy (manual) |

## Alerting
- Gateway: alert on 5xx rate > 1% over 5 min, pool saturation, readiness failure.
- Database: alert on backup job failure, replication lag (if any), disk > 80%.
- COBOL: alert on repeated `DB_BUSY` / lock-wait errors.

## Retention
- Logical backups: `RETENTION_DAYS` (default 7) via `scripts/backup_retention.sh`.
- Audit trail: archive via `ARCHIVE_AUDIT` past retention window (default 90 days).
- Ledger: never delete; archive to `ledger_archive` for cold storage.
