# Tiered CI: full release gate and affected-surface fast gate

Status: accepted
Date: 2026-10-20
Phase: development workflow (not a regulatory control).

## Context

The full `./ci.sh` run is 159 steps and about five to seven minutes. Most of that time
is fixed cost rather than feedback: the gateway suite (~65 s), the coverage
gate (~50 s), backup/restore, the C memory suite, migration replay, and the
array of small suites. Waiting five minutes after a one-line change slows
iteration and encourages skipping checks.

The full run must stay the merge and release evidence: it covers the money
path, the C/COBOL boundary, backup/restore, coverage, the hooks, and the
end-to-end HTTP flow. It is not negotiable evidence.

The merge gate restores a representative table slice (`BACKUP_TABLES` in
`ci.sh`), because importing all 454 tables costs ~140s of `CREATE TABLE`
fsyncs. The complete round-trip runs nightly in `scripts/nightly.sh`.

## Decision

1. **Two tiers, one source of truth.** `./ci.sh` remains the full 159-step
   release gate. `./ci-fast.sh` is a new, additive gate for the
   inner loop.
2. **The fast gate is affected-surface.** It diffs the branch against its
   merge base with `origin/main` and runs:
   - always: docs integrity, static checks, build, warning ratchet, migration
     check, and the assertion-count baseline for what it ran;
   - docs-only changes: just the docs/status/traceability/env checks;
   - changes touching `cobol/`, `database/`, `tests/`, `scripts/`, or the CI
     scripts: a twelve-suite money-path and identity smoke set;
   - changes touching `middleware/`: the full 126-test gateway suite.
   With no merge base (fresh or shallow clone) it runs every fast tier, which
   is still much cheaper than the full run.
3. **The fast gate cannot silently lose assertions.** It records the pass
   count of every suite it runs and checks it against the same
   `tests/baseline_counts.txt` manifest through `baseline_check.sh --subset`.
   Deleting an assertion from a suite the gate runs still fails it.
4. **The full run stays the merge evidence.** A pull request is opened only
   after `./ci.sh` is green on the final commit. The fast gate is for
   iterating between commits; it does not replace the full run, and no
   release or merge claim may cite it alone.
5. **The static checks are shared.** The six static COBOL checks moved to
   `tests/static_checks.sh` so both tiers run exactly the same rules (the
   extraction is behavior-preserving; the full CI calls the script as step 2).

## What the fast gate deliberately does not cover

Backup/restore, migration resume and idempotency, the C memory/buffer
contract, coverage measurement, the hook-hygiene and seed suites, the
end-to-end gateway flow, serve mode, and concurrent transfers. A change that
touches those areas still needs the full run before merge; the gate says so
in its header.

## Consequences

- A docs-only change is checked in seconds; a typical COBOL change in under a
  minute; a mixed change in about two minutes (the gateway suite dominates).
- The full run keeps its role and its 159 steps. No assertion, evidence file,
  or coverage floor is removed by this decision.
- `ci-fast.sh` is validated by `bash -n` in the static checks so a syntax
  error cannot hide in the tooling.
