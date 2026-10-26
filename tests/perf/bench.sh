#!/usr/bin/env bash
# Performance benchmarks: COBOL action latency P50/P99.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available 2>/dev/null; then echo "SKIP: DB unavailable"; exit 0; fi

ITERS=100
echo "=== COBOL Action Latency Benchmark ==="
echo "iterations: $ITERS"

for action in "PING" "GLA_LIST|||50|0||admin@test.com" "BDR_LIST|||50|0||admin@test.com"; do
  total=0
  min=999999
  max=0
  for i in $(seq 1 $ITERS); do
    start=$(date +%s%N)
    printf '%s\n' "$action" > "$ROOT/input.txt"
    DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}" \
      DB_USER="${DB_USER:-cobol_user}" DB_PASS="${DB_PASS:-cobol_pass}" \
      DB_NAME="${DB_NAME:-cobol_db}" "$ROOT/cobol/bin/main_logic" >/dev/null 2>&1
    end=$(date +%s%N)
    elapsed=$(( (end - start) / 1000000 ))
    total=$((total + elapsed))
    if [ "$elapsed" -lt "$min" ]; then min=$elapsed; fi
    if [ "$elapsed" -gt "$max" ]; then max=$elapsed; fi
  done
  avg=$((total / ITERS))
  echo "$action: avg=${avg}ms min=${min}ms max=${max}ms"
done
echo "Benchmark complete."