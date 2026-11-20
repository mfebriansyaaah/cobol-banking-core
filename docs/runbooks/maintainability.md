# Maintainability runbook

How to keep the tree splittable, counted, and green. Companion to the
per-domain guides; for the why, see ADR-0007 (generated docs), ADR-0008
(idempotency), ADR-0009 (extraction playbook), ADR-0010 (call contracts).

## The gates (run these; CI runs them anyway)

```sh
./build.sh                                      # must be silent (0 warnings)
npm run lint && npm run format:check && npm run test:scripts
node scripts/check_docs.mjs .                   # docs truth (incl. --check equivalents)
node scripts/audit_complexity.mjs --check .     # complexity baseline holds
bash tests/run_all.sh fast                      # gates + build + table cases + smoke
bash tests/run_all.sh db                        # full DB fleet (needs DDL-capable DB)
```

`run_all.sh full` must stay green twice in a row at wave end (master plan
§10.3); coverage must not drop >1.0pp; no new COBOL warnings.

ESLint's config-level complexity ratchet is **20** (Phase 2): a function at 20
is accepted; 21+ fails `npm run lint` through `--max-warnings 0`. A second,
stricter ratchet (`scripts/check_js_complexity.mjs`, threshold **15**) records
the remaining 16–20 functions in `tests/js_complexity_baseline.txt`; new
hotspots above 15 fail the fast gate, and a baselined function may not grow.
Split the function into named helpers and refresh the baseline only after a
reviewed change (`--write`). `max-depth` remains a warn-only signal at 6.

## Splitting a module (ADR-0009/0010 in one page)

1. Pin first: `scripts/test/<split>_split.test.mjs` asserting the new
   paragraphs exist, 0 transaction statements, no callback, caller
   delegates, and both call-graph edges. Commit red.
2. Move paragraphs byte-identical (`git diff --color-moved` must show
   relocation, not rewrite). Allowed adaptations only: the 4 transaction
   statements stay owner-side, guard hoists, OUT-protocol lines.
3. New module: same `ENVIRONMENT DIVISION` (copy `DECIMAL-POINT IS COMMA`
   where the owner has it), same LINKAGE shape, entry trim/validate with
   byte-identical semantics.
4. Regenerate: manifest, call graph (`--write`), linkage graph, domain +
   backlog entries, warning baseline (new module at 0, owner unchanged),
   test counts (`--static --write`).
5. Prove: the action's DB/race/conservation suites green with no new
   assertions papering over behavior change; `run_all.sh fast` green.
6. Commit order: test → implement → generated/docs (fixups autosquashed).

Common trap: caller-side numerics (`NUMVAL`, `TRIM` lengths) do not cross
the CALL — recompute them deterministically in the callee.

## Baselines and ratchets (all load-bearing, all `--write`-only)

| File | Counts | Update with |
| --- | --- | --- |
| `tests/baseline_counts.txt` | per-suite assertions | `check_test_counts.mjs --static --write` |
| `tests/warning_baseline.txt` | COBOL warnings per file | lower only, never raise |
| `tests/copybook_baseline.txt` | copybook estate | `check_copybooks.mjs --write` |
| `tests/duplication_baseline.txt` | paragraph/WS duplication, inline dupes, unused WS | `check_duplication.mjs --write` |
| `tests/linkage_baseline.txt` | L0/L1 modules without a core link | only shrinks; new modules need a linked core or stay listed |
| `tests/action_test_coverage_baseline.txt` | uncovered actions + reason | `check_action_test_coverage.mjs --write` |
| `tests/clone_baseline.txt` | clone-like L0/L1 modules (CLONE9 shape) | `check_clone_budget.mjs --write` (only shrinks) |
| `tests/coverage_baseline.txt` | gateway lines/branches ratchet | hand-edit from a reviewed CI run (tolerance 1.0pp; COBOL total retired, floor-only) |
| `tests/coverage_module_baseline.txt` | per-module COBOL coverage (the binding check) | `check_coverage_modules.mjs --write` (review every hunk; tolerance 1.0pp; L3 floor 70 via `--floor`) |
| `tests/coverage_copybook_baseline.txt` | copybooks-union ratchet (shared code) | hand-edit from the coverage-pr artifact of a reviewed run (single value; record the run URL in the PR) |
| `tests/coverage_floor_backlog.txt` | sub-floor L3 modules + reason | hand-edit; the gate fails unlisted sub-floor modules AND stale (reached-floor) entries alike |
| `tests/sql_wrapper_baseline.txt` | remaining inline SQL CALLs per module | `check_bind_slots.mjs --write` (only shrinks; convert to PERFORM instead) |
| `docs/COMPLEXITY_BASELINE.md` | tree metrics | `audit_complexity.mjs --write` |
| `manifest/*`, `docs/STATUS.md`, `MODULE_INDEX.md` | registry + index | their generators + `docs_stats.mjs --write` |

Never hand-edit a generated file or a baseline count; never add a
baseline entry to make CI green. The diff IS the review.

## Module lifecycle

- New modules need L2+ linkage (a proven core business link) or
  `UTILITY`/`INFRA` status, or `check_clone_budget.mjs` fails them.
- Shared COBOL paragraphs live in `cobol/copy/` (one file per declaration
  footprint — cobc validates the whole copybook against each host).
  Every new shared paragraph needs a pin test + a copybook-baseline
  update; inline exceptions stay inline with a documented reason.
- New DB tables are registered in `manifest/table_ownership.json`
  (`check_schema_ownership` fails unregistered tables).
- Archived planning docs live in `docs/archive/` and are byte-frozen;
  `lint:md` skips that directory.

## When CI is red and the tree is green

1. Re-run the failed job first — `coverage-pr` and shard suites flake
   (~1.5pp swings, single-suite flakes); a clean re-run is legitimate
   before re-baselining anything.
2. If the re-run fails identically, it is real: read the gate output,
   fix the tree (never the baseline to fit the tree), re-run the gate
   locally, then push.
3. Probe/mutant failures name the moved anchor — update the anchor to
   the new home, never delete the probe.
