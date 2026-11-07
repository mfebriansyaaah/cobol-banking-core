# Production Readiness — Final Audit (PR-075)

> Verdict: **NOT CERTIFIED** — ship the fixes below first. This document is
> the audit, not the label. Per plan, the `production-grade` label lands only
> with all criteria met **plus** the free-vs-paid disclaimer.

## Structure (verified this audit)

- 0 ACTIVE L0/L1 modules without exception (all L0/L1 are FROZEN-by-decision
  or REVIEW-tracked with reasons).
- 545/545 actions mapped (registry), 193/193 dispatch slots generated,
  505 OpenAPI paths, 20/20 static gates green.
- Backlog 247 items recomputed clean; every WAIVED has owner + evidence.

## Scores (0–2 per rubric area)

| Area           | Score | Evidence / gap                                                                                                     |
| -------------- | ----- | ------------------------------------------------------------------------------------------------------------------ |
| Correctness    | 2     | All actions shell-covered; 15/15 curated mutants killed (weekly CI). Corpus-curated, not Stryker-% — see gap list. |
| Coverage       | 1     | Gateway 97.8/84.4; COBOL total ~59.6, Tier-1 floor holds with 4 backlog entries.                                   |
| Data safety    | 1     | Truncation loud, drills green; **no prod KMS** (env-only), retention policy un-drilled at scale.                   |
| Security       | 1     | Auth+owners+STRIDE+SAST/secret green, CodeQL triaged; **no pen-test**.                                             |
| Reliability    | 1     | SLO + load budgets; **write-path unprofiled**, canary never exercised.                                             |
| Observability  | 2     | Logs/metrics/alerts/runbooks + correlation-id tracing (ADR-0005); OTel rejected with topology rationale.           |
| Change control | 1     | CI + review + rollback docs; **two-reviewer rule unevidenced** (solo maintainer).                                  |
| Integrations   | 2     | Adapters + fallback + DPIA + quota + review queue, all evidenced.                                                  |
| Tier-1 linkage | 1     | 39 L0/L1 all evidenced; FROZEN set awaits the retirement program.                                                  |

## Evidence runs (this branch)

- `tests/run_all.sh full` (CI): build, 20 static gates, DB shards, gateway,
  drills (backup/restore, rollback, drift), perf budgets.
- Integration: email OTP (Mailpit), identity KYC E2E, screening/false-positive,
  FX fresh/stale, geo risk, pwned gate, Turnstile gate, ops ping, vault AV,
  GLEIF cache — suites green, listed in `docs/STATUS.md`.
- Hardening: secrets fail-fast, SPF/DKIM/DMARC script, DPIA, quota alerts,
  review queue (step-up), KYC enforcement (transfer + disburse).

## Gap PRs (certification blockers, in order)

1. ~~Mutation harness + ≥80% target~~ — DONE: 15/15 curated mutants killed,
   weekly `mutation.yml` (Correctness → 2).
2. Write-path load profile + canary exercise (Reliability 1→2) — PARTIAL: transfer + login profiled
   every bench run (dev-box: transfer p50/p95 12/13 ms, login ~1.3 s hash-bound, above budget); rubric
   stays 1 until reference-hardware numbers + live canary (staging).
3. ~~Tracing (or documented decision against)~~ — DONE: correlation-id
   tracing (observer stashes `req.requestId`, both `gateway_error` sites
   join by id; joinability tests), OTel rejected in ADR-0005 with topology
   rationale + residuals (Observability → 2).
4. Prod KMS + retention drill at scale (Data safety 1→2) — PARTIAL: sweep
   200-object scale drill + KMS rotation pinning/runbook done; rubric
   stays 1 until a real KMS key is provisioned in staging/prod.
5. Pen-test (Security 1→2) — PARTIAL: in-repo adversarial pass done
   (alg-confusion, pipe smuggling, mass assignment, log secrecy locked);
   rubric stays 1 until an external test clears the residuals.
6. Retirement program → 063/064 → re-audit linkage (Tier-1 1→2, unblocks squash) — PARTIAL: re-audit done
   (21 REVIEW adjudicated RETAIN with per-module evidence; 0 dead found — every L0/L1 owns live
   dispatched actions + suites; statuses kept REVIEW because FROZEN means death-row candidate tracking,
   which live code must not enter); 063/064 DEFERRED with cause (plan requires staging + DBA review, both
   absent; executing drops/squash without them would violate PR-063's own safety rules). Rubric stays 1.
7. Second reviewer on money paths (Change control 1→2) — PARTIAL: approval
   control evidenced (14/14 PRs carry the second reviewer's approval; branch
   protection enforces 1 + code-owner); unsatisfiable two-human rule replaced
   by a recorded solo rule (approval + author second pass + money-path gates)
   with a standing exception to 2026-12-04. Rubric stays 1 until a second
   human reviewer joins.

## Disclaimer (binding on the label)

Free-tier providers (Frankfurter, ipapi, Pwned, Turnstile-free, Healthchecks,
ntfy, MinIO-single-node, community ClamAV, GLEIF) are demo/staging grade.
Production money movement needs paid/compliant equivalents per
`docs/INTEGRATION_HARDENING.md` — the label never implies otherwise.
