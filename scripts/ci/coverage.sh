#!/usr/bin/env bash
# Coverage measurement and gate.
#
# Scope:
#   - COBOL curated core: statement (line) coverage mapped from the generated C
#     for a fixed curated module set, exercised by a representative DB suite
#     subset, the table suite, and the gateway suite.
#   - Gateway: line/branch coverage over middleware/src/** from Node's built-in
#     test coverage.
#
# Coverage is a floor, not a correctness claim. The gateway suite is the same
# full suite used by CI; the COBOL subset is deliberately bounded so the
# nightly job stays practical. Generated domain modules are covered by their
# own DB suites and table cases; see docs/COVERAGE.md for the limits.
#
# Usage:
#   scripts/ci/coverage.sh                 # full COBOL + gateway measurement
#   scripts/ci/coverage.sh --gateway-only  # fast PR gate, no instrumented build
#   scripts/ci/coverage.sh --cobol-only    # COBOL only (still runs the gateway
#                                          # suite to exercise core actions)
#   scripts/ci/coverage.sh --json          # write coverage/summary.json
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

MODE=both
JSON=0
for arg in "$@"; do
    case "$arg" in
        --gateway-only) MODE=gateway ;;
        --cobol-only) MODE=cobol ;;
        --json) JSON=1 ;;
        -h|--help)
            sed -n '2,28p' "$0"
            exit 0
            ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

COVERAGE_DIR="${COVERAGE_DIR:-$ROOT/coverage}"
BASELINE="$ROOT/tests/coverage_baseline.txt"
FLOOR=30
TOLERANCE=1.0
mkdir -p "$COVERAGE_DIR"

# Curated money-path/core modules measured for COBOL line coverage.
CURATED=(
    main_logic user_core wallet_core auth_core ref_engine gl_core batch_core
    report_core fee_core eod_core statement_core notification_core loan_core
    loan_schedule_core deposit_core card_core collection_core
    payment_clearing_core treasury_liquidity_core kyc_periodic_core
    aml_screening_core sanctions_list_core fraud_case_core gl_allocation_core
    cost_center_core fixed_asset_core interest_rate_core account_core
    customer_core product_catalog_core
)

# Representative DB suites. Missing suites are skipped with a warning so the
# script remains usable on branches where a suite has not landed yet.
SUITES=(
    schema_tests loan_db_tests loan_schedule_db_tests deposit_db_tests
    card_db_tests collection_db_tests payment_clearing_db_tests
    treasury_liquidity_db_tests kyc_periodic_db_tests aml_screening_db_tests
    sanctions_list_db_tests fraud_case_db_tests gl_allocation_db_tests
    gl_master_db_tests fee_management_db_tests account_db_tests
    customer_db_tests cost_center_db_tests fixed_asset_db_tests
    interest_rate_db_tests product_catalog_db_tests report_builder_db_tests
    reporting_db_tests notification_template_db_tests statement_item_db_tests
    account_statement_db_tests
)

baseline() {
    awk -v k="$1" '$1==k {print $2}' "$BASELINE" 2>/dev/null || true
}

check_value() {
    local name="$1" value="$2" floor="$3" base="$4"
    local ok
    ok=$(awk -v v="$value" -v f="$floor" -v b="$base" -v t="$TOLERANCE" \
        'BEGIN { if (v < f) print "floor"; else if (b != "" && v < b - t) print "ratchet"; else print "ok" }')
    case "$ok" in
        floor) echo "FAIL $name: ${value}% is below the ${floor}% floor"; return 1 ;;
        ratchet) echo "FAIL $name: ${value}% dropped below baseline ${base}% (tolerance ${TOLERANCE}pp)"; return 1 ;;
        *) echo "PASS $name: ${value}% (floor ${floor}%, baseline ${base:-n/a}%)"; return 0 ;;
    esac
}

gateway_summary() {
    local report="$1"
    local summary
    summary=$(grep -E '^ℹ all files' "$report" | tail -1 || true)
    if [ -z "$summary" ]; then
        echo "FAIL gateway: no 'all files' summary in $report" >&2
        return 1
    fi
    # Node's table is: all files | lines | branches | functions |
    AWK_SUM="$summary" awk 'BEGIN {
        n = split(ENVIRON["AWK_SUM"], a, "|");
        gsub(/ /, "", a[2]); gsub(/ /, "", a[3]); gsub(/ /, "", a[4]);
        print a[2], a[3], a[4];
    }'
}

run_gateway_coverage() {
    local report="$COVERAGE_DIR/gateway.txt"
    echo "== gateway coverage ==" >&2
    set +e
    ( cd middleware && node --import ./preload.mjs --test \
        --experimental-test-coverage \
        --test-coverage-include='src/**' >"$report" 2>&1 )
    local rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        echo "FAIL gateway: the coverage suite did not pass (rc=$rc, see $report)" >&2
        tail -40 "$report" >&2
        return 1
    fi
    local summary
    summary=$(gateway_summary "$report") || return 1
    local lines branches functions
    read -r lines branches functions <<<"$summary"
    echo "gateway lines=${lines}% branches=${branches}% functions=${functions}%" >&2
    GATEWAY_LINES="$lines"
    GATEWAY_BRANCHES="$branches"
    GATEWAY_FUNCTIONS="$functions"
}

if [ "$MODE" = gateway ]; then
    run_gateway_coverage
    check_value gateway-lines "$GATEWAY_LINES" 80 "$(baseline gateway_lines)"
    check_value gateway-branches "$GATEWAY_BRANCHES" 70 "$(baseline gateway_branches)"
    if [ "$JSON" = 1 ]; then
        printf '{"gateway":{"lines":%s,"branches":%s,"functions":%s}}\n' \
            "$GATEWAY_LINES" "$GATEWAY_BRANCHES" "$GATEWAY_FUNCTIONS" >"$COVERAGE_DIR/summary.json"
    fi
    echo "gateway coverage gate OK"
    exit 0
fi

# The instrumented link reuses normal objects for every non-curated module
# (Fase 4.5): only the curated set is compiled with --coverage, the rest come
# from the incremental build cache. A full --coverage compile of all 605
# modules took longer than the normal build; this takes seconds when warm.
echo "== ensuring normal objects are fresh ==" >&2
./build.sh >"$COVERAGE_DIR/build-normal.log" 2>&1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cobol-coverage.XXXXXX")"
BIN="$ROOT/cobol/bin/main_logic"
SUITE_FAILED=0
cleanup() {
    if [ -f "$WORK/main_logic.normal" ]; then
        cp -f "$WORK/main_logic.normal" "$BIN"
        chmod +x "$BIN"
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

if [ ! -d "$ROOT/cobol/build/obj" ] || ! ls "$ROOT/cobol/build/obj"/*.o >/dev/null 2>&1; then
    echo "FAIL cobol: no normal objects (run ./build.sh without BUILD_LEGACY=1 first)" >&2
    exit 1
fi

echo "== building instrumented objects (curated only) ==" >&2
COV_OBJS=()
NORMAL_OBJS=()
for src in "$ROOT"/cobol/src/*.cob; do
    base="$(basename "$src" .cob)"
    # main_logic is compiled at link time (it carries the entry point).
    [ "$base" = "main_logic" ] && continue
    case " ${CURATED[*]} " in
        *" $base "*)
            if ! cobc -free -c --coverage -I "$ROOT/cobol/copy" \
                -o "$WORK/$base.o" "$src" >"$WORK/build-$base.log" 2>&1; then
                echo "FAIL cobol: coverage compile failed for $base" >&2
                tail -20 "$WORK/build-$base.log" >&2
                exit 1
            fi
            COV_OBJS+=("$WORK/$base.o")
            ;;
        *)
            NORMAL_OBJS+=("$ROOT/cobol/build/obj/$base.o")
            ;;
    esac
done
C_OBJS=(
    "$ROOT/cobol/build/cobj/sql_bridge.o"
    "$ROOT/cobol/build/cobj/hash_lib.o"
    "$ROOT/cobol/build/cobj/totp_lib.o"
    "$ROOT/cobol/build/cobj/settings_lib.o"
    "$ROOT/cobol/build/cobj/random_lib.o"
)
for o in "${NORMAL_OBJS[@]}" "${C_OBJS[@]}"; do
    if [ ! -f "$o" ]; then
        echo "FAIL cobol: missing object $o (stale build cache?)" >&2
        exit 1
    fi
done

echo "== linking instrumented binary ==" >&2
( cd "$WORK" && cobc -free -x --coverage -I "$ROOT/cobol/copy" -o main_cov \
    "$ROOT/cobol/src/main_logic.cob" \
    "${COV_OBJS[@]}" "${NORMAL_OBJS[@]}" "${C_OBJS[@]}" \
    -L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread >build.log 2>&1 ) \
    || { echo "FAIL cobol: instrumented link failed" >&2; tail -20 "$WORK/build.log" >&2; exit 1; }

echo "== generating C sources for ${#CURATED[@]} modules ==" >&2
for m in "${CURATED[@]}"; do
    ( cd "$WORK" && cobc -free -C -I "$ROOT/cobol/copy" "$ROOT/cobol/src/$m.cob" >/dev/null 2>&1 ) \
        || echo "WARN: could not generate C for $m" >&2
done

cp "$BIN" "$WORK/main_logic.normal"
cp "$WORK/main_cov" "$BIN"
chmod +x "$BIN"

echo "== running DB suites under coverage ==" >&2
for s in "${SUITES[@]}"; do
    f="tests/db/$s.sh"
    if [ ! -x "$f" ]; then
        echo "WARN: suite not present, skipped: $s" >&2
        continue
    fi
    echo "  $s" >&2
    if ! DB_HOST="${DB_HOST:-127.0.0.1}" DB_PORT="${DB_PORT:-3306}" \
        DB_NAME="${DB_NAME:-cobol_db}" DB_USER="${DB_USER:-cobol_user}" \
        DB_PASS="${DB_PASS:-cobol_pass}" "$f" >"$WORK/$s.out" 2>&1; then
        echo "FAIL: DB suite failed: $s (see $WORK/$s.out)" >&2
        SUITE_FAILED=1
    fi
done

echo "== running table suite under coverage ==" >&2
if ! tests/cobol/table_runner.sh >"$WORK/table.out" 2>&1; then
    echo "FAIL: table suite failed (see $WORK/table.out)" >&2
    SUITE_FAILED=1
fi

if run_gateway_coverage; then
    GW_RC=0
else
    GW_RC=$?
fi

echo "== mapping COBOL coverage ==" >&2
COBOL_JSON="$COVERAGE_DIR/cobol.json"
python3 "$ROOT/scripts/coverage/map_cobol.py" "$WORK" "$COVERAGE_DIR" "${CURATED[@]}" >"$COVERAGE_DIR/cobol.txt"
COBOL_JSON_FILE="$COVERAGE_DIR/cobol.json"
COBOL_TOTAL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["percent"])' "$COBOL_JSON_FILE")

check_value cobol-total "$COBOL_TOTAL" "$FLOOR" "$(baseline cobol_total)" || SUITE_FAILED=1
if [ "$GW_RC" -eq 0 ]; then
    check_value gateway-lines "$GATEWAY_LINES" 80 "$(baseline gateway_lines)" || SUITE_FAILED=1
    check_value gateway-branches "$GATEWAY_BRANCHES" 70 "$(baseline gateway_branches)" || SUITE_FAILED=1
else
    SUITE_FAILED=1
fi

if [ "$JSON" = 1 ]; then
    python3 - "$COBOL_JSON_FILE" "$COVERAGE_DIR/summary.json" "$GATEWAY_LINES" "$GATEWAY_BRANCHES" "$GATEWAY_FUNCTIONS" <<'PY'
import json, sys
cobol = json.load(open(sys.argv[1]))
summary = {
    'cobol': {'percent': cobol['percent'], 'covered': cobol['covered'], 'executable': cobol['executable']},
    'gateway': {'lines': float(sys.argv[3]), 'branches': float(sys.argv[4]), 'functions': float(sys.argv[5])},
}
open(sys.argv[2], 'w').write(json.dumps(summary, indent=2) + '\n')
PY
fi

if [ "$SUITE_FAILED" -ne 0 ]; then
    echo "COVERAGE GATE FAILED" >&2
    exit 1
fi
echo "COVERAGE GATE OK"
