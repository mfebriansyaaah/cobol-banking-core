#!/usr/bin/env bash
# Unified test runner.
# Usage: tests/run_all.sh [fast|db|full|probes]   (default: full)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-full}"

# Parse every gateway/script source before anything else runs. A route file
# that cannot be imported takes the whole gateway down, and the old pipeline
# had no step that noticed: the auth/db suites never import the route barrel.
check_js_syntax() {
    local bad=0 f
    while IFS= read -r f; do
        if ! node --check "$f" >/dev/null 2>&1; then
            echo "FAIL: $f"
            node --check "$f" 2>&1 | sed -n '1,3p' | sed 's/^/    /'
            bad=$((bad + 1))
        fi
    done < <(find middleware/src scripts \( -name '*.js' -o -name '*.mjs' \) -type f | sort)
    if [ "$bad" -ne 0 ]; then
        echo "FAIL: $bad file(s) cannot be parsed"
        exit 1
    fi
    echo "OK: gateway and script sources parse"
}

run_fast() {
    echo "=== JS SYNTAX CHECK ==="
    check_js_syntax
    echo "=== MANIFEST CHECK ==="
    node scripts/check_manifest.mjs "$ROOT"
    echo "=== ROUTE/DISPATCH CONTRACT CHECK ==="
    node scripts/check_route_dispatch.mjs "$ROOT"
    echo "=== ROUTE CONFLICT CHECK ==="
    node scripts/check_route_conflicts.mjs "$ROOT"
    echo "=== ROUTE AUTH CHECK ==="
    node scripts/check_route_auth.mjs "$ROOT"
    echo "=== ACTION COVERAGE CHECK ==="
    node scripts/check_action_coverage.mjs "$ROOT"
    echo "=== BIND SLOT CHECK ==="
    node scripts/check_bind_slots.mjs "$ROOT"
    echo "=== DB SUITE INVENTORY CHECK ==="
    node scripts/check_suite_coverage.mjs "$ROOT"
    echo "=== BUILD ==="
    if [ "${SKIP_BUILD:-0}" = "1" ]; then
        echo "skipping build (SKIP_BUILD=1)"
    else
        ./build.sh
    fi
    echo "=== COBOL TABLE TESTS ==="
    node scripts/check_case_actions.mjs "$ROOT"
    tests/cobol/table_runner.sh
    echo "=== SMOKE ==="
    printf 'PING||||||\n' > input.txt
    ./cobol/bin/main_logic
    out="$(cat output.txt)"
    echo "PING -> $out"
    echo "$out" | grep -q 'SUCCESS|PONG' || { echo "FAIL: smoke failed"; exit 1; }
}

run_db() {
    echo "=== TEST HELPER CHECK ==="
    node scripts/check_test_helpers.mjs "$ROOT"
    DB_NAME="${DB_NAME:-cobol_db}"
    # Isolate the whole DB test run from the primary database so suites cannot
    # clobber developer/production data. Opt out with ISOLATED_DB=0.
    if [ "${ISOLATED_DB:-1}" != "0" ] && [ "$DB_NAME" = "cobol_db" ]; then
        ISOLATED_DB_NAME="cobol_db_test_$$"
        DB_HOST="${DB_HOST:-localhost}"
        DB_PORT="${DB_PORT:-3306}"
        DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}"
        DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_pass}"
        if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" \
            -e "DROP DATABASE IF EXISTS \`$ISOLATED_DB_NAME\`; CREATE DATABASE \`$ISOLATED_DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1 && \
           mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$ISOLATED_DB_NAME" < database/schema.sql >/dev/null 2>&1; then
            ISOLATED_OK=1
            for f in database/migrations/*.sql; do
                mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$ISOLATED_DB_NAME" < "$f" >/dev/null 2>&1 || { ISOLATED_OK=0; break; }
            done
            if [ "${ISOLATED_OK:-1}" != "0" ]; then
                export DB_NAME="$ISOLATED_DB_NAME"
                trap 'mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" -e "DROP DATABASE IF EXISTS \`'"$ISOLATED_DB_NAME"'\`;" >/dev/null 2>&1 || true' EXIT
                echo "=== ISOLATED DB: $ISOLATED_DB_NAME ==="
            else
                echo "=== ISOLATION SKIPPED (migration failed); using $DB_NAME ==="
            fi
        else
            echo "=== ISOLATION SKIPPED (no DDL rights); using $DB_NAME ==="
        fi
    fi
    echo "=== DB SCHEMA TESTS ==="
    tests/db/schema_tests.sh
    # Run every DB suite that exists instead of a hand-maintained list. The
    # old explicit list silently dropped 11 suites (including loan) because
    # adding a domain never touched this file.
    db_failed=0
    db_total=0
    for suite in tests/db/*_db_tests.sh; do
        [ -f "$suite" ] || continue
        db_total=$((db_total + 1))
        echo "=== DB SUITE: $(basename "$suite") ==="
        if ! "$suite"; then
            echo "FAIL: $(basename "$suite")"
            db_failed=$((db_failed + 1))
        fi
    done
    echo "=== DB SUITES: ${db_total} run, ${db_failed} failed ==="
    if [ "$db_failed" -ne 0 ]; then
        echo "FAIL: ${db_failed} DB suite(s) failed"
        exit 1
    fi
    echo "=== SKELETON SMOKE TESTS ==="
    tests/cobol/skeleton_smoke.sh
    echo "=== FUZZ TESTS ==="
    tests/fuzz/fuzz_inputs.sh
}

run_gateway() {
    echo "=== GATEWAY ENDPOINT SMOKE ==="
    tests/gateway/endpoint_smoke.sh
}

# Break the code on purpose in a throwaway copy and require the gates to
# notice. Kept out of `fast` so a normal run stays fast; run it whenever a
# gate changes, and in CI.
run_probes() {
    echo "=== GATE DETECTION PROBES ==="
    tests/probes/run_probes.sh
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
    probes)
        run_probes
        ;;
    full)
        run_fast
        run_db
        run_error_harness
        run_gateway
        ;;
    *)
        echo "unknown mode: $MODE (fast|db|full|probes)" >&2
        exit 2
        ;;
esac

echo "=== RUN_ALL ($MODE) GREEN ==="
