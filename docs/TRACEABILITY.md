# Requirements traceability matrix

Source of truth for PRD requirement → control → test/evidence → owner.
Required by `PRD_Enterprise.md` section 3, item 3. Checked by
`tests/traceability_check.sh` (wired into `ci.sh`).

Conventions:

- `implemented` means code exists and is covered by the listed evidence.
  It is **not** a production or compliance claim: every row is still
  `BLOCKED` at Gate 0 because no accountable bank owner has approved it.
- `partial` means a mechanism exists but does not satisfy the requirement.
- `missing` means no control exists; the Tests/evidence cell names the
  blocking gap instead of a suite.
- Backticked paths are existing files (enforced by `tests/docs_check.sh`).
  Anything not yet built is written in plain words, never in backticks.
- Owner is `UNASSIGNED` on every row until Gate 0 names the accountable
  bank, security, compliance, finance, legal, and operations owners.

## Gate 0 — Product/regulatory definition (PRD section 3)

| Req ID | Requirement | Status | Control / implementation | Tests / evidence | Owner | Retention / approval | Gate |
|---|---|---|---|---|---|---|---|
| G0-ENTITY | Operating legal entity, license, jurisdiction, products, customers, currencies, reporting obligations named | missing | No entity, license, or jurisdiction is named anywhere in the repo | Blocked: jurisdiction and entity unidentified (PRD section 3, items 1–2) | UNASSIGNED | No retention defined; no approval recorded | Gate 0 BLOCKED |
| G0-SIGNOFF | Written requirements and sign-off from compliance, legal, risk, security, finance/accounting, operations | missing | No sign-off records exist | Blocked: no accountable owners named | UNASSIGNED | No retention defined; no approval recorded | Gate 0 BLOCKED |
| G0-MATRIX | Requirements-to-control-to-test-to-evidence matrix maintained | implemented | `docs/TRACEABILITY.md` (this file) | `tests/traceability_check.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 0 open |
| G0-PRODDATA | Production data, secrets, access, deployments under bank governance; no dev defaults as production config | partial | Least-privilege runtime account in `database/grants.sh`; production secret guard in `middleware/src/server.js`; no production deployment exists to govern | `tests/test_grants.sh`, `tests/env_check.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 0 BLOCKED |
| G0-REASSESS | Matrix reassessed on jurisdiction/product/integration/data change | partial | Rule written in `CODING_STANDARDS.md` (reassess clause); no change history to apply it to yet | `tests/traceability_check.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 0 open |

## A. Customer, identity, account lifecycle

| Req ID | Requirement | Status | Control / implementation | Tests / evidence | Owner | Retention / approval | Gate |
|---|---|---|---|---|---|---|---|
| A-P0-CDD | Customer identification, verification, risk classification, consent, evidence retention, review, rejection/exit | missing | Only email-code verification and status flags exist; no identification, risk, consent, or exit workflow | Blocked: needs jurisdiction-approved KYC design and owner | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| A-P0-ACCESS | Least privilege, dual control for designated operations, access reviews, strong auth, session/device revocation, attributable admin actions | partial | Least-privilege DB account (`database/grants.sh`); rank hierarchy and last-admin guard in `cobol/src/auth_core.cob` and `cobol/src/user_core.cob`; step-up proof in `middleware/src/auth.js`; session/device revocation in `cobol/src/auth_core.cob`; no dual control, no access reviews | `tests/test_grants.sh`, `tests/test_admin_hierarchy.sh`, `tests/test_last_admin.sh`, `tests/test_stepup.sh`, `tests/test_sessions_manage.sh`, `tests/test_token_rotation.sh`, `tests/test_audit_actor.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| A-P1-LIFECYCLE | Controlled application/opening, ownership, eligibility, holds/restrictions, closure, archival | partial | Signup + status lifecycle (`VERIFIED`/`SUSPENDED`/`CLOSED`) and soft-close in `cobol/src/auth_core.cob` and `cobol/src/user_core.cob`; no application/opening product, no holds | `tests/test_signup_verify.sh`, `tests/test_account_lifecycle.sh`, `tests/test_user_profile.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| A-P1-RECOVERY | Secure customer and administrator recovery incl. lost MFA device, identity re-proofing, approval, notification, audit | partial | Admin unlock and MFA reset with rank gate, step-up, and audit in `cobol/src/user_core.cob`; no backup codes, no re-proofing, no approval workflow | `tests/test_admin_recovery.sh`, `tests/test_mfa.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |

## B. Financial ledger and money movement

| Req ID | Requirement | Status | Control / implementation | Tests / evidence | Owner | Retention / approval | Gate |
|---|---|---|---|---|---|---|---|
| B-P0-DOUBLE | Double-entry: balanced debit/credit legs in an immutable journal with account, currency, value date, posting time, source, reference, actor | implemented | One `journal_entries` row per posting (`TRANSFER`/`REVERSAL`, value date, source, actor) with linked legs and audit rows in `cobol/src/wallet_core.cob`; pre-commit balanced-leg verification (same- and cross-currency, either direction) rolls back on violation; append-only triggers; crash-recovery proven by `tests/test_journal.sh` | `tests/test_ledger_atomic.sh`, `tests/test_ledger_integrity.sh`, `tests/test_bridge_txn.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 1 open |
| B-P0-BALANCE | Authoritative balance defined; projections transactionally updated, recomputable, reconciled, alert on divergence | partial | `accounts.balance` is a materialized projection updated inside the transfer transaction; `RECONCILE` in `cobol/src/wallet_core.cob` recomputes from `ledger`; no divergence alerting | `tests/test_reconciliation.sh`, `tests/test_ledger_atomic.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 1 open |
| B-P0-PRECISION | Currency-specific minor units end to end; no fixed x100 scaling; defined rounding, rate source/validity, fees, limits, boundary tests | partial | Amounts parsed in exact major units per currency (`cobol/src/wallet_core.cob`: dot normalized before NUMVAL); caps in whole sender units with fail-closed validation; per-currency precision gate (0-4, fail closed above); posting/reads/reversal at full precision; KNOWN GAPS: rate source has no validity window, no fees | `tests/test_transfer_validity.sh`, `tests/test_transfer_limits.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 1 open |
| B-P1-LIFECYCLE | Account opening, funding/deposit, withdrawal, internal transfer, fees, holds/releases, failed/reversed/returned, end-of-day as explicit state transitions | partial | Journal-headed internal transfer and compensating reversal with linked audit in `cobol/src/wallet_core.cob`; no funding/withdrawal products, no fees, no holds, no end-of-day | `tests/test_suite.sh`, `tests/test_transfer_reversal.sh`, `tests/test_account_status.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 1 open |
| B-P1-IDEM | Retries and concurrent requests cannot duplicate value; idempotency scope, retention, post-archival behavior defined | implemented | Per-sender idempotency keys with `TRANSFER_IN_PROGRESS` and replay in `cobol/src/wallet_core.cob`; retention window with archival; concurrent-transfer and crash-path coverage | `tests/test_idempotent_transfer.sh`, `tests/test_concurrent_transfer.sh`, `tests/test_atomic_txn.sh`, `tests/test_wallet_observability.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 1 open |
| B-P1-RECON | Operator-controlled and scheduled reconciliation with immutable results, exception ownership, resolution workflow, exportable evidence | partial | On-demand `RECONCILE` in `cobol/src/wallet_core.cob` with actor gate; no scheduling, no immutable result store, no exception workflow | `tests/test_reconciliation.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 1 open |

## C. Fraud, AML, financial crime

| Req ID | Requirement | Status | Control / implementation | Tests / evidence | Owner | Retention / approval | Gate |
|---|---|---|---|---|---|---|---|
| C-P0-RISK | Jurisdiction-approved screening, transaction monitoring, risk state, sanctions/PEP handling, holds, escalation, case ownership, disposition, retention | missing | No screening, monitoring, risk state, sanctions handling, or case workflow | Blocked: needs jurisdiction, providers, and owner | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| C-P0-LIMITS | Approved per-customer/product/channel limits and velocity enforced in the posting path, fail-safe, explainable/auditable | partial | Per-transaction and rolling-24h debit caps enforced in the posting path in `cobol/src/wallet_core.cob`; no per-customer/product/channel approval basis | `tests/test_transfer_limits.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| C-P1-FRAUDOPS | Review queues, false-positive handling, overrides with dual control, rule versioning, outcome monitoring | missing | No review queue, no rule versioning, no dual-control override | Blocked: needs fraud-operations design and owner | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |

## D. Audit, records, reporting

| Req ID | Requirement | Status | Control / implementation | Tests / evidence | Owner | Retention / approval | Gate |
|---|---|---|---|---|---|---|---|
| D-P0-AUDIT | who/what/when/result for sensitive actions, journal correlation, integrity, restricted access, retention/legal hold, pipeline-failure alert | partial | Attributed audit rows with actor in `cobol/src/auth_core.cob`, `cobol/src/user_core.cob`, `cobol/src/wallet_core.cob`; append-only trigger; SUPER_ADMIN-only read in `middleware/src/app.js`; retention via `ARCHIVE_AUDIT`; no legal hold, no pipeline-failure alert | `tests/test_audit_actor.sh`, `tests/test_audit_read.sh`, `tests/test_audit_integrity.sh`, `tests/test_roles.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| D-P1-RECORDS | Transaction history and statements with opening/closing balances, dates, currency, references, fees, corrections | missing | No statements; history exists only as raw `ledger` rows and `RECONCILE` output | Blocked: needs statement design and owner | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| D-P1-REPORTS | Balanced trial balance and jurisdiction-required reports, reproducible, controlled export | missing | No trial balance, no regulatory reports | Blocked: needs jurisdiction requirements and owner | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |

## E. Customer service and communications

| Req ID | Requirement | Status | Control / implementation | Tests / evidence | Owner | Retention / approval | Gate |
|---|---|---|---|---|---|---|---|
| E-P1-NOTIFY | Transactional outbox/queue, bounded retries, delivery status, dead-letter, redaction, alerting; money movement never rolled back for mail failure | missing | Verification mail sent inline from `middleware/src/app.js` via `middleware/src/mailer.js`; no outbox, no retries, no dead-letter | Blocked: needs outbox design | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |
| E-P1-DISPUTES | Ticket lifecycle linked to accounts/transactions, assignments, deadlines, escalation, immutable history | missing | No ticketing | Blocked: needs dispute-workflow design and owner | UNASSIGNED | No retention defined; no approval recorded | Gate 2 BLOCKED |

## F. Platform and operations

| Req ID | Requirement | Status | Control / implementation | Tests / evidence | Owner | Retention / approval | Gate |
|---|---|---|---|---|---|---|---|
| F-P0-RESIL | SLOs, capacity/load tests, health/alert thresholds, dependency failure behavior, controlled deploy/rollback, tested backup/restore and DR against approved RPO/RTO | partial | Liveness/readiness probes, pool mode, metrics and latency histograms in `middleware/src/server.js`, `middleware/src/observability.js`, `middleware/src/pool.js`; no SLOs, no load tests, no backup/restore, no RPO/RTO | `tests/test_e2e_gateway.sh`, `tests/test_serve_mode.sh`, `tests/test_ping.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 3 BLOCKED |
| F-P0-SECOPS | Secrets rotation, production identity separation, patch/dependency policy, vuln response, incident response, access logging, independent assessment | partial | Production secret guard and security headers in `middleware/src/server.js`; JSON access log lines; no rotation, no patch policy, no incident runbooks, no assessment | Gateway suite in `middleware/test/gateway.test.js` | UNASSIGNED | No retention defined; no approval recorded | Gate 3 BLOCKED |
| F-P1-DATA | Retention, deletion/legal hold, privacy access, archival, key management, non-production data handling | partial | Audit/pending archival with retention windows in `cobol/src/auth_core.cob` and `cobol/src/wallet_core.cob`; no legal hold, no key management | `tests/test_roles.sh`, `tests/test_wallet_observability.sh`, `tests/test_migrate.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 3 BLOCKED |
| F-P1-CHANGE | Reviewed migrations, backward compatibility, release evidence, approvals, recovery from partial deployment/migration | partial | Reviewed migration runner with failure semantics, idempotent seeds, migration-account separation in `database/migrate.sh` and `database/grants.sh`; no partial-deployment recovery path, no release-evidence template | `tests/test_migrate.sh`, `tests/test_seed.sh`, `tests/test_grants.sh` | UNASSIGNED | No retention defined; no approval recorded | Gate 3 BLOCKED |

## Reading this matrix

- Rows marked `implemented` are technically complete and tested, but must
  not be presented as regulatory compliance: owner approval is outstanding
  on every row.
- Rows marked `BLOCKED` need a Gate 0 decision (jurisdiction, owner, or
  approved numeric target) before implementation may start; code that
  guesses at those requirements would violate `CODING_STANDARDS.md` rule 2.
- P2 requirements (analytics/export, rewards/interest) are intentionally
  absent: they must not precede P0/P1 controls.
