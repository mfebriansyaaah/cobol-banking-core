# Coverage cadence: nightly, not every merge

Status: accepted
Date: 2026-10-20
Phase: development workflow (not a regulatory control). Extends ADR 0076.

## Context

The coverage gate costs about two minutes: the COBOL measurement rebuilds the
core with instrumentation and runs a ten-suite subset, and the gateway report
runs the 126-test suite again. On every merge this is a large share of the
full run, while the number it enforces (a floor plus a 1pp ratchet) changes
only when code moves — not between two consecutive merges.

The functional evidence a merge needs is the full `./ci.sh` run. Coverage is
trend evidence: it should be checked often enough to catch a slide, and
recorded for release, but it does not need to block every merge.

## Decision

1. **The full CI no longer runs the coverage gate.** `./ci.sh` keeps its
   functional, boundary, migration, backup, and warning evidence and drops
   the two-minute measurement. Its gateway step runs the plain suite (no
   instrumentation), which also removes the coverage-only threshold from the
   merge path.
2. **A nightly job runs the coverage gate.** `scripts/nightly.sh` runs
   `tests/coverage_check.sh` (COBOL statement coverage over the fixed subset
   plus gateway line/branch coverage), writes a timestamped log, and exits
   non-zero when a floor or the ratchet fails. Operators schedule it with
   cron/systemd (see `docs/COVERAGE.md`) and alert on failure through the
   existing alert runbook.
3. **Release requires a recent green nightly run.** The release checklist
   asks for a coverage run from the current revision (or a revision whose
   difference is docs-only) within the release window, so the ratchet result
   is evidence at release time without slowing merges.
4. **The floor and the ratchet are unchanged.** 30% absolute floor, 1.0pp
   tolerance against `tests/coverage_baseline.txt`; lowering a baseline still
   requires a deliberate change.

## Consequences

- The full CI drops by roughly two minutes; the nightly job keeps the same
  measurement and threshold.
- A regression that only coverage would catch is found within a day, not at
  the merge that introduced it. Functional suites and the assertion-count
  baseline still guard every merge.
- `docs/COVERAGE.md` records the cadence, the schedule example, and the
  release requirement; `docs/release-checklist.md` references it.
- The fast gate (ADR 0076) is unchanged: it never ran coverage.
