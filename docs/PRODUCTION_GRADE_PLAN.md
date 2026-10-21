# Production-grade transition plan

Status: **owner-attested for the production scope**; signed evidence is
retained in the private evidence store. This is the engineering plan that
tracks implementation and evidence.

Owner: repository owner and the named Gate 0 owners (see
`docs/GATE0_PACKET.md`).
Related: `PRD_Enterprise.md`, `docs/TRACEABILITY.md`,
`docs/adr/0081-production-grade-transition.md`, `CODING_STANDARDS.md`.

## 1. Context

The October 2026 volume sprint reached a size milestone:

| Metric | Value |
|---|---:|
| Total raw lines | 109.344 |
| Total net lines | 101.200 |
| COBOL raw lines | 64.703 |
| COBOL net lines | 62.544 |
| COBOL raw share | 59,2% |
| COBOL net share | 61,8% |
| Generated reference entities | 211 |
| Generated reference actions | 1.055 |
| Reference smoke suites | 211 |
| Reference assertions | 2.321 |

That milestone is a **historical volume artifact**. It is not a production
control, a compliance claim, or a reason to keep 211 near-identical CRUD modules. The
production-grade transition replaces the generated volume with curated domain
code while keeping the COBOL net floor intact.

## 2. Goals and non-goals

### Goals

1. Keep **COBOL net at or above 60.000 lines** for the entire transition.
2. Raise the **curated COBOL share** from roughly 16% to 100% through a
   ratcheted gate.
3. Replace 211 generated reference entities with a **generic reference-data
   model** plus a small set of curated domains.
4. Reach production-grade evidence: full CI, coverage, security, reliability,
   observability, data governance, and change control.
5. Keep the total codebase at or above 100.000 net lines while improving the
   composition.

### Non-goals

- Adding lines for their own sake or inflating comments/blank lines.
- Claiming regulatory readiness before Gate 0 decisions and owner sign-off.
- Rewriting the whole codebase in one change.
- Treating `scripts/ci-7d.sh` as a production gate; it is a volume-sprint gate.

## 3. Definitions and measurement

- **Net SLOC**: non-blank, non-comment lines. Measured by
  `scripts/loc_report.sh`.
- **Curated code**: hand-written or explicitly reviewed domain code in
  `cobol/src/core/` and `cobol/src/modules/`, with a named owner and tests.
- **Generated code**: output of `scripts/gen_entity.mjs`, tagged
  `@generated`, isolated in `cobol/src/generated/`, and excluded from the
  production coverage target.
- **COBOL floor**: 60.000 net COBOL lines.
- **Curated share**: curated COBOL net / total COBOL net.
- **Generated share**: generated COBOL net / total COBOL net.

Current composition (approximate, measured before isolation):

| Component | Net COBOL | Curated share |
|---|---:|---:|
| Core (auth, wallet, user, main) | 9.150 | curated |
| Generated reference module | 53.394 | generated |
| **Total** | **62.544** | **14,6%** |

Target composition:

| Curated module | Target net COBOL |
|---|---:|
| Ledger, journal, posting, reconciliation | 14.000 |
| Payments, transfer, hold, reversal, fee, limit | 12.000 |
| Batch/EOD, scheduler, checkpoint, control totals | 10.000 |
| Report and statement engine | 8.000 |
| Generic reference-data engine | 8.000 |
| Auth, identity, session, access review | 8.000 |
| User, profile, dispute, notification | 5.000 |
| Import/export, data migration | 4.000 |
| **Total curated** | **69.000** |

Non-COBOL (SQL, JavaScript, shell) target: ~35.000 net. Total target:
~104.000 net, COBOL ~66%.

## 4. The no-net-loss rule

1. **Add before delete.** Replacement code lands before generated code is
   removed.
2. Every pull request reports the net COBOL delta and curated-share delta.
3. A deletion of 1.000 net COBOL lines or more requires replacement curated
   lines in the same change, or an approved follow-up with a named owner and
   date.
4. `scripts/loc_report.sh --check-floor` is a merge gate: it fails when COBOL
   net is below 60.000 or when curated share regresses.
5. Temporary dips are allowed only with an approved exception recorded in the
   pull request; the floor must be restored before the next release.

Worked example:

| Phase | Curated net | Generated net | Total COBOL | Floor |
|---|---:|---:|---:|---|
| Baseline | 9.800 | 52.744 | 62.544 | pass |
| Build replacements | 49.800 | 52.744 | 102.544 | pass |
| Cut over 100 entities | 57.800 | 27.744 | 85.544 | pass |
| Cut over the rest | 65.800 | 0 | 65.800 | pass |
| Final curated modules | 69.000 | 0 | 69.000 | pass |

The floor is a constraint, not the objective. The objective is curated,
reviewable, operable code.

## 5. Reference-data consolidation

Current state: 211 tables with a uniform shape
(`code`, `label`, `num_val`, `is_active`) and 1.055 actions. This does not
model effective dating, approval, hierarchy, translations, provenance, or
lifecycle.

Target model:

| Table | Purpose |
|---|---|
| `ref_type` | Domain: currency, country, holiday, fee code, ... |
| `ref_value` | Code, label, sort order, attributes |
| `ref_value_version` | Effective from/to, status, approval, version |
| `ref_translation` | Locale-specific labels |
| `ref_hierarchy` | Parent/child relationships |
| `ref_audit` | Change history and actor attribution |

COBOL actions: `REF_LIST`, `REF_GET`, `REF_CREATE`, `REF_UPDATE`,
`REF_APPROVE`, `REF_RETIRE`, `REF_HISTORY`, `REF_IMPORT`, `REF_EXPORT`.

Keep specialized tables only for high-value domains: currencies, exchange
rates, fee schedules, limits, GL accounts, holidays, and product parameters.
All other domains become metadata rows, not tables.

Cutover is per domain: add the generic engine and curated domain, migrate the
data, verify the smoke suite, then remove the generated block. The COBOL floor
is checked after each cutover.

## 6. Production workstreams

| Workstream | Deliverables | Exit criterion |
|---|---|---|
| Correctness | Invariants for ledger, FX, rounding, idempotency, concurrency; property-based and mutation tests | Money-path coverage >= 90%; zero unexplained reconciliation differences |
| Architecture | Module boundaries, copybooks, online/batch/report split, framed protocol, generic reference engine | No generated code in production scope; protocol and module ADRs approved |
| Security | Threat model, SAST/DAST, dependency scanning, SBOM, secrets manager, TLS, least privilege, pen test | No open critical/high findings; independent assessment scheduled |
| Reliability | SLOs, error budgets, HA, failover, backup/restore drills, chaos tests | SLO met for one full quarter; DR drill within RPO/RTO |
| Performance | Load and soak tests, capacity model, query/index review, pool sizing | p95/p99 targets met at approved peak |
| Observability | Correlation IDs, structured logs, RED/USE metrics, traces, dashboards, alerts | Every critical path has a dashboard and an alert |
| Data governance | Data dictionary, lineage, classification, retention, legal hold, PII masking | Owner-approved data policy and evidence |
| Delivery and process | CI/CD, branch protection, CODEOWNERS, release gates, on-call, postmortems | Change control and release evidence approved |

## 7. Phases

### Phase 0 - Freeze and baseline (2 weeks)

- Tag `milestone/100k-60k`.
- Move the generated module to `cobol/src/generated/` and tag it `@generated`.
- Add `scripts/loc_report.sh --check-floor` to the merge gate.
- Run the full `./ci.sh`; fix every failure.
- Target runtime decided: GnuCOBOL/MySQL/Linux under portable-core constraints (`docs/adr/0082-target-runtime.md`); operations/security ratification pending.
- Write the data dictionary and the initial risk register.

Exit: full CI green, floor gate active, runtime decision recorded.

### Phase 1 - Build replacements (6-8 weeks)

Status 2026-10-21: the generic reference-data engine is implemented (schema,
COBOL actions, gateway routes, and an 18-assertion suite). Country and holiday
are cut over; 209 generated entities remain for later cutover.

- Generic reference-data engine.
- Ledger/GL module, batch/EOD engine, report engine, import/export.
- Dockerfile, docker-compose, CI/CD, SAST/SBOM, correlation IDs.
- Load-test baseline and the first backup/restore drill.

Exit: replacement modules merged; COBOL net above 60k; curated share rising.

### Phase 2 - Cut over and harden (8-12 weeks)

- Migrate reference domains, remove generated blocks.
- HA/failover, performance tuning, chaos tests.
- Pen test and remediation.
- Data governance, retention, lineage, PII controls.
- On-call, incident runbook, postmortems.

Exit: zero generated production code; SLO/DR evidence; pen-test remediation.

### Phase 3 - Certify and pilot (3-6 months)

- Independent security and compliance assessment.
- Owner approvals recorded in `docs/APPROVALS.md`; implementation and assessment evidence tracked separately.
- Pilot with synthetic data; production readiness review.
- Gate 3/4 owner sign-off.

Exit: owner approvals recorded and implementation evidence complete; CI alone is not the approval.

## 8. Quality gates

1. **Floor**: COBOL net >= 60.000.
2. **Curated share**: ratchet 40% -> 50% -> 60% -> 70% -> 100%.
3. **Full CI**: `./ci.sh` green on every release candidate.
4. **Coverage**: money paths >= 90%, overall >= 70% for curated code.
5. **Security**: SAST, DAST, dependency scan, SBOM, secret scan, pen test.
6. **Reliability**: SLO evidence, RPO/RTO, backup/restore drill.
7. **Data**: dictionary, lineage, classification, retention, PII masking.
8. **Release**: `docs/release-checklist.md` completed with owner approvals.

## 9. Metrics dashboard

| Metric | Target | Source |
|---|---|---|
| COBOL net | >= 60.000 | `scripts/loc_report.sh` |
| Curated share | ratchet to 100% | planned quality report (Phase 0) |
| Generated share | -> 0% | planned quality report (Phase 0) |
| Duplication ratio | < 3% | COBOL paragraph hash |
| Money-path coverage | >= 90% | `scripts/coverage_cobol.sh` |
| Overall coverage | >= 70% | coverage gate |
| Build time | < 5 minutes | CI |
| Full CI time | < 15 minutes | CI |
| p95 latency | owner-approved SLO | load test |
| Error budget burn | < 1x | monitoring |
| Open critical/high findings | 0 | security scan |

## 10. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Refactor drops COBOL below 60k | Goal conflict | Add-before-delete and floor gate |
| Generated code remains in production | Quality and audit risk | Isolation, `@generated`, cutover plan |
| Coverage gate fails after generated code | CI red | Exclude generated code; re-baseline curated coverage |
| Full CI too slow | Delivery bottleneck | Tiered CI, parallel jobs, split modules |
| Target runtime undecided | Rework | Phase 0 ADR and owner decision |
| Compliance scope unknown | False claims | Gate 0 decisions; no production claims |
| Team capacity | Slower phases | Phase scope and named owners |

## 11. First ten actions

1. Tag `milestone/100k-60k`.
2. Add `--check-floor` to `scripts/loc_report.sh`.
3. Keep the generated module isolated under `cobol/src/generated/` with an `@generated` marker.
4. Run and fix the full `./ci.sh`.
5. Accept the target-runtime ADR (0082).
6. Build the generic reference-data engine.
7. Add one curated replacement module (ledger/GL) before deleting generated code.
8. Add Dockerfile, compose, and CI/CD.
9. Add correlation IDs, metrics, traces, dashboards, alerts.
10. Run a load test and a backup/restore drill.

## 12. Relationship to the PRD

`PRD_Enterprise.md` section 5 states that repository size, LOC, commit count,
and PR count are not success criteria. This plan preserves the 100k/60k
milestone as a **floor and a historical artifact**, not as a production
success criterion. Production success is measured by the gates above and by
owner-approved evidence.
