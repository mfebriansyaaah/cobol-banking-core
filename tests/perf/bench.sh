#!/usr/bin/env bash
# Performance benchmarks: COBOL action latency P50/P95/P99 with a regression
# budget (P1-8). Runs each action ITERS times in a throwaway workdir, writes
# the distribution to tests/perf/last.json, and fails when p50 exceeds
# baseline by more than 20% or p95 by more than 50% (plus an absolute noise
# floor; p99 is measured and reported but does not gate, see below).
# The baseline (tests/perf/baseline.json) is hardware-dependent; regenerate it
# deliberately on the reference machine with PERF_UPDATE=1 and review the diff.
# Usage: [ITERS=100] [PERF_UPDATE=1] tests/perf/bench.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available 2>/dev/null; then echo "SKIP: DB unavailable"; exit 0; fi

ITERS="${ITERS:-100}"
BASELINE="$ROOT/tests/perf/baseline.json"
LAST="$ROOT/tests/perf/last.json"
echo "=== COBOL Action Latency Benchmark ==="
echo "iterations: $ITERS"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/workdir.sh"
WORKDIR="$(make_workdir bench)" || { echo "FAIL: cannot create workdir" >&2; exit 1; }
trap 'rm -rf "$WORKDIR"' EXIT
export DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}"
export DB_USER="${DB_USER:-cobol_user}" DB_PASS="${DB_PASS:-cobol_pass}"
export DB_NAME="${DB_NAME:-cobol_db}"

# percentile <p> <sorted-file>: nearest-rank from a sorted sample file.
pct() {
  awk -v p="$1" 'NF{ s[n++]=$1 } END { if (!n) exit 1; r=int((p*n+99)/100); if (r<1) r=1; print s[r-1] }' "$2"
}

json='{'
first_action=1
failed=0
for action in "PING" "GLA_LIST|||50|0||admin@test.com" "BDR_LIST|||50|0||admin@test.com"; do
  samples="$(mktemp "${TMPDIR:-/tmp}/bench-samples.XXXXXX")"
  min=999999999
  max=0
  total=0
  n=0
  for _ in $(seq 1 "$ITERS"); do
    start=$(date +%s%N)
    printf '%s\n' "$action" > "$WORKDIR/input.txt"
    ( cd "$WORKDIR" && "$ROOT/cobol/bin/main_logic" >/dev/null 2>&1 ) || true
    end=$(date +%s%N)
    elapsed=$(( (end - start) / 1000000 ))
    echo "$elapsed" >> "$samples"
    total=$((total + elapsed))
    if [ "$elapsed" -lt "$min" ]; then min=$elapsed; fi
    if [ "$elapsed" -gt "$max" ]; then max=$elapsed; fi
    n=$((n + 1))
  done
  sort -n "$samples" -o "$samples"
  p50="$(pct 50 "$samples")"
  p95="$(pct 95 "$samples")"
  p99="$(pct 99 "$samples")"
  avg=$((total / n))
  rm -f "$samples"
  # JSON key must survive arbitrary action text: base64 it.
  key="$(printf '%s' "$action" | base64 -w0 2>/dev/null || printf '%s' "$action" | base64)"
  if [ "$first_action" = "1" ]; then
    first_action=0
  else
    json="$json,"
  fi
  json="$json\"$key\":{\"p50\":$p50,\"p95\":$p95,\"p99\":$p99,\"avg\":$avg,\"min\":$min,\"max\":$max,\"n\":$n}"
  echo "$action: p50=${p50}ms p95=${p95}ms p99=${p99}ms avg=${avg}ms min=${min}ms max=${max}ms"
  if [ -f "$BASELINE" ] && [ "${PERF_UPDATE:-0}" != "1" ]; then
    base_p50="$(node -e 'const b=require(process.argv[1]);const k=process.argv[2];const r=b.actions[k];console.log(r?r.p50:"")' "$BASELINE" "$key" 2>/dev/null || true)"
    base_p95="$(node -e 'const b=require(process.argv[1]);const k=process.argv[2];const r=b.actions[k];console.log(r?r.p95:"")' "$BASELINE" "$key" 2>/dev/null || true)"
    if [ -n "$base_p50" ] && [ -n "$base_p95" ]; then
      # Integer budget check to stay in POSIX shell: fail when
      # p50*100 > base*120 or p95*100 > base*150 (guards divide-by-zero: a
      # zero baseline means "no reference yet", never a failure).
      # Plus an absolute noise floor: percentage gates on small latencies
      # flake with machine noise (measured +/-4ms run-to-run locally), so a
      # breach must also exceed +10ms (p50) / +25ms (p95) to count.
      # The tail gate uses p95, not p99: with n=100, p99 is the 2nd-worst
      # sample and a single outlier trips it (observed 118ms against a
      # 15-40ms distribution). p95 needs six bad samples to move, so it
      # tracks the same tail phenomena without crying wolf. p99 is still
      # measured and reported for humans.
      if [ "$base_p50" -gt 0 ] && [ $((p50 * 100)) -gt $((base_p50 * 120)) ] && [ $((p50 - base_p50)) -gt 10 ]; then
        echo "FAIL perf budget: $action p50=${p50}ms exceeds baseline ${base_p50}ms by >20% and >10ms" >&2
        failed=1
      fi
      if [ "$base_p95" -gt 0 ] && [ $((p95 * 100)) -gt $((base_p95 * 150)) ] && [ $((p95 - base_p95)) -gt 25 ]; then
        echo "FAIL perf budget: $action p95=${p95}ms exceeds baseline ${base_p95}ms by >50% and >25ms" >&2
        failed=1
      fi
    fi
  fi
done
json="$json}"
printf '%s' "$json" | node -e "let s='';process.stdin.on('data',(c)=>s+=c).on('end',()=>{const d=JSON.parse(s);d.generatedAt=new Date().toISOString();d.iters=Number(process.env.ITERS||100);require('fs').writeFileSync(process.argv[1],JSON.stringify(d,null,2)+'\n');})" "$LAST"

if [ "${PERF_UPDATE:-0}" = "1" ]; then
  cp "$LAST" "$BASELINE"
  echo "baseline updated from this run (review the diff before committing)"
elif [ ! -f "$BASELINE" ]; then
  cp "$LAST" "$BASELINE"
  echo "note: no baseline existed; recorded this run as the baseline"
fi

if [ "$failed" -ne 0 ]; then
  echo "FAIL: performance regression over budget" >&2
  exit 1
fi
echo "Benchmark complete (report: tests/perf/last.json)."
