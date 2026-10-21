# Test coverage

Coverage here is a **floor, not a correctness claim**. A covered line can still
be wrong, and the money-path invariants (balanced journals, idempotency,
concurrency, reversals) are proven by the functional suites, not by a
percentage.

## What is measured

| Surface | Measure | Tool |
|---|---|---|
| COBOL core | statement (line) coverage, mapped back to `.cob` lines | `scripts/coverage_cobol.sh` |
| Gateway | line and branch coverage over `middleware/src/**` | Node `--experimental-test-coverage` |

GnuCOBOL translates COBOL to C, and every generated statement carries a
`/* Line: N : ... : <file>.cob */` marker. The script builds the core with
`--coverage`, runs a representative suite subset, and maps the gcov counts on
the generated C back to COBOL lines. A COBOL line counts as executable when
it has at least one instrumented C line, and as covered when any of those C
lines ran.

## Volume-sprint note (2026-10)

The baseline below predates the 211-entity generated reference module. That
module is lab-only and will be excluded from the production coverage target
when it is isolated under `cobol/src/generated/`. Phase 0 re-baselines curated
code after the isolation; until then the numbers below are frozen and must not
be used to claim production coverage. Production targets are **90% for money
paths** and **70% overall for curated code**.

## Floors and ratchet

- **Absolute floor: 30%** for every reported number.
- **Ratchet:** the numbers in `tests/coverage_baseline.txt` must not drop by
  more than 1.0 percentage point. Lower a baseline only when a deliberate
  change removes exercised code (for example deleting a branch), never to
  accept a regression.

`tests/coverage_check.sh` enforces both. **It runs nightly, not on every
merge** (ADR 0078): `scripts/nightly.sh` measures both surfaces, writes a
timestamped log, and exits non-zero on a failure. Schedule it with cron or a
systemd timer:

```sh
# cron: 02:30 every night
30 2 * * * cd /opt/cobol-banking-core && ./scripts/nightly.sh /var/lib/cobol/coverage >> /var/log/cobol-coverage.log 2>&1
```

A red nightly run is the alert; the existing alert runbook applies. The full
`./ci.sh` merge gate no longer runs the measurement, so a merge needs the
functional evidence, while the release needs a recent green nightly run
(`docs/release-checklist.md`). The check reuses a gateway report only when it
is complete and less than an hour old; otherwise it runs the suite itself.

## Running it

```sh
# COBOL statement coverage (default representative subset, ~60s)
./scripts/coverage_cobol.sh

# The same measurement as JSON, or over every functional suite
./scripts/coverage_cobol.sh --json
./scripts/coverage_cobol.sh --all

# Gateway coverage (line + branch, src only)
npm --prefix middleware run test:coverage

# Both gates against the baseline (CI calls this)
./tests/coverage_check.sh
```

The COBOL script swaps an instrumented binary into
`cobol/bin/main_logic` for the duration of the run and restores the normal
binary on exit (including on failure).

## Limits

- **Suite subset.** The default run uses a fixed, representative subset so the
  gate stays around a minute. `--all` measures the whole functional surface;
  use it for release evidence. A subset number is a floor, not the maximum the
  suites would reach.
- **Generated-C proxy.** Coverage lines are attributed through the generated
  C, so a statement that the translator handles unusually can be counted
  imprecisely. The error is small and consistent between runs, which is what a
  ratchet needs.
- **Node's report** covers only loaded files under `src/**`; the worker and
  helper modules are included when their tests load them.
- Coverage does not replace the assertion-count baseline
  (`tests/baseline_counts.txt`), the traceability matrix, or the functional
  suites. All three stay mandatory.
