# CI Failure Triage

Runbook for the automated `ci-failure` issues opened by the `notify` jobs in
`nightly.yml`, `coverage.yml`, `mutation.yml`, and `ci.yml` (push to `main`).

## 1. Open the issue, click the run URL

Each `ci-failure` issue contains the workflow name, event, commit SHA, run
URL, and the failed-jobs payload. Start from the run URL, not from a guess.

## 2. Identify the primary failed job

Ignore cascaded failures. A job is cascaded when one of its `needs`
dependencies also failed in the same run (for example `db aggregate` after
`test`). The issue body lists all needs; the primary job is the one whose
own steps failed while its dependencies succeeded. `scripts/ci/ci_metrics.mjs`
implements the same primary-vs-cascaded split for weekly reports.

## 3. Download the diagnostics artifact

Download `diagnostics-*` for the failed job and read `summary.txt` first:
tool versions, git state, database status, report summary, and gateway log
tails. Do not paste secrets; the collector never records passwords or tokens.

## 4. Reproduce locally

- Fast gate: `bash scripts/ci/premerge.sh`.
- Single DB suite: `tests/run_all.sh db --only <suite>`.
- Gateway suite: `npm --prefix middleware test`.
- Full parity (slow, needs Docker + DB + GnuCOBOL 3.2):
  `PREMERGE_CI_PARITY=1 bash scripts/ci/premerge.sh --ci-parity`.

## 5. Flake or bug

- Flake: add a quarantine entry only with an issue link, owner, reason, and
  expiry. Nightly keeps running the full suite as the detection net; PR runs
  may skip quarantined entries.
- Bug: open a separate issue, link it from the failure issue, and fix via a
  normal PR. Do not mix the fix with unrelated changes.

## 6. Close the loop

A green scheduled run automatically comments `Recovered by run: <url>` and
closes the `ci-failure` issue. If the issue stays open after a green run,
close it manually and note why automation missed it.

## 7. Update the docs when assumptions change

If the root cause changes a CI assumption (job graph, timeout, shard count,
artifact layout, quarantine policy), update `docs/CI.md` in the same PR as
the fix so `scripts/ci/check_ci_docs.mjs` stays green.
