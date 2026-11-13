# Test Coverage

Coverage here is a **floor, not a correctness claim**. A covered line can still
be wrong, and the money-path invariants (balanced journals, idempotency,
concurrency, reversals) are proven by the functional suites, not by a
percentage.

## What is measured

| Surface            | Measure                                                      | Tool                                |
| ------------------ | ------------------------------------------------------------ | ----------------------------------- |
| COBOL curated core | statement (line) coverage mapped back to `.cob` lines        | `scripts/ci/coverage.sh`            |
| Gateway            | line, branch, and function coverage over `middleware/src/**` | Node `--experimental-test-coverage` |

GnuCOBOL translates COBOL to C. The coverage build compiles only the curated
modules with `cobc --coverage` and reuses normal objects from the incremental
build cache (`cobol/build/`) for everything else, then runs
the representative DB suites, the table suite, and the gateway suite, then maps
gcov counts from the generated C back to COBOL lines using the translator's
`/* Line: N : ... */` markers. A COBOL line is executable when at least one
instrumented C line maps to it, and covered when any of those C lines ran.
Markers name their source file, so only the module's own `.cob` lines are
attributed to it: COPYbook lines (`.cpy`) compile into every host but belong
to a different file, and counting them by bare line number collided with
unrelated host lines (the copybook's line 100 was credited to the host's
line 100), which is why per-module rates shifted on every extraction.

## Scope

- **COBOL curated core:** the 21 money-path/core modules listed in
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
- Stage-1 per-module floor (PR-044): every measured Tier-1 module
  (`manifest/tier1.json`) must sit at or above **70%** line coverage.
  Modules below the floor are recorded in `tests/coverage_floor_backlog.txt`
  with reason instead of dragging silently; the gate fails unlisted
  sub-floor modules and stale (reached-floor) entries alike.
- Ratchet: `tests/coverage_baseline.txt` values may not drop by more than
  **1.0 percentage point**. Lower a baseline only for a deliberate change that
  removes exercised code, never to accept a regression.
- Per-module ratchet: `tests/coverage_module_baseline.txt` pins every curated
  module (±1.0pp, see above). A total that still looks fine never hides a
  collapsing module.
- Update the baseline deliberately after a reviewed change. The script prints
  the measured values; commit them with the reason in the PR.
- The C-to-COBOL mapper lives in `scripts/coverage/map_cobol.py` (unit-tested
  in `scripts/coverage/test_map_cobol.py`); the module gate in
  `scripts/check_coverage_modules.mjs` (unit-tested in
  `scripts/test/check_coverage_modules.test.mjs`).

## Running it

```sh
# Full COBOL + gateway measurement and gate (nightly)
bash scripts/ci/coverage.sh

# Fast gateway-only gate (used on pushes; PRs use the coverage-pr job)
bash scripts/ci/coverage.sh --gateway-only

# Machine-readable summary in coverage/summary.json
bash scripts/ci/coverage.sh --json

# Gateway coverage directly
npm --prefix middleware run test:coverage
```

The script writes:

- `coverage/cobol.txt` — per-module COBOL line coverage.
- `coverage/cobol.json` — machine-readable COBOL totals.
- `coverage/cobol-cobertura.xml` — same data as Cobertura XML (one `<class>`
  per module, one `<line>` per executable COBOL line).
- `coverage/gateway.txt` — full gateway coverage report.
- `coverage/summary.json` — combined totals when `--json` is used.

## Per-module ratchet

The total (30% floor + ratchet) cannot see one module collapsing while another
rises. `tests/coverage_module_baseline.txt` pins all 21 curated modules:
`scripts/check_coverage_modules.mjs --json coverage/cobol.json` fails any
module that drops more than 1.0pp below its recorded value. `coverage.sh`
runs this gate automatically after the COBOL measurement.

Update only for a deliberate, reviewed change — never to make CI green:

```sh
node scripts/check_coverage_modules.mjs --json coverage/cobol.json --write
git diff -- tests/coverage_module_baseline.txt   # review every hunk
```

A single-line refactor that moves code between modules legitimately lowers one
module and raises another; record the reason in the PR. `ref_engine` sits at
0% (not yet exercised by the representative suites): the ratchet keeps it
from going unnoticed, raising it is separate work.

## CI

- **Pushes and nightly:** the `coverage` job in `.github/workflows/ci.yml`
  runs `scripts/ci/coverage.sh --gateway-only` against a fresh database and
  uploads the `coverage` artifact. It does not run on pull requests
  (skipped via `if: github.event_name != 'pull_request'`); PRs use
  `coverage-pr` below instead.
- **Pull requests (curated COBOL, impact-selected):** the `coverage-pr` job
  runs `scripts/ci/coverage.sh --cobol-only --changed origin/main --json`.
  The change set is classified by `scripts/ci/coverage_trigger.mjs`
  (unit-tested in `scripts/test/coverage_trigger.test.mjs`) into trigger
  groups — `cobol` (curated modules, shared inputs, build, C bridge),
  `data` (database surface, suites/cases), `measurement` (the scripts and
  baselines themselves), and `gateway` (`middleware/src`, `middleware/test`,
  `tests/gateway`, `tests/lib`). Gateway changes trigger the measurement:
  the gateway suite exercises COBOL actions through the instrumented binary,
  so a route change can drop COBOL coverage. Docs-only changes, generated
  data, and build noise skip the instrumented build in seconds; unrecognized
  paths measure (safe default). Otherwise the full curated measurement runs
  and a Markdown summary (totals vs baselines, any module below its baseline)
  is appended to the run summary, with the full report in the `coverage-pr`
  artifact. (A PR comment is not used: this repository's token permissions
  are read-only, so `issues: write` calls fail; the run summary needs no
  extra permission.)
- **Nightly:** `.github/workflows/coverage.yml` runs the full COBOL + gateway
  measurement with a MariaDB service and uploads the report. It can also be
  started manually with `workflow_dispatch`.

> Preload mode: `coverage.sh` runs the gateway suite with `preload.mjs`
> (file mode: one COBOL process per call), while `endpoint_smoke.sh` uses
> `preload.gateway.mjs` for `test:gateway` (persistent worker pool).
> Gateway coverage therefore measures file mode, not pool mode. Coverage is
> a measurement floor, not a behavior gate — behavior is covered by `test`.

### Toolchain

Ubuntu 24.04's apt `gnucobol` (3.1.2) does not know `cobc --coverage`, which
the curated measurement requires (both coverage jobs failed on it before).
Both jobs therefore build GnuCOBOL 3.2 from the official tarball via
`scripts/ci/install_gnucobol.sh` (pinned SHA-256, CFLAGS for modern GCC,
idempotent) and cache `~/.local/gnucobol` between runs. The normal build, the
instrumented build, and the measured binary all use that toolchain; other
jobs keep using apt.

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
