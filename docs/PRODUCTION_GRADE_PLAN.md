# Production readiness plan

Status: **owner-attested for the production scope**; signed evidence is
retained in the private evidence store. This is the engineering roadmap; it is
not a compliance claim.

Owner: repository owner and the named Gate 0 owners (see
`docs/GATE0_PACKET.md`).
Related: `PRD_Enterprise.md`, `docs/DELIVERY_RULES.md`,
`docs/TRACEABILITY.md`, `docs/adr/0081-production-grade-transition.md`,
`CODING_STANDARDS.md`.

## 1. Objective

Run a licensed banking service where all business logic is authoritative in
curated COBOL, with C and JavaScript limited to infrastructure adapters. The
production target is GnuCOBOL/MySQL/Linux under the portable-core constraints
in `docs/adr/0082-target-runtime.md`.

The delivery workflow is mandatory and lives in `docs/DELIVERY_RULES.md`.
Volume is a constraint, not a success criterion: success is owner-approved
evidence for correctness, security, reliability, data governance, and change
control.

## 2. Current state (2026-10-21)

- Current metrics, modules, suites, and baseline: `docs/STATUS.md` and
  `docs/DELIVERY_RULES.md`.
- Generated reference module: **206 entities / 1.030 actions**, isolated under
  `cobol/src/generated/` and tagged `@generated`.
- Curated Phase 1 modules: generic reference engine, GL core (accounts,
  period control, manual and multi-line journals, trial balance), batch/EOD
  foundation, report engine, and import/export staging.
- Full `./ci.sh` is green on the current slice.
- Target runtime ADR accepted; operations/security ratification remains an
  external Gate 0 item.

The generated module is a historical volume artifact. It is not a production
data model and must not grow. It is replaced by the generic reference engine
and curated domains, one cutover at a time.

## 3. Goals and non-goals

### Goals

1. Keep total COBOL net at or above **60.000** while replacing generated code.
2. Raise curated COBOL to at least **50.000** net and **50%** of the
   non-generated codebase.
3. Reach production evidence: full CI, coverage, security, reliability,
   observability, data governance, and owner-approved change control.
4. Keep each delivered slice coherent: two modules, tests, routes, docs, and
   baselines in one review.

### Non-goals

- Claiming regulatory readiness before owner approval and external evidence.
- Rewriting the whole codebase in one change.
- Treating the old volume-sprint gate as a production gate.

## 4. No-net-loss rule

1. **Add before delete.** Replacement curated code lands before generated code
   is removed.
2. Every production-bound change reports the non-generated delta and curated
   share delta.
3. A deletion of 1.000 net COBOL lines or more needs replacement curated lines
   in the same change, or an owner-approved follow-up with a named date.
4. `./scripts/loc_report.sh --check-floor` enforces the COBOL floor and the
   curated-share ratchet.
5. Temporary dips require an approved exception in the PR; the floor must be
   restored before the next release.

## 5. Production workstreams

| Workstream | Deliverables | Exit criterion |
|---|---|---|
| Correctness | Ledger/FX/rounding/idempotency/concurrency invariants; property and mutation tests | Money-path coverage >= 90%; zero unexplained reconciliation differences |
| Architecture | Module boundaries, copybooks, online/batch/report split, framed protocol, generic reference engine | No generated code in production scope; protocol and module ADRs approved |
| Security | Threat model, SAST/DAST, dependency scanning, SBOM, secrets manager, TLS, least privilege, pen test | No open critical/high findings; independent assessment scheduled |
| Reliability | SLOs, error budgets, HA, failover, backup/restore drills, chaos tests | SLO met for one full quarter; DR drill within RPO/RTO |
| Performance | Load and soak tests, capacity model, query/index review, pool sizing | p95/p99 targets met at approved peak |
| Observability | Correlation IDs, structured logs, RED/USE metrics, traces, dashboards, alerts | Every critical path has a dashboard and an alert |
| Data governance | Data dictionary, lineage, classification, retention, legal hold, PII masking | Owner-approved data policy and evidence |
| Delivery | CI/CD, branch protection, CODEOWNERS, release gates, on-call, postmortems | Change control and release evidence approved |

## 6. Phases and gates

### Phase 0 - Baseline and approvals

Completed: generated module isolated and tagged, full CI green, target runtime
ADR accepted, owner approvals recorded in `docs/APPROVALS.md` with external
evidence. Gate 0 items still open are listed in `docs/TRACEABILITY.md`.

### Phase 1 - Curated replacements (current)

Build two-module slices per `docs/DELIVERY_RULES.md`: GL expansion, batch/EOD,
reports, import/export, payments/fees/limits, reference engine, and
auth/user/dispute gaps. Each slice adds tests, routes, migrations, and docs.

Exit: curated modules cover the production scope; total COBOL net >= 60k;
curated share rising; no new generated code.

### Phase 2 - Cut over and harden

Migrate reference domains, remove generated blocks, add HA/failover, tune
performance, run chaos tests, complete data-governance controls, and establish
on-call/incident response.

Exit: zero generated production code; SLO/DR evidence; pen-test remediation.

### Phase 3 - Certify and pilot

Independent security and compliance assessment, synthetic-data pilot,
production-readiness review, and Gate 3/4 owner sign-off.

Exit: owner approvals recorded and implementation evidence complete. CI alone
is not approval.

## 7. Quality gates

1. **Volume**: non-generated baseline never falls; COBOL floor and curated
   share pass `./scripts/loc_report.sh --check-floor`.
2. **Full CI**: `./ci.sh` green on the final commit of every PR.
3. **Coverage**: money paths >= 90%; overall curated coverage ratcheted
   upward; generated code excluded from the production target.
4. **Warnings**: no new warning class or count; `tests/warning_check.sh` green.
5. **Security**: SAST, DAST, dependency scan, SBOM, secret scan, pen test.
6. **Reliability**: SLO evidence, RPO/RTO, backup/restore drill.
7. **Data**: dictionary, lineage, classification, retention, PII masking.
8. **Release**: `docs/release-checklist.md` completed with owner approvals.

## 8. Metrics

| Metric | Target | Source |
|---|---|---|
| Non-generated net | 100.000 | `scripts/loc_report.sh --non-generated` |
| Curated COBOL | >= 50.000 | `scripts/loc_report.sh --quality` |
| Total COBOL floor | >= 60.000 | `scripts/loc_report.sh --check-floor` |
| Curated share | ratchet upward to 100% | `tests/curated_share_baseline.txt` |
| Duplication ratio | < 3% | COBOL paragraph hash |
| Money-path coverage | >= 90% | `scripts/coverage_cobol.sh` |
| Open critical/high findings | 0 | security scan |

## 9. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Refactor drops COBOL below 60k | Goal conflict | Add-before-delete and floor gate |
| Generated code remains in production | Quality/audit risk | Isolation, `@generated`, cutover plan |
| Slice scope drifts | Slow delivery | Two-module rule and interface freeze |
| Full CI too slow | Delivery bottleneck | Parallel local tests, one full CI per PR |
| Compliance scope unknown | False claims | Gate 0 decisions; no production claims |
| Team capacity | Slower slices | Two-module slices, parallel worktrees, one review |

## 10. Relationship to the PRD

`PRD_Enterprise.md` section 5 states that repository size, LOC, commit count,
and PR count are not success criteria. This plan keeps the volume target as a
floor and delivery constraint; production success is measured by the gates
above and owner-approved evidence.
