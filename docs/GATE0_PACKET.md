# Gate 0 decision packet

Status: working packet, not an approval record. Every item stays open until the
named owner signs it. `UNASSIGNED`/`TBD` means blocked, not approved.

This packet consolidates the 17 items in `docs/GATE0_DECISIONS.md` with the
input each one needs, a proposed technical default where one is safe, and the
blank fields that only the accountable business owners can fill. It does not
change the traceability matrix or create a compliance claim.

## 1. Status summary

| # | Item | Status | Owner | Input needed | Proposed default | Unblocks |
|---:|---|---|---|---|---|---|
| 17 | Target runtime | Decided (technical) | Repository owner | Operations/security ratification | A - GnuCOBOL/MySQL/Linux (`docs/adr/0082-target-runtime.md`) | Phase 0/1 |
| 1 | Legal entity, license, jurisdiction | Blocked | TBD (legal + compliance) | Entity name, license, jurisdiction, products, currencies | None; cannot be invented | G0-ENTITY and all BLOCKED rows |
| 2 | Accountable owners and sign-off | Blocked | TBD (executive) | Named owners for compliance, legal, risk, security, finance, operations | None | G0-SIGNOFF |
| 3 | Product and customer scope | Blocked | TBD (product + compliance) | Launch products, customer segments, EOD scope | Pilot: internal transfer only, synthetic data | A-P1-LIFECYCLE, B-P1-LIFECYCLE |
| 4 | KYC/CDD design and provider | Blocked | TBD (compliance) | Identification, verification, risk, consent, retention, provider | None; jurisdiction-specific | A-P0-CDD |
| 5 | Sanctions/PEP and monitoring | Blocked | TBD (compliance + risk) | Provider, lists, rules, risk states, escalation | None; jurisdiction-specific | C-P0-RISK |
| 6 | Fraud operations | Blocked | TBD (risk + operations) | Queues, false positives, dual control, rule versioning | None; needs operating model | C-P1-FRAUDOPS |
| 7 | Disaster recovery | Draftable | TBD (operations + security) | RPO/RTO, recovery site, drill schedule | RPO 15 min, RTO 4 h for pilot; see section 2 | F-P0-RESIL (DR leg) |
| 8 | Limits approval basis | Blocked | TBD (risk + finance) | Per-customer/product/channel limits, velocity | Conservative default in section 3; needs approval | C-P0-LIMITS |
| 9 | Regulatory reports and trial balance | Blocked | TBD (finance + compliance) | Report list, formats, trial-balance layout, export rules | Generic trial balance only; no regulatory formats | D-P1-REPORTS |
| 10 | Owner-controlled money data | Blocked | TBD (finance) | Fee amounts, hold policy, FX residual materiality | Seed values are placeholders only | B-P1-LIFECYCLE (fees) |
| 11 | SLOs, load targets, alerts | Draftable | TBD (operations) | Availability, latency, capacity, alert thresholds | Draft in section 2 | F-P0-RESIL (SLO/load) |
| 12 | Patch windows and exception approver | Draftable | TBD (security + operations) | Patch windows, emergency approver | Critical <= 7 days, high <= 30, medium <= 90 | `docs/patch-policy.md` rule 3 |
| 13 | Incident severity and roster | Draftable | TBD (operations) | SEV definitions, paging roster, contacts | Draft in section 2 | F-P0-SECOPS, incident runbook |
| 14 | Data retention, legal hold, keys | Blocked | TBD (legal + compliance + security) | Retention schedule, legal hold, key management | Draft in section 2; legal must approve | F-P1-DATA, D-P0-AUDIT |
| 15 | Release approvals and independent assessment | Draftable | TBD (security + operations) | Approvers, production identity, assessment provider | Draft in section 2 | F-P1-CHANGE, F-P0-SECOPS |
| 16 | ADR 0072 production ratification | Blocked | TBD (compliance + finance) | Ratify D1/D2/D3 for production | Implementation is complete; sign-off missing | FX/fee/rate production use |

## 2. Proposed technical defaults

These are engineering proposals, not approvals. An owner may accept, change, or
reject each one. Record the decision and date in `docs/GATE0_DECISIONS.md`.

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

## 3. Business decisions that cannot be defaulted

These require named accountable owners and, in most cases, a licensed entity
and jurisdiction:

1. Legal entity, license, jurisdiction, permitted products, currencies.
2. Named owners for compliance, legal, risk, security, finance, operations.
3. Launch product scope and customer segments.
4. KYC/CDD design, provider, evidence retention.
5. Sanctions/PEP screening and transaction monitoring.
6. Fraud operations model and dual-control overrides.
7. Approved limits and velocity basis.
8. Regulatory reports and trial-balance format.
9. Fee amounts, hold policy, FX residual materiality.
10. ADR 0072 D1/D2/D3 production ratification.

Until these are signed, the repository remains a development prototype. No
demo, README, or release note may claim production or regulatory readiness.

## 4. Recommended minimum pilot scope

A safe pilot that does not require jurisdiction-specific approvals:

- Synthetic data only; no real customer funds or production customer data.
- Internal transfers between existing synthetic accounts only.
- No external funding, withdrawal, card, or payment rails.
- No KYC, AML, sanctions, fraud, or regulatory reporting claims.
- No production SLO or compliance claim; use the proposal in section 2 as a
  test target only.
- The pilot is an engineering rehearsal, not a licensed product.

This scope unblocks Phase 1/2 engineering while the business decisions remain
open. It does not unblock a production launch.

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
