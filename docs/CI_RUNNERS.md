# CI runner capacity & pinning proposal (CI-015, revived)

Status: **proposal** (needs repo-owner decision). Replaces the deferred CI-015
scope item from the CI improvement master plan (out of scope at v1.1).

## Problem (measured 2026-11-07, not assumed)

PR wall p50 is 6m51s against the <=6m G1 target, while cost per PR keeps
_falling_ (job-min 29 -> 18). Wall up + cost down = the runs are not slower,
they are **waiting**:

| Job (run 42336537277, created 04:01:00Z) | Started   | Wait               |
| ---------------------------------------- | --------- | ------------------ |
| lint / build / changes                   | 04:01:03Z | ~3s (no queue)     |
| db-snapshot (needs build)                | 04:01:56Z | dependency         |
| db shard 0/1, test, coverage-pr          | 04:04:51Z | **~2-4 min queue** |

The four heavy jobs all start in the same second: that is a batch of runners
freeing up, not dependencies finishing. Estimated queue tax: **~2-3 min per
full PR run** — exactly the G1 gap (+51s) plus headroom.

Repo growth since baseline (2026-11-05) adds real load on top: 46 -> 63 DB
suites, 47 -> 66 modules, 548 -> 568 gateway definitions. Workflow design is
not the bottleneck (docs-only PR wall: 66s, proven in #585).

## Options

### A. Confirm ceiling first, then raise concurrency (recommended first step)

Check the account/organization concurrent-job usage during peak PR hours
(Settings -> Billing, or the Actions usage graph). If queued jobs coincide
with the 20-job hosted limit, the fix is administrative, not code:

- Move heavy, cache-friendly jobs (lint, build) to `ubuntu-latest` large
  runners **or** add a second hosted pool — whichever the billing owner
  approves. No workflow logic changes; only `runs-on` labels.
- Expected effect: wall -2-3 min (queue tax removed), job-min unchanged,
  public-repo billing unaffected within fair use.
- Risk: low. Rollback: revert the `runs-on` labels.

### B. Pin runner images (reproducibility; original CI-015 intent)

Replace `ubuntu-latest` with a dated image
(`ubuntu-24.04` dated snapshot) plus a quarterly bump calendar. This does
**not** add capacity — it removes a variance source (a runner image refresh
once moved sqlite/openssl behavior under a green tree). Cheap, do regardless
of A. Risk: stale images if the bump calendar slips; mitigate with a
Dependabot-style quarterly reminder and the existing contract test
(`runs-on` allowlist).

### C. Self-hosted runners (only if A is insufficient or rejected)

Full control and warm caches (persistent GnuCOBOL build cache, warm MariaDB
images), but real costs for a **public** repo: fork PRs must never reach
self-hosted runners (exfiltration risk) — restrict them to `push`/`main`
and internal PRs, keep PRs from forks on hosted. Maintenance owner required
(OS patching, disk/GC, log redaction audit). Pilot on `lint`+`build` only,
evaluate 2 weeks, then decide. Do not start here.

## Recommended sequence

1. **Measure (0.5 day):** confirm queue-vs-dependency split across 10 full
   PR runs (created_at vs job started_at, as above). If queue tax < 60s
   median, stop — accept the ~7m baseline instead.
2. **Pin images (0.5 day):** option B, one PR, contract test update.
3. **Raise concurrency (owner decision):** option A for the heavy fan-out
   jobs only (db shards, test, coverage-pr). Success = PR p50 <= 6m over the
   next 20 runs with no failure-rate increase.
4. **Revisit C** only with data showing A insufficient.

## Acceptance

- PR wall p50 <= 6m sustained (20-run sample, same collector).
- No gate weakened; no baseline changed without reason (see plan invariants).
- Billing owner signs off on any runner-tier change; evidence linked here.

## Relation to G1

This proposal closes the recorded G1 exception (PR p50 +51s). Until it
lands, the exception stands and the ~7m baseline is accepted as the
capacity-bound (not design-bound) wall.
