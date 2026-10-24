# Testing Strategy and Taxonomy

This document maps the existing test suites in `tests/` and `middleware/` to the
six standard backend testing categories, and records where the repository is
strong and where it has gaps. It is a living document: when a new suite is
added, update the appendix and the counts.

## 1. Scope and layers

| Layer | Technology | Where it runs |
|---|---|---|
| COBOL/C core | `cobc` programs invoked via `main_logic` | `tests/test_*.sh` (file or serve mode) |
| C bridge / SQL | `sql_bridge.c` | `tests/test_bridge_txn.sh`, `tests/test_c_memory.sh` |
| Database | MariaDB/MySQL | migrations, backup/restore, grants |
| Gateway | Node.js (`middleware/`) | `npm test` (126 tests) |
| Static / docs | shell + grep | `tests/static_checks.sh`, `tests/docs_check.sh`, `tests/status_check.sh` |

The full gate is `./ci.sh` (156 steps, ~3.7 min). The fast inner loop is
`./ci-fast.sh`. The nightly path (`scripts/nightly.sh`) adds the full 454-table
backup/restore round-trip and the coverage ratchet.

## 2. Category definitions

| # | Category | What it means here | Representative suites |
|---|---|---|---|
| 1 | **Unit** | Smallest isolated pieces: helpers, KDF, RNG, buffer contracts, C memory boundary. | `test_rng`, `test_password_kdf`, `test_password_policy`, `test_c_memory`, `tests/buffer_contract_check.sh` |
| 2 | **Integration** | COBOL core + database + bridge exercised end-to-end through `main_logic`, including transactions, EOD jobs, reconciliation, accounting. | `test_suite`, `test_atomic_txn`, `test_ledger_atomic`, `test_bridge_txn`, `test_eod_jobs`, `test_reconciliation` |
| 3 | **API / Endpoint** | HTTP surface of the gateway and the serve-mode protocol. | `test_e2e_gateway`, `test_prepared`, `test_ping`, `test_serve_mode`, `middleware/` (126) |
| 4 | **Database & Data Integrity** | Migrations, backup/restore round-trip, ledger integrity, grants, schema constraints. | `test_migrate`, `test_backup_restore`, `test_backup_restore_core`, `test_ledger_integrity`, `test_grants` |
| 5 | **Performance & Load** | Concurrency and throughput under load. | `test_concurrent_transfer` |
| 6 | **Security** | AuthN/AuthZ, sessions, MFA, tokens, injection, rate limiting, RNG, grants. | `test_injection`, `test_auth_login`, `test_login_lockout`, `test_session_security`, `test_mfa`, `test_token_rotation`, `test_grants` |

## 3. Coverage summary (shell suites)

| Category | Suites | Share |
|---|---:|---:|
| Integration | 108 | 75% |
| Security | 21 | 14% |
| Database & Data Integrity | 5 | 3% |
| Unit | 4 | 3% |
| API / Endpoint | 4 | 3% |
| Performance & Load | 1 | <1% |
| **Total shell suites** | **143** | 100% |

Plus the gateway suite (`middleware/`, 126 tests) which spans API, Security,
Performance (rate limiting, pool), and Data Integrity.

## 4. Gaps and recommendations

1. **Unit (weak).** Only 4 suites are truly isolated; most logic is tested through
   the binary. Recommendation: add focused unit tests for new helpers (e.g.
   `ref_engine`, `hash_lib`) and keep the KDF/RNG/policy suites as the model.
2. **Performance & Load (weak).** Only `test_concurrent_transfer` exists. There is
   no sustained load or stress suite. Recommendation: add a `test_load_smoke.sh`
   (bounded, CI-friendly) and keep heavy stress testing in `scripts/nightly.sh`.
3. **Database & Data Integrity (thin).** Backup/restore and migration are covered,
   but explicit constraint/rollback tests are sparse. Recommendation: extend
   `test_atomic_txn` assertions for rollback on partial failure and add a
   constraint-violation suite.
4. **API / Endpoint (gateway-heavy).** Shell-level API coverage is thin; the
   gateway suite compensates. Keep `test_e2e_gateway` as the end-to-end smoke.
5. **Security (good).** Auth, session, MFA, injection, grants, RNG are covered.
   Gap: no dedicated DoS/rate-limit shell test outside the gateway suite.

## 5. How to run by category

```bash
# Unit
./tests/test_rng.sh ./tests/test_password_kdf.sh ./tests/test_password_policy.sh ./tests/test_c_memory.sh

# API / Endpoint
./tests/test_e2e_gateway.sh ./tests/test_prepared.sh ./tests/test_ping.sh ./tests/test_serve_mode.sh
npm --prefix middleware test

# Database & Data Integrity
./tests/test_migrate.sh ./tests/test_backup_restore.sh ./tests/test_backup_restore_core.sh ./tests/test_ledger_integrity.sh ./tests/test_grants.sh

# Performance & Load
./tests/test_concurrent_transfer.sh

# Security
./tests/test_injection.sh ./tests/test_auth_login.sh ./tests/test_login_lockout.sh \
  ./tests/test_session_security.sh ./tests/test_mfa.sh ./tests/test_token_rotation.sh \
  ./tests/test_grants.sh

# Full gate
./ci.sh
```

## 6. Appendix: suite-to-category mapping

| Suite | Primary category |
|---|---|
| `test_access_reviews.sh` | Integration |
| `test_account_lifecycle.sh` | Integration |
| `test_account_status.sh` | Integration |
| `test_admin_hierarchy.sh` | Security |
| `test_admin_recovery.sh` | Security |
| `test_alert_center.sh` | Integration |
| `test_alert_escalation.sh` | Integration |
| `test_asset.sh` | Integration |
| `test_asset_maintenance.sh` | Integration |
| `test_atomic_txn.sh` | Integration |
| `test_audit_actor.sh` | Security |
| `test_audit_analytics.sh` | Integration |
| `test_audit_drilldown.sh` | Integration |
| `test_audit_integrity.sh` | Database & Data Integrity |
| `test_audit_read.sh` | Integration |
| `test_audit_retention.sh` | Integration |
| `test_audit_snapshot.sh` | Integration |
| `test_auth_login.sh` | Security |
| `test_backup_restore_core.sh` | Database & Data Integrity |
| `test_backup_restore.sh` | Database & Data Integrity |
| `test_batch.sh` | Integration |
| `test_bridge_txn.sh` | Integration |
| `test_budget.sh` | Integration |
| `test_capacity_plan.sh` | Integration |
| `test_card.sh` | Integration |
| `test_change_control.sh` | Integration |
| `test_c_memory.sh` | Unit |
| `test_compliance_audit.sh` | Integration |
| `test_compliance_export.sh` | Integration |
| `test_compliance_retention.sh` | Integration |
| `test_concurrent_transfer.sh` | Performance & Load |
| `test_control_accounts.sh` | Integration |
| `test_dashboard.sh` | Integration |
| `test_data_quality.sh` | Integration |
| `test_deposit.sh` | Integration |
| `test_disaster_recovery.sh` | Integration |
| `test_dispute_notify.sh` | Integration |
| `test_dispute_ops.sh` | Integration |
| `test_disputes.sh` | Integration |
| `test_dormancy.sh` | Integration |
| `test_dsar.sh` | Integration |
| `test_dual_control.sh` | Integration |
| `test_e2e_gateway.sh` | API / Endpoint |
| `test_eod.sh` | Integration |
| `test_eod_jobs.sh` | Integration |
| `test_export_archive.sh` | Integration |
| `test_export_stream.sh` | Integration |
| `test_fee.sh` | Integration |
| `test_fee_waiver.sh` | Integration |
| `test_fraud_ops.sh` | Integration |
| `test_fx_deal.sh` | Integration |
| `test_gl.sh` | Integration |
| `test_gl_period_close.sh` | Integration |
| `test_gl_reval.sh` | Integration |
| `test_grants.sh` | Security |
| `test_holds.sh` | Integration |
| `test_hooks.sh` | Integration |
| `test_idempotent_transfer.sh` | Integration |
| `test_import.sh` | Integration |
| `test_import_post.sh` | Integration |
| `test_import_recon.sh` | Integration |
| `test_incident.sh` | Integration |
| `test_injection.sh` | Security |
| `test_journal.sh` | Integration |
| `test_key_rotation.sh` | Integration |
| `test_kyc_review.sh` | Integration |
| `test_last_admin.sh` | Security |
| `test_lbpue.sh` | Integration |
| `test_ledger_atomic.sh` | Integration |
| `test_ledger_integrity.sh` | Database & Data Integrity |
| `test_legal_hold.sh` | Integration |
| `test_limit_profile.sh` | Integration |
| `test_loan.sh` | Integration |
| `test_login_lockout.sh` | Security |
| `test_mfa_recovery.sh` | Security |
| `test_mfa.sh` | Security |
| `test_mfa_state.sh` | Security |
| `test_migrate.sh` | Database & Data Integrity |
| `test_notification.sh` | Integration |
| `test_oncall_delivery.sh` | Integration |
| `test_oncall.sh` | Integration |
| `test_outbox.sh` | Integration |
| `test_password_kdf.sh` | Unit |
| `test_password_policy.sh` | Unit |
| `test_password.sh` | Security |
| `test_payment_enforcement.sh` | Integration |
| `test_payment_hold.sh` | Integration |
| `test_payment_instruction.sh` | Integration |
| `test_payment.sh` | Integration |
| `test_permissions.sh` | Integration |
| `test_ping.sh` | API / Endpoint |
| `test_pipeline_alert.sh` | Integration |
| `test_policy_attestation.sh` | Integration |
| `test_prepared.sh` | API / Endpoint |
| `test_procurement.sh` | Integration |
| `test_reconciliation.sh` | Integration |
| `test_reconciliation_runs.sh` | Integration |
| `test_recon_exception.sh` | Integration |
| `test_recon.sh` | Integration |
| `test_recon_ops.sh` | Integration |
| `test_ref_engine.sh` | Integration |
| `test_ref_ext.sh` | Integration |
| `test_regulatory_calendar.sh` | Integration |
| `test_regulatory_report.sh` | Integration |
| `test_report_archive.sh` | Integration |
| `test_report_delivery.sh` | Integration |
| `test_report.sh` | Integration |
| `test_report_scheduler.sh` | Integration |
| `test_resend_cooldown.sh` | Security |
| `test_retention_job.sh` | Integration |
| `test_risk_screening.sh` | Integration |
| `test_rng.sh` | Unit |
| `test_roles.sh` | Security |
| `test_sanctions_hold.sh` | Integration |
| `test_schedule_history.sh` | Integration |
| `test_secret_rotation.sh` | Integration |
| `test_seed.sh` | Integration |
| `test_serve_mode.sh` | API / Endpoint |
| `test_session.sh` | Security |
| `test_session_security.sh` | Security |
| `test_sessions_manage.sh` | Security |
| `test_settlement_recon.sh` | Integration |
| `test_signup_verify.sh` | Integration |
| `test_slo_report.sh` | Integration |
| `test_statement_delivery.sh` | Integration |
| `test_statement.sh` | Integration |
| `test_statement_recon.sh` | Integration |
| `test_statements.sh` | Integration |
| `test_step_up_policy.sh` | Security |
| `test_stepup.sh` | Security |
| `test_suite.sh` | Integration |
| `test_tax_report.sh` | Integration |
| `test_token_rotation.sh` | Security |
| `test_transfer_limits.sh` | Integration |
| `test_transfer_reversal.sh` | Integration |
| `test_transfer_validity.sh` | Integration |
| `test_treasury_position.sh` | Integration |
| `test_user_profile.sh` | Integration |
| `test_vendor_compliance.sh` | Integration |
| `test_vendor.sh` | Integration |
| `test_vendor_risk.sh` | Integration |
| `test_verify_cap.sh` | Security |
| `test_wallet_observability.sh` | Integration |

