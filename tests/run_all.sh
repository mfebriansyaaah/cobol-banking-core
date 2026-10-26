#!/usr/bin/env bash
# Unified test runner.
# Usage: tests/run_all.sh [fast|db|full]   (default: full)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-full}"

run_fast() {
    echo "=== MANIFEST CHECK ==="
    node scripts/check_manifest.mjs "$ROOT"
    echo "=== BUILD ==="
    if [ "${SKIP_BUILD:-0}" = "1" ]; then
        echo "skipping build (SKIP_BUILD=1)"
    else
        ./build.sh
    fi
    echo "=== COBOL TABLE TESTS ==="
    tests/cobol/table_runner.sh
    echo "=== SMOKE ==="
    printf 'PING||||||\n' > input.txt
    ./cobol/bin/main_logic
    out="$(cat output.txt)"
    echo "PING -> $out"
    echo "$out" | grep -q 'SUCCESS|PONG' || { echo "FAIL: smoke failed"; exit 1; }
}

run_db() {
    echo "=== DB SCHEMA TESTS ==="
    tests/db/schema_tests.sh
    echo "=== DB LOAN SCHEDULE TESTS ==="
    tests/db/loan_schedule_db_tests.sh
    echo "=== DB DEPOSIT TESTS ==="
    tests/db/deposit_db_tests.sh
    echo "=== DB CARD TESTS ==="
    tests/db/card_db_tests.sh
    echo "=== DB COLLECTION TESTS ==="
    tests/db/collection_db_tests.sh
}

run_gateway() {
    echo "=== GATEWAY ENDPOINT SMOKE ==="
    tests/gateway/endpoint_smoke.sh
}

run_error_harness() {
    echo "=== COBOL/C ERROR HARNESS ==="
    tests/check_cobol_c_errors.sh
}

case "$MODE" in
    fast)
        run_fast
        ;;
    db)
        run_db
        ;;
    full)
        run_fast
        run_db
        run_error_harness
        run_gateway
        ;;
    *)
        echo "unknown mode: $MODE (fast|db|full)" >&2
        exit 2
        ;;
esac

echo "=== RUN_ALL ($MODE) GREEN ==="
