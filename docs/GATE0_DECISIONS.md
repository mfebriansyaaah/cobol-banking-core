# Gate 0 decision list

Status: checklist. Nothing here is approved until the named owners sign
it; code stays closed (fail-closed defaults, owner-controlled data, no
production wiring) while any item is open.

Decision log: item 17 (technical target runtime) was decided by the repository
owner on 2026-10-21. It is a technical architecture decision and does not
satisfy G0-SIGNOFF; all other items remain open.

Consolidated status, input checklist, and proposed technical defaults:
`docs/GATE0_PACKET.md`.

Owner posture (2026-10-21): target production berlisensi, full product scope,
technical defaults deferred. This is an intent, not an approval; items 1-16
remain open and require the inputs in the packet.

Batch 1 interview inputs (2026-10-21): PT Flopay Teknologi Indonesia;
Indonesia; license 28/145/DKSP/Srt/B (Izin Penyelenggara Uang Elektronik dan
Transfer Dana), active 2026-05-12; supervised by Bank Indonesia and OJK;
e-money and transfer; IDR + USD; Retail + SME; Indonesia only; daily + monthly
internal EOD; monthly LBPUE through the BI-Antasena API in XML/XBRL; target
launch Q1 2027. Named owners: Compliance Muhammad Febriansyah; Legal Sarah
Wijaya; Risk Andi Pratama; Security Hendra Gunawan; Finance Rina Amelia;
Operations Kevin Kusuma. Formal evidence and sign-offs are pending.

Batch 2 interview inputs (2026-10-21): KYC in-house with Dukcapil; sanctions/PEP
Dow Jones; transaction monitoring in-house COBOL rules; fraud operations 24/7
in-house; limits IDR 25m/txn and 50m/day, USD 5k/txn and 10k/day; fee
IDR 2,500/txn; risk-based auto hold; FX residual materiality 0.01; SLO 99.95%
with read p95 200ms and transfer p95 400ms; RPO 5m/RTO 1h; patch 3/14/30 days;
retention 7y/90d/30d; on-call 24/7; reports LBPUE + trial balance; release
approvers owner + CISO + COO + Compliance; ADR 0072 D1/D2/D3 accepted as
implemented. Formal evidence and sign-offs are pending. Sources: `docs/TRACEABILITY.md`
(Gate 0 rows), `PRD_Enterprise.md` section 3, `docs/adr/0072-fx-fee-rate-policy.md`.

How to use this file: for each item, fill Owner, Decision, and Date.
`UNASSIGNED`/`TBD` means blocked. When an item is signed, update the
corresponding `docs/TRACEABILITY.md` row (owner + approval record) in the
same PR that implements the unblocked work.

## 1. Jurisdiction, legal entity, license (blocks everything)

- **Decision:** PT Flopay Teknologi Indonesia; Indonesia; license
  28/145/DKSP/Srt/B (Izin Penyelenggara Uang Elektronik dan Transfer Dana),
  active, issued 2026-05-12; supervised by Bank Indonesia and OJK; products
  e-money and transfer; currencies IDR + USD; monthly LBPUE through the
  BI-Antasena API in XML/XBRL.
- **Owner:** Muhammad Febriansyah (Chief Compliance Officer) and Sarah Wijaya
  (VP of Legal Affairs).
- **Date:** 2026-10-21 (owner input recorded; formal evidence and sign-off
  pending).
- **Unblocks:** G0-ENTITY, subject to the license certificate and sign-off.
- **Note:** owner-provided input, not an independent verification. The license
  certificate and formal approvals belong in the private evidence store.

## 2. Accountable owners and sign-off records (blocks everything)

- **Decision:** named owners recorded: Compliance Muhammad Febriansyah (CCO);
  Legal Sarah Wijaya (VP Legal Affairs); Risk Andi Pratama (CRO); Security
  Hendra Gunawan (CISO); Finance Rina Amelia (CFO); Operations Kevin Kusuma
  (COO).
- **Owner:** each named owner for their domain; the repository owner for the
  technical runtime decision.
- **Date:** 2026-10-21 (named; formal sign-off pending).
- **Unblocks:** G0-SIGNOFF, subject to signatures.
- **Note:** formal sign-offs belong in the private evidence store. The earlier
  provisional decision by `nineboll07` on 2026-10-18
  (`docs/adr/0072-fx-fee-rate-policy.md`) still needs the licensed entity's
  compliance and finance owners to ratify it.

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
