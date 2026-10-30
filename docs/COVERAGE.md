# Test Coverage

Coverage here is a **floor, not a correctness claim**. A covered line can still
be wrong, and the money-path invariants (balanced journals, idempotency,
concurrency, reversals) are proven by the functional suites, not by a
percentage.

## What is measured

| Surface | Measure | Tool |
|---|---|---|
| COBOL curated core | statement (line) coverage mapped back to `.cob` lines | `scripts/ci/coverage.sh` |
| Gateway | line, branch, and function coverage over `middleware/src/**` | Node `--experimental-test-coverage` |

GnuCOBOL translates COBOL to C. The coverage build compiles only the curated
modules with `cobc --coverage` and reuses normal objects from the incremental
build cache (`cobol/build/`) for everything else, then runs
the representative DB suites, the table suite, and the gateway suite, then maps
gcov counts from the generated C back to COBOL lines using the translator's
`/* Line: N : ... */` markers. A COBOL line is executable when at least one
instrumented C line maps to it, and covered when any of those C lines ran.

## Scope

- **COBOL curated core:** the 30 money-path/core modules listed in
  `scripts/ci/coverage.sh` (`main_logic`, `wallet_core`, `auth_core`,
  `user_core`, `loan_core`, `deposit_core`, `card_core`, `collection_core`,
  `payment_clearing_core`, `treasury_liquidity_core`, compliance modules,
  accounting modules, and the reference/gateway helpers).
- **Representative DB suites:** the suite list in `scripts/ci/coverage.sh`
  covers core banking, lending, deposits, cards, collections, payments,
  treasury, compliance, accounting, and reporting.
- **Table suite:** all `tests/cobol/cases/*.cases`.
- **Gateway:** the full `middleware/test/*.test.js` suite.

Generated domain modules are **not** part of the COBOL line-coverage total.
They remain covered by their own DB suites, table cases, and the action/suite
inventory gates (`check_action_coverage`, `check_suite_coverage`). This keeps
the measurement bounded and honest; it is a curated-core floor, not a claim of
whole-codebase coverage.

## Floors and ratchet

- Absolute floor: **30%** for COBOL, **80%** for gateway lines, **70%** for
  gateway branches.
- Ratchet: `tests/coverage_baseline.txt` values may not drop by more than
  **1.0 percentage point**. Lower a baseline only for a deliberate change that
  removes exercised code, never to accept a regression.
- Update the baseline deliberately after a reviewed change. The script prints
  the measured values; commit them with the reason in the PR.

## Running it

```sh
# Full COBOL + gateway measurement and gate (nightly)
bash scripts/ci/coverage.sh

# Fast gateway-only gate (used on pull requests)
bash scripts/ci/coverage.sh --gateway-only

# Machine-readable summary in coverage/summary.json
bash scripts/ci/coverage.sh --json

# Gateway coverage directly
npm --prefix middleware run test:coverage
```

The script writes:

- `coverage/cobol.txt` — per-module COBOL line coverage.
- `coverage/cobol.json` — machine-readable COBOL totals.
- `coverage/gateway.txt` — full gateway coverage report.
- `coverage/summary.json` — combined totals when `--json` is used.

## CI

- **Pull requests:** the `coverage` job in `.github/workflows/ci.yml` runs
  `scripts/ci/coverage.sh --gateway-only` against a fresh database and uploads
  the `coverage` artifact.
- **Nightly:** `.github/workflows/coverage.yml` runs the full COBOL + gateway
  measurement with a MariaDB service and uploads the report. It can also be
  started manually with `workflow_dispatch`.

## Limits

- The COBOL number is a **curated-core subset**, not the whole tree.
- The generated-C proxy can misattribute a statement that GnuCOBOL translates
  unusually. The error is small and consistent between runs, which is what a
  ratchet needs.
- Node's report covers only loaded files under `src/**`; helper modules are
  included when their tests load them.
- Coverage does not replace the assertion-count baseline
  (`tests/baseline_counts.txt`), the action/suite inventory gates, or the
  functional suites.
