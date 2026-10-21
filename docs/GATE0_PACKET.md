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

- Legal entity: **PT Flopay Teknologi Indonesia**.
- Jurisdiction: **Indonesia**.
- License: **28/145/DKSP/Srt/B**, Izin Penyelenggara Uang Elektronik dan
  Transfer Dana; status **active**; issued **12 May 2026**; supervised by
  **Bank Indonesia and OJK**.
- Permitted products / currencies: e-money and transfer; **IDR + USD**.
- Customer segments: **Retail + SME**.
- Operating countries: **Indonesia only**.
- End-of-day / reporting: daily + monthly internal; monthly **LBPUE** through
  the **BI-Antasena API** in **XML/XBRL**.
- Target launch: **Q1 2027**.
- Named owners: Compliance Muhammad Febriansyah; Legal Sarah Wijaya; Risk Andi
  Pratama; Security Hendra Gunawan; Finance Rina Amelia; Operations Kevin
  Kusuma.
- Batch 2 (2026-10-21): KYC in-house + Dukcapil; sanctions/PEP Dow Jones;
  transaction monitoring in-house COBOL rules; fraud operations 24/7 in-house;
  limits IDR 25m/txn and 50m/day, USD 5k/txn and 10k/day; fee IDR 2,500/txn;
  risk-based auto hold; FX residual materiality 0.01; SLO 99.95%, read p95
  200ms, transfer p95 400ms; RPO 5m/RTO 1h; patch 3/14/30 days; retention
  7y/90d/30d; on-call 24/7; reports LBPUE + trial balance; release approvers
  owner + CISO + COO + Compliance; ADR 0072 D1/D2/D3 accepted as implemented.
- Evidence: the license certificate and signed approvals belong in the bank's
  private evidence store; this repository records the decision and the evidence
  reference only. Do not commit identity documents or personal contact details.

## 1. Status summary

| # | Item | Status | Owner | Input needed | Proposed default | Unblocks |
|---:|---|---|---|---|---|---|
| 17 | Target runtime | Decided (technical) | Repository owner | Operations/security ratification | A - GnuCOBOL/MySQL/Linux (`docs/adr/0082-target-runtime.md`) | Phase 0/1 |
| 1 | Legal entity, license, jurisdiction | Decided (owner input) - evidence/sign-off pending | Muhammad Febriansyah (Compliance); Sarah Wijaya (Legal) | License certificate and formal sign-off | PT Flopay Teknologi Indonesia; Indonesia; 28/145/DKSP/Srt/B; active 2026-05-12; BI + OJK | G0-ENTITY |
| 2 | Accountable owners and sign-off | Named - formal sign-off pending | Named owners (see section 3.2) | Signed approvals | Six named owners recorded | G0-SIGNOFF |
| 3 | Product and customer scope | Decided (owner input): full scope; e-money + transfer; Retail + SME; Indonesia; IDR + USD | Compliance + Operations | Final product list, excluded products, compliance scope | LBPUE + internal trial balance; limits below | A-P1-LIFECYCLE, B-P1-LIFECYCLE |
| 4 | KYC/CDD design and provider | Decided (owner input) - implementation pending | Muhammad Febriansyah (Compliance) | Dukcapil integration, risk classification, consent, evidence retention | In-house + Dukcapil | A-P0-CDD |
| 5 | Sanctions/PEP and monitoring | Decided (owner input) - implementation pending | Muhammad Febriansyah (Compliance); Andi Pratama (Risk) | Dow Jones contract, lists, rules, escalation | Dow Jones; in-house COBOL monitoring rules | C-P0-RISK |
| 6 | Fraud operations | Decided (owner input) - implementation pending | Andi Pratama (Risk); Kevin Kusuma (Operations) | Queues, false positives, dual control, rule versioning | 24/7 in-house | C-P1-FRAUDOPS |
| 7 | Disaster recovery | Decided (owner input) - evidence pending | Kevin Kusuma (Operations); Hendra Gunawan (Security) | PITR, recovery site, drill schedule | RPO 5m; RTO 1h | F-P0-RESIL (DR leg) |
| 8 | Limits approval basis | Decided (owner input) - approval pending | Andi Pratama (Risk); Rina Amelia (Finance) | Per-customer/product/channel mapping, velocity | IDR 25m/txn and 50m/day; USD 5k/txn and 10k/day | C-P0-LIMITS |
| 9 | Regulatory reports and trial balance | Decided (owner input) - implementation pending | Rina Amelia (Finance); Muhammad Febriansyah (Compliance) | LBPUE mapping, trial-balance layout, export rules | LBPUE monthly + internal trial balance | D-P1-REPORTS |
| 10 | Owner-controlled money data | Decided (owner input) - approval pending | Rina Amelia (Finance) | Effective dates, fee schedule, hold rules, FX residual | Fee IDR 2,500/txn; risk-based auto hold; FX residual 0.01 | B-P1-LIFECYCLE (fees) |
| 11 | SLOs, load targets, alerts | Decided (owner input) - evidence pending | Kevin Kusuma (Operations) | Load test, dashboards, capacity model | 99.95%; read p95 200ms; transfer p95 400ms | F-P0-RESIL (SLO/load) |
| 12 | Patch windows and exception approver | Decided (owner input) - policy update pending | Hendra Gunawan (Security); Kevin Kusuma (Operations) | Exception approver, emergency procedure | Critical 3d, high 14d, medium 30d | `docs/patch-policy.md` rule 3 |
| 13 | Incident severity and roster | Decided (owner input) - roster pending | Kevin Kusuma (Operations) | SEV definitions, paging roster, contacts | 24/7 on-call; SEV1/2/3 | F-P0-SECOPS, incident runbook |
| 14 | Data retention, legal hold, keys | Decided (owner input) - legal confirmation pending | Sarah Wijaya (Legal); Muhammad Febriansyah (Compliance); Hendra Gunawan (Security) | Legal hold, KMS/HSM, retention evidence | 7y financial/audit; 90d logs; 30d backups | F-P1-DATA, D-P0-AUDIT |
| 15 | Release approvals and independent assessment | Decided (owner input) - assessment pending | Hendra Gunawan (Security); Kevin Kusuma (Operations) | Signed approver matrix, assessment provider | Owner + CISO + COO + Compliance; independent assessment before launch | F-P1-CHANGE, F-P0-SECOPS |
| 16 | ADR 0072 production ratification | Decided (owner input) - ratification pending | Rina Amelia (Finance); Muhammad Febriansyah (Compliance) | Signed finance/compliance ratification | D1/D2/D3 accepted as implemented | FX/fee/rate production use |

Owner mapping is proposed from the roles named on 2026-10-21. Each named owner
must confirm the assignment; this table is not a sign-off.
## 2. Proposed technical defaults (not accepted)

These are engineering starting points, not approvals. The owner deferred the
numbers on 2026-10-21; they will be adjusted after load testing and owner
review. Record the final decision and date in `docs/GATE0_DECISIONS.md`.

### 2.1 Availability and latency (item 11)

| Measure | Pilot proposal | Production target |
|---|---|---|
| API availability | 99.95% monthly | Owner input 2026-10-21 |
| Read p95 | <= 200 ms | Owner input 2026-10-21 |
| Transfer p95 | <= 400 ms | Owner input 2026-10-21 |
| Error rate | < 0.1% of requests | Owner input 2026-10-21 |
| Reconciliation | Zero unexplained differences | Zero unexplained differences |
| Capacity | 2x projected peak | To be approved |

Implementation gaps: load test harness, capacity model, and dashboards are not
yet present. This proposal defines the target, not the evidence.

### 2.2 Backup and disaster recovery (item 7)

| Measure | Pilot proposal | Notes |
|---|---|---|
| RPO | 5 minutes | Requires binlog/PITR; current backup is a full dump |
| RTO | 1 hour | Requires documented restore and DNS/traffic cutover |
| Full backup | Daily | `scripts/backup.sh` |
| Retention | 30 days | Owner-approved retention may differ |
| Restore drill | Quarterly | `tests/test_backup_restore.sh` proves the round-trip |
| DR site | To be decided | No standby environment is provisioned |

Production RPO/RTO must be approved by the bank's operations and risk owners.

### 2.3 Alerts (item 11)

| Signal | Proposed threshold | Action |
|---|---|---|
| API error rate | > 1% for 5 minutes | Page on-call |
| Read p95 latency | > 500 ms for 5 minutes | Page on-call |
| Transfer p95 latency | > 800 ms for 5 minutes | Page on-call |
| Database down | 1 minute | Page on-call |
| Pool queue saturation | > 80% for 5 minutes | Page on-call |
| Reconciliation mismatch | Any | Page finance/operations |
| Backup failure | Any | Page operations |
| Audit/outbox dead-letter | Any new row | Page operations |

Numeric thresholds are proposals until the owner approves them.

### 2.4 Patch and incident (items 12 and 13)

- Critical security patch: <= 3 days.
- High: <= 14 days.
- Medium: <= 30 days.
- Emergency exception approver: CISO (Hendra Gunawan).
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

- Required approvers: repository owner, CISO, COO, and Compliance; finance for
  financial changes.
- Production identity: separate from development; least privilege.
- Independent assessment: required before production, provider TBD.
- Release evidence: `docs/release-checklist.md` completed and attached.
- Rollback: previous revision plus verified backup manifest.

## 3. Required inputs (business decisions)

These require named accountable owners and, because the posture is a licensed
production target, a licensed entity and jurisdiction. Fill the blanks here or
return them in the review thread; do not mark an item complete without evidence.

### 3.1 Legal entity and jurisdiction (item 1)

- Legal entity name: PT Flopay Teknologi Indonesia
- Jurisdiction / country: Indonesia
- License type: Izin Penyelenggara Uang Elektronik dan Transfer Dana
- License number: 28/145/DKSP/Srt/B
- License status and issue date: Active; 12 May 2026
- Regulator(s): Bank Indonesia and OJK
- Permitted products and currencies: e-money and transfer; IDR + USD
- Reporting obligations: daily + monthly internal; monthly LBPUE through the
  BI-Antasena API in XML/XBRL
- Target launch date: Q1 2027
- Evidence reference: license certificate and formal sign-off in the private
  evidence store (reference TBD)

### 3.2 Named owners and sign-off (item 2)

| Role | Name | Contact | Decision date |
|---|---|---|---|
| Compliance | Muhammad Febriansyah (Chief Compliance Officer) | TBD | Named 2026-10-21; sign-off pending |
| Legal | Sarah Wijaya (VP of Legal Affairs) | TBD | Named 2026-10-21; sign-off pending |
| Risk | Andi Pratama (Chief Risk Officer) | TBD | Named 2026-10-21; sign-off pending |
| Security | Hendra Gunawan (Chief Information Security Officer) | TBD | Named 2026-10-21; sign-off pending |
| Finance/accounting | Rina Amelia (Chief Financial Officer) | TBD | Named 2026-10-21; sign-off pending |
| Operations | Kevin Kusuma (Chief Operating Officer) | TBD | Named 2026-10-21; sign-off pending |
| Repository owner (technical) | repository owner | TBD | 2026-10-21 (runtime/posture only) |

### 3.3 Product and customer scope (item 3)

- Launch products (full scope selected): e-money and transfer; final product
  list TBD
- Customer segments: Retail + SME
- Countries and currencies: Indonesia only; IDR + USD
- End-of-day and reporting needs: daily + monthly internal; monthly LBPUE via
  the BI-Antasena API in XML/XBRL
- Excluded products: TBD

### 3.4 KYC/CDD, sanctions, and fraud (items 4-6)

- KYC/CDD design and provider: in-house, with Dukcapil for e-KTP identity
  verification.
- Identification and verification methods: e-KTP/Dukcapil plus internal data;
  detailed flow TBD.
- Risk classification and consent: TBD.
- Evidence retention: TBD; legal/retention owner Sarah Wijaya.
- Sanctions/PEP provider and lists: Dow Jones; list set TBD.
- Transaction-monitoring rules and risk states: in-house COBOL rules; rule
  catalog and thresholds TBD.
- Escalation and case ownership: fraud operations 24/7 in-house; case queue
  ownership TBD.
- Fraud operations model and dual control: 24/7 in-house; dual-control override
  procedure TBD.

### 3.5 Limits and owner-controlled money data (items 8 and 10)

- Per-customer/product/channel limits: IDR 25,000,000 per transaction and
  IDR 50,000,000 per day; USD 5,000 per transaction and USD 10,000 per day;
  segment mapping TBD.
- Velocity basis: rolling 24 hours; count and velocity thresholds TBD.
- Fee amounts and effective dates: IDR 2,500 per transfer; effective date TBD.
- Hold policy: risk-based automatic hold; rule catalog TBD.
- FX residual materiality: 0.01 target currency unit.
- Owner/approver: Andi Pratama (Risk) and Rina Amelia (Finance); formal
  approval pending.

### 3.6 Regulatory reports and trial balance (item 9)

- Required regulator reports and formats: monthly LBPUE through the BI-Antasena
  API in XML/XBRL, plus an internal trial balance.
- Trial-balance layout: TBD.
- Reproducibility and export rules: TBD.
- Finance/compliance approver: Rina Amelia (Finance) and Muhammad Febriansyah
  (Compliance); formal sign-off pending.

### 3.7 Operations, security, and release (items 7, 11-15)

- RPO / RTO target: RPO 5 minutes, RTO 1 hour; PITR and recovery site TBD.
- SLO, latency, and capacity targets: 99.95% availability; read p95 200 ms;
  transfer p95 400 ms; capacity 2x projected peak; load test pending.
- Alert thresholds and on-call roster: API error > 1% for 5 minutes; read
  p95 > 500 ms for 5 minutes; transfer p95 > 800 ms for 5 minutes; database
  down for 1 minute; pool queue > 80% for 5 minutes; any reconciliation
  mismatch; 24/7 on-call.
- Patch windows and emergency approver: critical 3 days, high 14 days, medium
  30 days; emergency exception approver CISO Hendra Gunawan.
- Incident severity definitions: SEV1 financial integrity or full outage;
  SEV2 degraded or critical path down; SEV3 minor; 24/7 roster.
- Retention schedule and legal hold: 7 years for financial and audit records;
  90 days logs; 30 days backups; legal hold and KMS/HSM TBD.
- Release approvers and independent assessment: repository owner, CISO, COO,
  and Compliance; independent assessment before launch; provider TBD.

### 3.8 ADR 0072 production ratification (item 16)

- D1 (FX residual to FX_PNL): accepted as implemented.
- D2 (fee refund by reason): accepted as implemented; refund only for
  BANK_ERROR, customer error retains the fee.
- D3 (24h rate window): accepted as implemented.
- Finance/compliance approver and date: Rina Amelia (Finance) and Muhammad
  Febriansyah (Compliance); formal sign-off pending.

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
| Repository owner (technical) | repository owner |  | 2026-10-21 | Runtime/posture only |
| Compliance | Muhammad Febriansyah |  |  | Named 2026-10-21; formal sign-off pending |
| Legal | Sarah Wijaya |  |  | Named 2026-10-21; formal sign-off pending |
| Risk | Andi Pratama |  |  | Named 2026-10-21; formal sign-off pending |
| Security | Hendra Gunawan |  |  | Named 2026-10-21; formal sign-off pending |
| Finance/accounting | Rina Amelia |  |  | Named 2026-10-21; formal sign-off pending |
| Operations | Kevin Kusuma |  |  | Named 2026-10-21; formal sign-off pending |

Batch 2 inputs were recorded on 2026-10-21. The names above are designations;
the signature and date columns stay blank until formal approval evidence is
attached. A signature approves only the item named next to it. It does not
approve the whole repository or any unlisted control.

## 6. How to close an item

1. Fill the owner, decision, and date in `docs/GATE0_DECISIONS.md`.
2. Update the matching row in `docs/TRACEABILITY.md` (owner + approval record).
3. Attach the evidence named by the item (test, drill, report, or sign-off).
4. Update this packet's status summary.
5. Do not mark an item complete while its evidence is missing.
