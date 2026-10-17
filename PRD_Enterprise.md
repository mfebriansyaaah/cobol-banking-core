# Product Requirements: Regulated Banking Core

Status: **Target mission; not a statement of regulatory approval or production readiness.**
Version: 2.0

## 1. Product mission

Build a secure, auditable banking core suitable for operation by a properly
licensed bank in a specifically identified jurisdiction. The system must
preserve monetary value, enforce approved product and compliance policies,
produce independently reconcilable records, and support controlled operations
and recovery.

This repository is currently a **development banking-core prototype**. It is
not licensed, certified, approved by a regulator, or ready to hold customer
funds. Passing CI or completing this PRD does not itself constitute regulatory
approval. Production use is prohibited until the release gates in Section 7
are evidenced and approved by the accountable bank, security, compliance,
finance, legal, and operations owners.

## 2. Scope and non-goals

The product scope is a bank-operated core ledger and its controlled API. It
includes customer/account lifecycle, double-entry postings, internal transfers,
approved funding and withdrawal channels, compliance controls, auditability,
reporting, and operational recovery.

The service is not, by itself, a web/mobile banking application, payment
network, identity-verification provider, sanctions data provider, card
processor, or regulatory authority. These require explicit integrations,
contracts, owners, and jurisdiction-specific requirements; they must not be
represented as implemented merely because an API seam exists.

**COBOL is the mandatory and sole authority for business logic.** This is an
architectural requirement, not an implementation preference. Business logic
includes financial calculations and postings, account/product state
transitions, eligibility, limits, pricing/fees, fraud/compliance decisions,
and business authorization. C, Node.js, SQL triggers, jobs, and integrations
must not independently make or alter these decisions. If another component
must enforce a technical boundary, COBOL must remain the final authoritative
decision point and the behavior must be covered by cross-boundary tests.

Other languages and infrastructure are permitted only as supporting adapters
for capabilities COBOL does not provide directly: HTTP/network transport,
process management, database-driver access, cryptographic primitives,
queue/provider clients, serialization, and observability. They may perform
syntax/size validation and defense-in-depth checks, but domain validation and
business outcomes must be implemented and enforced in COBOL. A capability
must not be moved out of COBOL merely for convenience; any technical exception
requires an explicit ADR, security/finance review, and proof that COBOL remains
the source of truth.

## 3. Regulatory and governance prerequisites

These are blocking requirements, not optional future enhancements:

1. Name the operating legal entity, license, jurisdiction(s), permitted
   products, customer types, currencies, and applicable reporting obligations.
2. Obtain written requirements and sign-off from the bank's compliance,
   legal, risk, security, finance/accounting, and operations owners.
3. Maintain a requirements-to-control-to-test-to-evidence traceability matrix.
   Every applicable obligation has an owner, implementation, test/evidence,
   retention period, and approval record.
4. Keep production data, secrets, access, and deployments under the bank's
   approved governance. No developer convenience default or test fixture may
   be used as a production configuration.
5. Reassess the matrix whenever jurisdiction, product, integration, or data
   processing changes.

Until the jurisdiction and accountable owners are identified, compliance
features below are requirements to resolve, not claims that a generic code
implementation satisfies a particular law.

## 4. Capability requirements

Priority: **P0** is a production release blocker; **P1** is required for the
initial regulated product; **P2** is conditional on product/jurisdiction and
must not precede P0/P1 controls.

### A. Customer, identity, and account lifecycle

- **P0 — Customer due diligence:** support the approved customer identification,
  verification, risk classification, consent, evidence retention, review,
  and rejection/exit workflows. Integrations must be explicit and auditable.
- **P0 — Access control:** least privilege, maker-checker/dual control for
  designated privileged operations, operator access reviews, strong
  authentication, session/device revocation, and attributable administrative
  actions.
- **P1 — Account lifecycle:** controlled application/opening, ownership,
  currency/product eligibility, holds/restrictions, closure, and archival.
  A user signup must not implicitly mean a financially usable account.
- **P1 — Recovery:** secure customer and administrator recovery, including
  lost MFA device, identity re-proofing, approval, notification, and audit.

### B. Financial ledger and money movement

- **P0 — Double-entry accounting:** every posted movement has balanced debit
  and credit legs in an immutable journal, with account, currency, value date,
  posting time, source, reference, and actor/initiator. Reversals are new
  compensating entries; posted rows are never edited or deleted in place.
- **P0 — Authoritative balance:** define whether balances are ledger-derived
  or materialized projections. Any projection must be transactionally updated,
  independently recomputable, continuously/periodically reconciled, and
  automatically alert on divergence. Reconciliation must cover all relevant
  states, currencies, holds, and pending postings.
- **P0 — Precision and limits:** use currency-specific minor units/precision
  end to end. No fixed `x100` scaling for zero-decimal currencies. Define
  rounding, rate source, rate validity/time, fees, limits, and boundary tests
  before enabling a product.
- **P1 — Complete lifecycle:** account opening, funding/deposit, withdrawal,
  internal transfer, fees, holds/releases, failed/reversed/returned payments,
  and end-of-day posting must be modeled as explicit state transitions.
- **P1 — Idempotency and concurrency:** retries and concurrent requests cannot
  create, lose, or duplicate value. Define idempotency scope, retention, and
  behavior after archival; test crash/retry and contention cases.
- **P1 — Reconciliation:** provide operator-controlled and scheduled
  reconciliation with immutable results, exception ownership, resolution
  workflow, and exportable evidence.

### C. Fraud, AML, and financial crime controls

- **P0 — Risk controls:** jurisdiction-approved screening and transaction
  monitoring requirements, customer/account risk state, sanctions/PEP handling
  where applicable, holds, escalation, case ownership, disposition, and
  evidence retention.
- **P0 — Limits and velocity:** approved per-customer/product/channel limits
  and velocity rules must be enforced in the posting path, fail safely, and
  create explainable/auditable decisions.
- **P1 — Fraud operations:** review queues, false-positive handling, overrides
  with dual control, rule versioning, and outcome monitoring. No opaque model
  may autonomously move or confiscate funds without an approved control design.

### D. Audit, records, and reporting

- **P0 — Audit evidence:** record who/what/when/result and correlation to the
  financial posting for sensitive actions. Protect integrity, restrict access,
  apply approved retention/legal hold, and alert on audit pipeline failure.
- **P1 — Customer records:** transaction history and statements with opening/
  closing balances, value/posting dates, currency, references, fees, and
  corrections/reversals.
- **P1 — Finance/regulatory reports:** balanced trial balance and product- and
  jurisdiction-required reports; all outputs must be reproducible from
  immutable source records and have controlled export access.
- **P2 — Analytics/export:** only after privacy, purpose limitation,
  authorization, retention, and data-quality controls are approved.

### E. Customer service and communications

- **P1 — Durable notifications:** transactional outbox/queue, bounded retries,
  delivery status, dead-letter handling, redaction, and operational alerting.
  A successful money movement must not be rolled back because an email provider
  is unavailable; notification loss must nevertheless be observable/recoverable.
- **P1 — Disputes and complaints:** customer ticket lifecycle linked to
  accounts/transactions, controlled assignments, response deadlines, escalation,
  and immutable case history.
- **P2 — Rewards/interest:** only after product terms, accrual basis, calendar,
  rounding, tax, reversals, and accounting treatment are specified and approved.

### F. Platform and operations

- **P0 — Resilience:** documented SLOs, capacity/load tests, health and alert
  thresholds, dependency failure behavior, controlled deployment/rollback, and
  tested backup/restore and disaster recovery against approved RPO/RTO.
- **P0 — Security operations:** secrets management/rotation, production
  identity separation, patch/dependency policy, vulnerability response,
  incident response, access logging, and independent security assessment.
- **P1 — Data lifecycle:** retention, deletion/legal hold, privacy access,
  archival, key management, and secure non-production data handling.
- **P1 — Change control:** reviewed schema migrations, backward compatibility,
  release evidence, approvals, and a tested path to recover from partial
  deployment or migration failure.

## 5. Non-functional requirements

- **Financial integrity:** no unbalanced or untraceable posted movement;
  duplicate delivery/retry cannot duplicate value.
- **Availability and recovery:** numeric SLO/RPO/RTO must be agreed by the
  accountable bank owners before production; demonstrate them with tests/drills.
- **Security:** threat model, least privilege, secure configuration, encryption
  in transit/at rest as required, key lifecycle, and independent assessment.
- **Auditability:** every posted amount is traceable from source instruction
  through journal, balance projection, reconciliation, statement, and report.
- **Testability:** requirements link to deterministic unit, integration,
  concurrency, fault-injection, reconciliation, migration, and recovery tests.
- **Maintainability:** repository size, LOC, commit count, and PR count are not
  success criteria. Correctness, evidence, and controlled operation are.

## 6. Current implementation boundary

The repository currently provides authentication and authorization, user
profiles, a multi-currency internal transfer path between existing accounts,
mutable account balances with spendable-balance enforcement, holds, scheduled per-currency fees as separate journals, journal-headed postings (balanced-leg verified pre-commit), audit-linked journals, recorded reconciliation runs with an exception workflow, maker-checker for designated operations (designation empty by default), transactional notification outbox with a dispatch worker, MFA backup codes and assisted recovery, read-only customer statements, dispute ticketing, transfer limits,
reversal, audit/session administration, a Node.js API gateway, and a MySQL/C
bridge. It includes substantial security and CI guardrails.

The following are **not implemented or not evidenced as production controls**:
account-opening/funding/withdrawal products, jurisdiction-specific KYC/AML and
sanctions workflows, fraud case management, dual control, durable notifications,
regulatory/finance reporting, interest/rewards,
production backup/restore/DR evidence, licensing/certification, and independent
security/compliance approval. See `docs/STATUS.md` for known technical gaps.

This boundary must be reflected in demos, documentation, and deployment claims.

## 7. Delivery order and release gates

1. **Gate 0 — Product/regulatory definition:** jurisdiction, license, legal
   entity, product scope, compliance matrix, owners, SLO/RPO/RTO.
2. **Gate 1 — Accounting foundation:** double-entry journal, authoritative
   balance contract, currency precision, complete posting lifecycle, crash and
   concurrency invariants, independent reconciliation.
3. **Gate 2 — Production controls:** KYC/AML/fraud workflows, maker-checker,
   durable audit/notifications, customer disputes and reporting required for
   launch.
4. **Gate 3 — Operational assurance:** backup/restore and DR drills, load and
   failure tests, incident runbooks, access/security review, migration/release
   evidence, independent sign-off.
5. **Gate 4 — Conditional products:** interest, rewards, analytics, or
   jurisdiction-specific integrations only after their accounting and control
   requirements are approved.

No gate is passed by code or CI alone. Each requires named owner approval and
retained evidence. **No customer funds or production customer data may be used
before Gates 0–3 are approved.**

## 8. Success criteria

- Requirements/control/test/evidence traceability is complete for the approved
  launch scope.
- Independent reconciliation demonstrates zero unexplained balance/journal
  differences across normal, retry, reversal, concurrency, and recovery paths.
- Approved limits, screening, holds, and dual-control workflows are tested and
  auditable.
- Backup restoration and disaster recovery meet the approved numeric RPO/RTO.
- Security, compliance, finance, operations, and legal owners approve the
  release evidence for the named jurisdiction and product.
