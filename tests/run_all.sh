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
    echo "=== DB PAYMENT CLEARING TESTS ==="
    tests/db/payment_clearing_db_tests.sh
    echo "=== DB TREASURY LIQUIDITY TESTS ==="
    tests/db/treasury_liquidity_db_tests.sh
    echo "=== DB KYC PERIODIC TESTS ==="
    tests/db/kyc_periodic_db_tests.sh
    echo "=== DB GL ALLOCATION TESTS ==="
    tests/db/gl_allocation_db_tests.sh
    echo "=== DB BACKUP DRILL TESTS ==="
    tests/db/backup_drill_db_tests.sh
    echo "=== DB REPORT BUILDER TESTS ==="
    tests/db/report_builder_db_tests.sh
    echo "=== DB AML SCREENING TESTS ==="
    tests/db/aml_screening_db_tests.sh
    echo "=== DB SANCTIONS LIST TESTS ==="
    tests/db/sanctions_list_db_tests.sh
    echo "=== DB FRAUD CASE TESTS ==="
    tests/db/fraud_case_db_tests.sh
    echo "=== DB COST CENTER TESTS ==="
    tests/db/cost_center_db_tests.sh
    echo "=== DB FIXED ASSET TESTS ==="
    tests/db/fixed_asset_db_tests.sh
    echo "=== DB CONSOLIDATION TESTS ==="
    tests/db/consolidation_db_tests.sh
    echo "=== DB FX HEDGING TESTS ==="
    tests/db/fx_hedging_db_tests.sh
    echo "=== DB BILLPAY TESTS ==="
    tests/db/billpay_db_tests.sh
    echo "=== DB INCIDENT POSTMORTEM TESTS ==="
    tests/db/incident_postmortem_db_tests.sh
    echo "=== DB CHANGE APPROVAL TESTS ==="
    tests/db/change_approval_db_tests.sh
    echo "=== SKELETON SMOKE TESTS ==="
    tests/cobol/skeleton_smoke.sh
    echo "=== FUZZ TESTS ==="
    tests/fuzz/fuzz_inputs.sh
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
