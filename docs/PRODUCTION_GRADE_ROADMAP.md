# Production-grade roadmap: curated COBOL >60% after cut-over

## 0. Progress (auto-tracked)

| PR | Branch | Status |
|---|---|---|
| PR-01 | `phase-1/kyc-risk` | done (slice 30) |
| PR-02 | `phase-1/fraud-reporting` | done (slice 31) |
| PR-03 | `phase-1/limits-fees` | done (slice 33) |
| PR-04 | `phase-2/cutover-observability` | partial (observability modules done; generated cut-over pending) |
| PR-05 | `phase-3/security-data-cert` | done (this slice) |

Status is derived from merged slices and the module files present under
`cobol/src/`. Run `./scripts/progress_report.sh` for the live view and
`./tests/progress_check.sh` for the CI gate.

This is the executable PR plan for adding curated COBOL without growing the
generated module, then finishing the production-grade phases. Each code PR
has **at least two modules**; a PR may carry three or four when the modules
belong to one domain and the combined net stays reviewable.

## 1. Current baseline (2026-10-23)

| Metric | Value |
|---|---:|
| Non-generated net | 100,488 |
| Curated COBOL net | 49,832 |
| Generated COBOL net | 52,134 |
| Total COBOL net | 101,966 |
| Curated share | 48.8% |
| CI | 130 steps, ALL GREEN |
| COBOL coverage | 75.35% |

## 2. Owner decisions (recorded 2026-10-23)

1. **Share timing:** curated COBOL exceeds 60% **after** generated is removed.
2. **Modules per PR:** minimum **two**, more allowed; group by domain.
3. **Required traceability:** `A-P0-CDD`, `C-P0-RISK`, `C-P1-FRAUDOPS`,
   `D-P1-REPORTS`, `F-P0-RESIL`.
4. **Gate 0 sign-off is available** and is attached in the final PR.
5. **Merge policy:** merge-commit, reviewer is the repository owner.
6. **Optional:** `F-P0-SECOPS`, `F-P1-DATA` may be folded into the final PR;
   otherwise they stay owner-attested in `docs/TRACEABILITY.md`.

## 3. Target

| Metric | Target |
|---|---:|
| Curated COBOL before cut-over | **>= 60,000** |
| Curated share after cut-over | **> 60%** (100% once generated is removed) |
| Total COBOL after cut-over | **>= 60,000** |
| Generated COBOL after cut-over | **0** |
| Non-generated net | **>= 100,000** |
| Each code PR | **>= 2 modules**, combined net 5,000-9,000 |

Three volume PRs of three modules each add about **18,000** curated net
(49,832 -> ~67,832). Two later PRs add about **8,000** more. After the
generated module is removed the curated share is **100%** and total COBOL
stays well above the 60,000 floor.

## 4. Execution rules

- One PR = at least two COBOL modules plus schema, routes, tests, CI wiring,
  coverage, baselines, and docs.
- Branch from `main`; one push; one owner review; **merge-commit**.
- Every PR ends with `./ci.sh` **ALL GREEN** and
  `./scripts/finalize_slice.sh --check` clean.
- No new generated code; `cobol/src/generated/ref_core.cob` never grows.
- Runtime target stays GnuCOBOL/MySQL/Linux (portable-core ADR).
- Owner approvals: `docs/APPROVALS.md`; signed evidence stays private.

## 5. PR sequence at a glance

| PR | Branch | Modules | Count | Est. net | Covers |
|---|---|---|---:|---:|---|
| PR-01 | `phase-1/kyc-risk` | `kyc_core`, `risk_screening_core`, `sanctions_hold_core` | 3 | 6,000 | A-P0-CDD, C-P0-RISK |
| PR-02 | `phase-1/fraud-reporting` | `fraud_ops_core`, `lbpue_core`, `trial_balance_core` | 3 | 6,000 | C-P1-FRAUDOPS, D-P1-REPORTS |
| PR-03 | `phase-1/limits-fees` | `limit_profile_core`, `fee_waiver_core`, `velocity_tier_core` | 3 | 6,000 | C-P0-LIMITS |
| PR-04 | `phase-2/cutover-observability` | `slo_report_core`, `pipeline_alert_core` | 2 | 4,000 | F-P0-RESIL, generated cut-over |
| PR-05 | `phase-3/security-data-cert` | `legal_hold_core`, `key_rotation_core`, `dsar_core`, `retention_job_core` | 4 | 8,000 | F-P0-SECOPS, F-P1-DATA, Gate 0 sign-off |

After PR-01..PR-05, curated COBOL is about **79,832** and generated is gone,
so curated share is **100%** and total COBOL is far above 60,000.

## 6. PR-01 - KYC, risk screening, sanctions hold

- **Branch:** `phase-1/kyc-risk`
- **Modules:** `kyc_core.cob`, `risk_screening_core.cob`, `sanctions_hold_core.cob`
- **Migration:** 
- **Routes:** , 
- **Tests:** `test_kyc.sh`, `test_risk_screening.sh`, `test_sanctions_hold.sh`
- **Commits:**
  1. `feat(kyc): add case, evidence, and decision core`
  2. `feat(risk): add profile and screening core`
  3. `feat(risk): add sanctions-hold core`
  4. `test(kyc-risk): cover review, screening, PEP, and hold outcomes`
  5. `chore(ci): wire KYC, risk, and sanctions suites`
  6. `docs(status): record slice KYC and risk screening`
- **Acceptance:** risk class per customer, screening hits fail closed to a
  hold, no self-approval, consent and retention recorded, all transitions
  audited.

## 7. PR-02 - Fraud operations, LBPUE, trial balance

- **Branch:** `phase-1/fraud-reporting`
- **Modules:** `fraud_ops_core.cob`, `lbpue_core.cob`, `trial_balance_core.cob`
- **Migration:** 
- **Routes:** , 
- **Tests:** `test_fraud_ops.sh`, `test_lbpue.sh`, `test_trial_balance.sh`
- **Commits:**
  1. `feat(fraud): add review queue and rule-version core`
  2. `feat(fraud): add dual-control override core`
  3. `feat(report): add LBPUE and trial balance core`
  4. `test(fraud-report): cover false positive, override, and report mapping`
  5. `chore(ci): wire fraud, LBPUE, and trial balance suites`
  6. `docs(status): record slice fraud operations and reporting`
- **Acceptance:** override needs a second approver, rule versions immutable,
  LBPUE and trial balance reconcile to the GL, layout owner-approved.

## 8. PR-03 - Limits, fee waiver, velocity tiers

- **Branch:** `phase-1/limits-fees`
- **Modules:** `limit_profile_core.cob`, `fee_waiver_core.cob`, `velocity_tier_core.cob`
- **Migration:** 
- **Routes:** , 
- **Tests:** `test_limit_profile.sh`, `test_fee_waiver.sh`, `test_velocity_tier.sh`
- **Commits:**
  1. `feat(limit): add per-customer profile core`
  2. `feat(fee): add waiver request and approval core`
  3. `feat(limit): add velocity tier core`
  4. `test(limits-fees): cover profiles, waivers, and velocity enforcement`
  5. `chore(ci): wire limit, fee, and velocity suites`
  6. `docs(status): record slice limits and fees`
- **Acceptance:** no self-approval, changes effective-dated, posting path
  honours the active profile, fail closed at every boundary.

## 9. PR-04 - Cut-over and observability

- **Branch:** `phase-2/cutover-observability`
- **Modules:** `slo_report_core.cob`, `pipeline_alert_core.cob`
- **Migration:** 
- **Routes:** 
- **Tests:** `test_slo_report.sh`, `test_pipeline_alert.sh`, extended
  `test_ref_engine.sh` cut-over parity
- **Commits:**
  1. `refactor(ref): route actions to curated modules`
  2. `refactor(ref): remove generated ref_core fallback`
  3. `test(ref): add cut-over parity suite`
  4. `feat(obs): add SLO report core`
  5. `feat(obs): add pipeline-failure alert core`
  6. `test(obs): cover alert dedupe and SLO budget burn`
  7. `chore(build): drop the generated module from the build`
  8. `docs(status): record cut-over and 100% curated share`
- **Acceptance:** zero generated code; reference parity green; curated share
  reads 100%; total COBOL >= 60,000; SLO alerts fire on induced failure.

## 10. PR-05 - Security, data governance, certification

- **Branch:** `phase-3/security-data-cert`
- **Modules:** `legal_hold_core.cob`, `key_rotation_core.cob`,
  `dsar_core.cob`, `retention_job_core.cob`
- **Migration:** 
- **Routes:** , ,
  , 
- **Tests:** `test_legal_hold.sh`, `test_key_rotation.sh`, `test_dsar.sh`,
  `test_retention_job.sh`
- **Commits:**
  1. `feat(security): add legal hold core`
  2. `feat(security): add key rotation schedule core`
  3. `feat(data): add DSAR export and erase core`
  4. `feat(data): add retention job core`
  5. `test(security-data): cover holds, rotation windows, DSAR, retention`
  6. `docs(assessment): attach independent assessment findings`
  7. `docs(assessment): record pilot results and remediation`
  8. `docs(approvals): attach Gate 0 sign-off evidence index`
  9. `docs(status): close production-grade phases`
- **Acceptance:** legal hold blocks deletion, rotation overlap bounded and
  audited, DSAR scoped to the subject, retention idempotent, all required
  traceability items implemented or explicitly deferred by an owner.

## 11. Traceability coverage map

| Open item | Covered by | Status target |
|---|---|---|
| A-P0-CDD | PR-01 | implemented + owner-approved |
| C-P0-RISK | PR-01 | implemented + owner-approved |
| C-P1-FRAUDOPS | PR-02 | implemented + owner-approved |
| D-P1-REPORTS | PR-02 | implemented + owner-approved |
| F-P0-RESIL | PR-04 | evidence attached |
| F-P0-SECOPS | PR-05 | assessment attached |
| F-P1-DATA | PR-05 | implemented |
| Gate 0 sign-offs | PR-05 | evidence index attached |

## 12. Per-PR execution checklist

1. `./scripts/sync_main.sh <branch>`
2. Implement every module in the PR, migration, routes, and tests.
3. `./build.sh && ./tests/static_checks.sh && ./tests/status_check.sh`
4. Targeted suites and `./tests/test_migrate.sh`
5. `./scripts/finalize_slice.sh`
6. `./ci.sh` until ALL GREEN
7. Commit atomically (one commit per module, then tests/CI/docs)
8. `git push -u origin <branch>`
9. `gh pr create` with module list and CI evidence
10. Owner review, **merge-commit**, then prune the branch

## 13. Definition of done

- Curated COBOL **>= 60,000** before cut-over and **100% share** after.
- `cobol/src/generated/ref_core.cob` removed; no generated code remains.
- Required traceability items implemented and owner-approved.
- `./ci.sh` ALL GREEN on the final commit of every PR.
- `docs/STATUS.md`, `README.md`, `docs/DELIVERY_RULES.md`, and baselines
  synchronized by `./scripts/finalize_slice.sh`.
