# Gate 0 decision list

Status: checklist. Nothing here is approved until the named owners sign
it; code stays closed (fail-closed defaults, owner-controlled data, no
production wiring) while any item is open.

Decision log: item 17 (technical target runtime) was decided by the repository
owner on 2026-10-21. It is a technical architecture decision and does not
satisfy G0-SIGNOFF; all other items remain open.

Consolidated status, input checklist, and proposed technical defaults:
`docs/GATE0_PACKET.md`. Sources: `docs/TRACEABILITY.md`
(Gate 0 rows), `PRD_Enterprise.md` section 3, `docs/adr/0072-fx-fee-rate-policy.md`.

How to use this file: for each item, fill Owner, Decision, and Date.
`UNASSIGNED`/`TBD` means blocked. When an item is signed, update the
corresponding `docs/TRACEABILITY.md` row (owner + approval record) in the
same PR that implements the unblocked work.

## 1. Jurisdiction, legal entity, license (blocks everything)

- **Decide:** operating legal entity name, license type/number, jurisdiction(s),
  permitted products, customer types, currencies, reporting obligations.
- **Owner:** TBD (bank legal + compliance).
- **Date:** TBD.
- **Unblocks:** G0-ENTITY, and every row marked `BLOCKED` at Gate 0/2/3.
- **Note:** `PRD_Enterprise.md` section 3 items 1-2. Until this is named,
  compliance-sensitive work (KYC, screening, reports, DR) cannot start.

## 2. Accountable owners and sign-off records (blocks everything)

- **Decide:** named owners for compliance, legal, risk, security,
  finance/accounting, operations; where written sign-offs are recorded.
- **Owner:** TBD.
- **Date:** TBD.
- **Unblocks:** G0-SIGNOFF and every `UNASSIGNED` owner cell.
- **Note:** provisional owner `nineboll07` recorded decisions D1-D3 on
  2026-10-18 (`docs/adr/0072-fx-fee-rate-policy.md`); a licensed entity's
  compliance + finance owners must still ratify them for production.

## 3. Product and customer scope

- **Decide:** which products ship first (transfer-only vs funding/withdrawal),
  customer segments, end-of-day requirements.
- **Owner:** TBD (product + compliance).
- **Date:** TBD.
- **Unblocks:** A-P1-LIFECYCLE (application/opening product), B-P1-LIFECYCLE
  (funding/withdrawal, end-of-day).

## 4. KYC/CDD design and provider (PR 11)

- **Decide:** jurisdiction-approved identification, verification, risk
  classification, consent, evidence retention, review, rejection/exit;
  provider and integration owner.
- **Owner:** TBD (compliance).
- **Date:** TBD.
- **Unblocks:** A-P0-CDD.

## 5. Sanctions/PEP screening and transaction monitoring (PR 11)

- **Decide:** screening provider, lists, monitoring rules, risk states,
  escalation, case ownership, disposition, retention.
- **Owner:** TBD (compliance + risk).
- **Date:** TBD.
- **Unblocks:** C-P0-RISK.

## 6. Fraud operations model (PR 12)

- **Decide:** review queues, false-positive handling, dual-control overrides,
  rule versioning, outcome monitoring.
- **Owner:** TBD (risk + operations).
- **Date:** TBD.
- **Unblocks:** C-P1-FRAUDOPS.

## 7. Full disaster recovery (PR 12)

- **Decide:** RPO/RTO, recovery site, DR schedule and owner.
- **Owner:** TBD (operations + security).
- **Date:** TBD.
- **Unblocks:** F-P0-RESIL (DR leg). Backup/restore itself is implemented
  and tested (`scripts/backup.sh`, `scripts/restore.sh`).

## 8. Limits approval basis

- **Decide:** approved per-customer/product/channel limits and velocity
  (the posting path already enforces per-transaction and rolling-24h caps
  as configured data).
- **Owner:** TBD (risk + finance).
- **Date:** TBD.
- **Unblocks:** C-P0-LIMITS.

## 9. Regulatory reports and trial balance

- **Decide:** required report list and formats, trial-balance layout,
  reproducibility and controlled-export rules.
- **Owner:** TBD (finance + compliance).
- **Date:** TBD.
- **Unblocks:** D-P1-REPORTS.

## 10. Owner-controlled money data

- **Decide:** per-currency flat fee amounts (`fee_schedule`), hold policy,
  residual materiality for the FX gain/loss account.
- **Owner:** TBD (finance).
- **Date:** TBD.
- **Unblocks:** B-P1-LIFECYCLE (fee completeness). The core only applies
  configured data; nothing is hardcoded.

## 11. SLOs, load targets, alert thresholds

- **Decide:** SLOs, capacity/load test targets, health/alert thresholds.
- **Owner:** TBD (operations).
- **Date:** TBD.
- **Unblocks:** F-P0-RESIL (SLO/load legs). Probes, pool mode, metrics,
  and runbooks already exist.

## 12. Patch windows and exception approvers

- **Decide:** patch windows (e.g. critical <= 7 days), exception approver.
- **Owner:** TBD (security + operations).
- **Date:** TBD.
- **Unblocks:** `docs/patch-policy.md` rule 3. Everything else in that
  policy is already enforced (pinned lockfile, CI audit).

## 13. Incident severity contacts and roster

- **Decide:** who is paged per SEV level, contact/roster location.
- **Owner:** TBD (operations + security).
- **Date:** TBD.
- **Unblocks:** `docs/runbooks/incident-response.md` (workflow otherwise
  complete).

## 14. Retention, legal hold, key management

- **Decide:** retention schedule, legal-hold process, key management,
  non-production data handling; audit pipeline-failure alerting.
- **Owner:** TBD (legal + compliance + security).
- **Date:** TBD.
- **Unblocks:** F-P1-DATA, D-P0-AUDIT (legal-hold and alert legs).
  Archival with retention windows is already implemented.

## 15. Release approvals, production identity, independent assessment

- **Decide:** per-release approvers, production identity separation,
  independent assessment provider and cadence.
- **Owner:** TBD (security + operations).
- **Date:** TBD.
- **Unblocks:** F-P1-CHANGE (approvals leg), F-P0-SECOPS (identity and
  assessment legs), G0-PRODDATA. Migration review, least-privilege
  grants, and the release checklist already exist.

## 16. ADR 0072 production ratification

- **Decide:** ratify D1 (book residual to FX_PNL), D2 (refund by reason),
  D3 (24h rate window) for production as implemented.
- **Owner:** TBD (compliance + finance, licensed entity).
- **Date:** TBD.
- **Unblocks:** production use of the FX/fee/rate path. Implementation
  is complete and tested; only the sign-off is missing.

## 17. Target runtime and production-grade acceptance criteria

- **Decision:** **A - GnuCOBOL/MySQL/Linux**, with portable-core constraints.
  Recorded in `docs/adr/0082-target-runtime.md`.
- **Owner:** repository owner (technical decision, 2026-10-21); operations and
  security ratification pending.
- **Date:** 2026-10-21.
- **Unblocks:** Phase 0/1 of `docs/PRODUCTION_GRADE_PLAN.md`. The deployment,
  security, and performance workstreams now target GnuCOBOL/MySQL/Linux.
  Mainframe options B/C remain available only by reopening ADR 0082.
