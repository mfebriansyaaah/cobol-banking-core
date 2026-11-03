# Performance & fuzz

Two harnesses live here. Both need a migrated database and a built binary
(`./build.sh`); neither writes fixtures, so they are safe to rerun.

## Benchmarks (`bench.sh`)

Measures COBOL action latency over `ITERS` runs (default 100) in a throwaway
workdir and writes `tests/perf/last.json`
(`{"generatedAt","iters","actions": {"<base64>": {p50,p95,p99,avg,min,max,n}}}`).
Actions are base64 keys because they contain pipes and spaces.

The run fails when, against `tests/perf/baseline.json`:

- p50 exceeds baseline by more than 20% **and** more than +10ms, or
- p99 exceeds baseline by more than 50% **and** more than +25ms.

The absolute floor exists because pure ratios flake on machine noise
(measured ±4ms run-to-run locally, which alone trips a 20% gate at these
magnitudes). Real regressions (tens of ms) trip both conditions.

Workflow:

```sh
ITERS=50 bash tests/perf/bench.sh        # measure; last.json is gitignored
PERF_UPDATE=1 bash tests/perf/bench.sh   # rebaseline after review
git diff -- tests/perf/baseline.json     # review every hunk before committing
```

Rules:

- Never update the baseline to make CI green. If the change is intentional
  (new query plan, added validation), say so in the PR with before/after
  numbers; otherwise fix the regression.
- Baselines are hardware-class specific. If CI runners differ systematically
  from the machine that recorded the baseline, rebaseline from a nightly
  artifact (`nightly-reports` → `last.json`) instead of widening thresholds.
- CI runs the benchmark gate in the `test` job before the drills (seeded DB,
  no competing dump); nightly runs the load test below.

## Load test (`load_gateway.sh`)

Serves the real gateway on a random localhost port (pool mode, rate limits
lifted — the limiter itself is covered by `ratelimit.test.js`) and hammers
`GET /health` — a real COBOL+DB round-trip per request, no fixtures needed.

```sh
LOAD_DURATION=10 LOAD_CONNECTIONS=50 LOAD_P99_MS=500 bash tests/perf/load_gateway.sh
```

Fails on any transport error, timeout, non-2xx, or p99 over budget
(default 500ms, ~10x a local 24k-request run; tune per hardware with
`LOAD_P99_MS`). Runs in nightly after gateway coverage.

## Fuzz (`../fuzz/fuzz_inputs.sh`)

Sends malformed inputs through `run_cobol` (same path as DB suites) and
requires: non-empty output, a `SUCCESS|`/`ERROR|` prefix, `ERROR|` for the
whole fixed malformed corpus (never bare `SUCCESS`), and the `users` table
still present afterwards (injection must not escape validation).

```sh
FUZZ_ACTIONS="GLA_CREATE BDR_CREATE" FUZZ_ITERATIONS=5 FUZZ_SEED=42 bash tests/fuzz/fuzz_inputs.sh
```

- `FUZZ_ACTIONS`: space-separated subset (default: 5 validating actions).
- `FUZZ_ITERATIONS=N`: N extra deterministic random inputs per action.
- `FUZZ_SEED`: reseeds bash `$RANDOM` (default 42); same seed, same soup.
- Random soup asserts protocol conformance + table integrity only — random
  bytes can be legitimately valid, so `ERROR|`-only would be a false gate.
- Adding an action that accepts a corpus input is a deliberate test change,
  not a fuzzer bug: the gate forces validation to be explicit.
