# Gate 0 decision packet

Status: working packet, not an approval record. Every item stays open until the
named owner signs it. `UNASSIGNED`/`TBD` means blocked, not approved.

This packet consolidates the 17 items in `docs/GATE0_DECISIONS.md` with the
input each one needs, a proposed technical default where one is safe, and the
blank fields that only the accountable business owners can fill. It does not
change the traceability matrix or create a compliance claim.

## 0. Owner posture (2026-10-21)

The repository owner selected:

- **Gate 0 posture:** target production berlisensi.
- **Product scope:** full product scope.
- **Technical defaults:** deferred; adjust after load test and owner review.
- **Legal entity:** reported as existing; the details are still required in
  section 3.

This raises the Gate 0 bar. It does not close any item, and the repository
remains a development prototype until the items below are signed. The optional
synthetic pilot is an engineering rehearsal, not the target product.

### 0.1 Interview inputs recorded (2026-10-21)

- Jurisdiction: Indonesia.
- License type: payment / e-money; regulator OJK.
- Permitted currencies: IDR + USD.
- Customer segments: Retail + SME.
- Operating countries: Indonesia only.
- End-of-day / reporting: daily + monthly internal; regulator reports TBD.
- Target launch: Q1 2027.
- Still missing: legal entity name, license number/status/date, and named owners.

## 1. Status summary

| # | Item | Status | Owner | Input needed | Proposed default | Unblocks |
|---:|---|---|---|---|---|---|
| 17 | Target runtime | Decided (technical) | Repository owner | Operations/security ratification | A - GnuCOBOL/MySQL/Linux (`docs/adr/0082-target-runtime.md`) | Phase 0/1 |
| 1 | Legal entity, license, jurisdiction | Blocked - entity name/license/owners required | TBD (legal + compliance) | Entity name, license number/status/date, jurisdiction evidence, owners | Partial: Indonesia, payment/e-money, OJK, IDR+USD | G0-ENTITY and all BLOCKED rows |
| 2 | Accountable owners and sign-off | Blocked | TBD (executive) | Named owners for compliance, legal, risk, security, finance, operations | None | G0-SIGNOFF |
| 3 | Product and customer scope | Decided (owner intent): full scope; Retail + SME; Indonesia; IDR + USD | TBD (product + compliance) | Final product list, excluded products, compliance scope | Full scope; daily + monthly EOD; regulator reports TBD | A-P1-LIFECYCLE, B-P1-LIFECYCLE |
| 4 | KYC/CDD design and provider | Blocked | TBD (compliance) | Identification, verification, risk, consent, retention, provider | None; jurisdiction-specific | A-P0-CDD |
| 5 | Sanctions/PEP and monitoring | Blocked | TBD (compliance + risk) | Provider, lists, rules, risk states, escalation | None; jurisdiction-specific | C-P0-RISK |
| 6 | Fraud operations | Blocked | TBD (risk + operations) | Queues, false positives, dual control, rule versioning | None; needs operating model | C-P1-FRAUDOPS |
| 7 | Disaster recovery | Deferred | TBD (operations + security) | RPO/RTO, recovery site, drill schedule | Section 2 is a starting point; owner deferred | F-P0-RESIL (DR leg) |
| 8 | Limits approval basis | Blocked | TBD (risk + finance) | Per-customer/product/channel limits, velocity | Conservative default in section 3; needs approval | C-P0-LIMITS |
| 9 | Regulatory reports and trial balance | Partial input | TBD (finance + compliance) | Report list, formats, trial-balance layout, export rules | Daily + monthly internal; regulator formats TBD | D-P1-REPORTS |
| 10 | Owner-controlled money data | Blocked | TBD (finance) | Fee amounts, hold policy, FX residual materiality | Seed values are placeholders only | B-P1-LIFECYCLE (fees) |
| 11 | SLOs, load targets, alerts | Deferred | TBD (operations) | Availability, latency, capacity, alert thresholds | Section 2 is a starting point; owner deferred | F-P0-RESIL (SLO/load) |
| 12 | Patch windows and exception approver | Deferred | TBD (security + operations) | Patch windows, emergency approver | Section 2 is a starting point; owner deferred | `docs/patch-policy.md` rule 3 |
| 13 | Incident severity and roster | Deferred | TBD (operations) | SEV definitions, paging roster, contacts | Section 2 is a starting point; owner deferred | F-P0-SECOPS, incident runbook |
| 14 | Data retention, legal hold, keys | Blocked | TBD (legal + compliance + security) | Retention schedule, legal hold, key management | Draft in section 2; legal must approve | F-P1-DATA, D-P0-AUDIT |
| 15 | Release approvals and independent assessment | Deferred | TBD (security + operations) | Approvers, production identity, assessment provider | Section 2 is a starting point; owner deferred | F-P1-CHANGE, F-P0-SECOPS |
| 16 | ADR 0072 production ratification | Blocked | TBD (compliance + finance) | Ratify D1/D2/D3 for production | Implementation is complete; sign-off missing | FX/fee/rate production use |

## 2. Proposed technical defaults (not accepted)

These are engineering starting points, not approvals. The owner deferred the
numbers on 2026-10-21; they will be adjusted after load testing and owner
review. Record the final decision and date in `docs/GATE0_DECISIONS.md`.

### 2.1 Availability and latency (item 11)

| Measure | Pilot proposal | Production target |
|---|---|---|
| API availability | 99.9% monthly | To be approved by the bank |
| Read p95 | <= 300 ms | To be approved |
| Transfer p95 | <= 500 ms | To be approved |
| Error rate | < 0.1% of requests | To be approved |
| Reconciliation | Zero unexplained differences | Zero unexplained differences |
| Capacity | 2x projected peak | To be approved |

Implementation gaps: load test harness, capacity model, and dashboards are not
yet present. This proposal defines the target, not the evidence.

### 2.2 Backup and disaster recovery (item 7)

| Measure | Pilot proposal | Notes |
|---|---|---|
| RPO | 15 minutes | Requires binlog/PITR; current backup is a full dump |
| RTO | 4 hours | Requires documented restore and DNS/traffic cutover |
| Full backup | Daily | `scripts/backup.sh` |
| Retention | 30 days | Owner-approved retention may differ |
| Restore drill | Quarterly | `tests/test_backup_restore.sh` proves the round-trip |
| DR site | To be decided | No standby environment is provisioned |

Production RPO/RTO must be approved by the bank's operations and risk owners.

### 2.3 Alerts (item 11)

| Signal | Proposed threshold | Action |
|---|---|---|
| API error rate | > 1% for 5 minutes | Page on-call |
| API p95 latency | > 1 s for 5 minutes | Page on-call |
| Database down | 1 minute | Page on-call |
| Pool queue saturation | > 80% for 5 minutes | Page on-call |
| Reconciliation mismatch | Any | Page finance/operations |
| Backup failure | Any | Page operations |
| Audit/outbox dead-letter | Any new row | Page operations |

Numeric thresholds are proposals until the owner approves them.

### 2.4 Patch and incident (items 12 and 13)

- Critical security patch: <= 7 days.
- High: <= 30 days.
- Medium: <= 90 days.
- Emergency exception approver: TBD (security + operations).
- SEV1: financial integrity, data loss, or full outage; page immediately.
- SEV2: degraded service or a single critical path down; page in business hours
  or per roster.
- SEV3: minor defect or cosmetic issue; normal backlog.
- Incident commander and paging roster: TBD.

### 2.5 Data retention and keys (item 14)

- Financial records: 7 years (jurisdiction-dependent; legal must confirm).
- Audit trail: 7 years, append-only, archive verified.
- Application logs: 90 days, PII redacted.
- Backups: 30 days, encrypted, owner-only access.
- Legal hold: TBD process and owner.
- Key management: TBD KMS/HSM; no production secrets in the repository.
- Data classification and lineage: TBD data dictionary.

### 2.6 Release approvals and assessment (item 15)

- Required approvers: repository owner, security, operations; finance and
  compliance for financial changes.
- Production identity: separate from development; least privilege.
- Independent assessment: required before production, provider TBD.
- Release evidence: `docs/release-checklist.md` completed and attached.
- Rollback: previous revision plus verified backup manifest.

## 3. Required inputs (business decisions)

These require named accountable owners and, because the posture is a licensed
production target, a licensed entity and jurisdiction. Fill the blanks here or
return them in the review thread; do not mark an item complete without evidence.

### 3.1 Legal entity and jurisdiction (item 1)

- Legal entity name: TBD - owner to provide
- Jurisdiction / country: Indonesia
- License type, number, status: Payment / e-money; number, status, and issue date TBD
- Regulator(s): OJK
- Permitted products and currencies: IDR + USD
- Reporting obligations: daily + monthly internal; regulator reporting TBD
- Target launch date: Q1 2027

### 3.2 Named owners and sign-off (item 2)

| Role | Name | Contact | Decision date |
|---|---|---|---|
| Compliance | TBD |  |  |
| Legal | TBD |  |  |
| Risk | TBD |  |  |
| Security | TBD |  |  |
| Finance/accounting | TBD |  |  |
| Operations | TBD |  |  |
| Repository owner (technical) | repository owner |  | 2026-10-21 (runtime/posture only) |

### 3.3 Product and customer scope (item 3)

- Launch products (full scope selected): full product scope (owner intent); final list TBD
- Customer segments: Retail + SME
- Countries and currencies: Indonesia only; IDR + USD
- End-of-day and reporting needs: daily + monthly internal; regulator reports TBD
- Excluded products: TBD

### 3.4 KYC/CDD, sanctions, and fraud (items 4-6)

- KYC/CDD design and provider: ______________________________________
- Identification and verification methods: __________________________
- Risk classification and consent: __________________________________
- Evidence retention: ______________________________________________
- Sanctions/PEP provider and lists: _________________________________
- Transaction-monitoring rules and risk states: _____________________
- Escalation and case ownership: ____________________________________
- Fraud operations model and dual control: __________________________

### 3.5 Limits and owner-controlled money data (items 8 and 10)

- Per-customer/product/channel limits: ______________________________
- Velocity basis: __________________________________________________
- Fee amounts and effective dates: __________________________________
- Hold policy: _____________________________________________________
- FX residual materiality: _________________________________________
- Owner/approver: __________________________________________________

### 3.6 Regulatory reports and trial balance (item 9)

- Required regulator reports and formats: ___________________________
- Trial-balance layout: ____________________________________________
- Reproducibility and export rules: _________________________________
- Finance/compliance approver: _____________________________________

### 3.7 Operations, security, and release (items 7, 11-15)

- RPO / RTO target: ________________________________________________
- SLO, latency, and capacity targets: _______________________________
- Alert thresholds and on-call roster: ______________________________
- Patch windows and emergency approver: ____________________________
- Incident severity definitions: ____________________________________
- Retention schedule and legal hold: ________________________________
- Key management (KMS/HSM): ________________________________________
- Release approvers and independent assessment: ____________________

### 3.8 ADR 0072 production ratification (item 16)

- D1 (FX residual to FX_PNL): ______________________________________
- D2 (fee refund by reason): _______________________________________
- D3 (24h rate window): ____________________________________________
- Finance/compliance approver and date: ____________________________

Until these are signed, the repository remains a development prototype. No
demo, README, or release note may claim production or regulatory readiness.

## 4. Production target scope

The owner selected **full product scope** for a licensed production target. The
pilot-only scope is no longer the target. A synthetic pilot may still be used
as an engineering rehearsal, but it does not satisfy Gate 0.

Full scope requires every item in this packet, including:

- A licensed entity and jurisdiction.
- KYC/CDD, sanctions/PEP, transaction monitoring, and fraud operations.
- Approved limits, fee amounts, hold policy, and FX residual materiality.
- Regulatory reports and a trial balance.
- SLO, load, DR, retention, key management, and independent assessment.
- Owner sign-offs for every row in section 3.

Until those are complete, the repository remains a development prototype. No
production or compliance claim is permitted.

## 5. Sign-off record

| Role | Name | Decision | Date | Notes |
|---|---|---|---|---|
| Repository owner (technical) |  |  |  |  |
| Compliance |  |  |  |  |
| Legal |  |  |  |  |
| Risk |  |  |  |  |
| Security |  |  |  |  |
| Finance/accounting |  |  |  |  |
| Operations |  |  |  |  |

A signature approves only the item named next to it. It does not approve the
whole repository or any unlisted control.

## 6. How to close an item

1. Fill the owner, decision, and date in `docs/GATE0_DECISIONS.md`.
2. Update the matching row in `docs/TRACEABILITY.md` (owner + approval record).
3. Attach the evidence named by the item (test, drill, report, or sign-off).
4. Update this packet's status summary.
5. Do not mark an item complete while its evidence is missing.
