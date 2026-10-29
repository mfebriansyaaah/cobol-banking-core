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
    node --no-warnings --experimental-vm-modules scripts/check_js_syntax.mjs "$ROOT"
}

# --- DB fleet sharding (Fase 2.3) -------------------------------------------
# SHARD_DBS: worker databases created by this run (space-separated).
# ISOLATED_DB_CREATED: throwaway template DB from the isolation block.
SHARD_DBS=""
ISOLATED_DB_CREATED=""

mysql_admin() {
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_MIGRATE_USER:-cobol_user}" -p"${DB_MIGRATE_PASS:-cobol_pass}" "$@"
}

# Drop every throwaway database this run created (workers + isolated
# template). Safe to run when nothing was created.
cleanup_db_resources() {
    local db
    for db in ${SHARD_DBS:-}; do
        mysql_admin -e "DROP DATABASE IF EXISTS \`$db\`;" >/dev/null 2>&1 || true
    done
    if [ -n "${ISOLATED_DB_CREATED:-}" ]; then
        mysql_admin -e "DROP DATABASE IF EXISTS \`$ISOLATED_DB_CREATED\`;" >/dev/null 2>&1 || true
    elif [ -n "${ISOLATED_DB_NAME:-}" ]; then
        # Isolation attempted but failed (e.g. a migration errored): the
        # half-built database was never recorded, drop it anyway so failed
        # runs do not accumulate cobol_db_test_* databases.
        mysql_admin -e "DROP DATABASE IF EXISTS \`$ISOLATED_DB_NAME\`;" >/dev/null 2>&1 || true
    fi
}

# Probe DDL rights (CREATE/DROP DATABASE) with the migrate credentials.
db_have_ddl() {
    local probe="cobol_db_ddlprobe_$$"
    if mysql_admin -e "CREATE DATABASE \`$probe\`;" >/dev/null 2>&1; then
        mysql_admin -e "DROP DATABASE \`$probe\`;" >/dev/null 2>&1 || true
        return 0
    fi
    return 1
}

# One shard worker: runs its suites sequentially against its worker DB.
# Runs in a background subshell; DB_NAME is exported per worker, while
# DB_VERIFIED=1 / DB_SEEDED=1 are inherited from the runner. Full suite
# output goes to the shard log; only one progress line per suite hits stdout.
# Exits non-zero if any suite failed; failed names go to $log.failed.
run_shard_worker() {
    local idx="$1" log="$2"
    shift 2
    local failed=0 s rc
    : >"$log" 2>/dev/null || return 1
    : >"$log.failed" 2>/dev/null || return 1
    for s in "$@"; do
        if "$s" >"$log.part" 2>&1; then
            rc=0
        else
            rc=$?
        fi
        cat "$log.part" >>"$log" 2>/dev/null || true
        rm -f "$log.part"
        if [ "$rc" -eq 0 ]; then
            echo "[ok] [shard $idx] $(basename "$s")"
        else
            echo "[FAIL] [shard $idx] $(basename "$s")"
            echo "$(basename "$s")" >>"$log.failed"
            failed=$((failed + 1))
        fi
    done
    return "$failed"
}

# Serial fleet (DB_SHARDS=1, or fallback when sharding is unavailable).
run_db_serial() {
    local db_failed=0 db_total=0 suite
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
        return 1
    fi
    return 0
}

run_db_sharded() {
    local shards="$1"
    local template="$DB_NAME"
    echo "=== DB SHARDING: $shards workers (template: $template) ==="
    if [ -z "${ISOLATED_DB_CREATED:-}" ]; then
        echo "--- template migration check ---"
        if ! DB_NAME="$template" database/migrate.sh --check >/dev/null 2>&1; then
            echo "FAIL: template $template has pending migrations; run database/migrate.sh first"
            return 1
        fi
    fi
    command -v mysqldump >/dev/null 2>&1 || { echo "FAIL: mysqldump not found"; return 1; }
    local schema_dump
    schema_dump="$(mktemp "${TMPDIR:-/tmp}/cobol-schema.XXXXXX.sql")" || return 1
    if ! mysqldump -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_MIGRATE_USER:-cobol_user}" -p"${DB_MIGRATE_PASS:-cobol_pass}" \
        --no-data --routines --triggers --single-transaction \
        "$template" >"$schema_dump" 2>/dev/null; then
        echo "FAIL: cannot dump template schema from $template"
        rm -f "$schema_dump"
        return 1
    fi
    # Schema-only misses the migration ledger, which schema_tests asserts on.
    # Append its rows (routines/triggers were already dumped above).
    if mysql_admin -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$template' AND table_name='schema_migrations';" 2>/dev/null | grep -q '^[1-9]'; then
        if ! mysqldump -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
            -u "${DB_MIGRATE_USER:-cobol_user}" -p"${DB_MIGRATE_PASS:-cobol_pass}" \
            --no-create-info --skip-triggers "$template" schema_migrations >>"$schema_dump" 2>/dev/null; then
            echo "FAIL: cannot dump migration ledger from $template"
            rm -f "$schema_dump"
            return 1
        fi
    fi
    # Least privilege: suites keep running as the app account, so the worker
    # DBs need DML grants for exactly the hosts the app account already has.
    # Discovery needs read access to mysql.user (root in CI has it); without
    # it we fall back to serial instead of guessing hosts.
    local app_hosts
    app_hosts="$(mysql_admin -N -B -e "SELECT DISTINCT host FROM mysql.user WHERE user='${DB_USER:-cobol_user}';" 2>/dev/null)" || app_hosts=""
    if [ -z "$app_hosts" ]; then
        echo "WARN: cannot enumerate app-account hosts; sharding needs GRANT-capable migrate credentials, falling back to serial"
        rm -f "$schema_dump"
        return 2
    fi
    local i w h
    for i in $(seq 0 $((shards - 1))); do
        w="cobol_db_shard_${i}_$$"
        if ! mysql_admin -e "CREATE DATABASE \`$w\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1; then
            echo "FAIL: cannot create worker DB $w"
            rm -f "$schema_dump"
            return 1
        fi
        SHARD_DBS="${SHARD_DBS:-} $w"
        for h in $app_hosts; do
            mysql_admin -e "GRANT SELECT, INSERT, UPDATE, DELETE ON \`$w\`.* TO '${DB_USER:-cobol_user}'@'$h';" >/dev/null 2>&1 || true
        done
        if ! mysql_admin "$w" <"$schema_dump" >/dev/null 2>&1; then
            echo "FAIL: cannot load schema into $w"
            rm -f "$schema_dump"
            return 1
        fi
        if ! DB_NAME="$w" mysql_app <"$ROOT/database/seed_test_data.sql" >/dev/null 2>&1; then
            echo "FAIL: cannot seed $w"
            rm -f "$schema_dump"
            return 1
        fi
    done
    rm -f "$schema_dump"
    # Weighted assignment (LPT): heavy suites spread across shards.
    local assign
    assign="$(node scripts/shard_suites.mjs "$shards" "$ROOT")" || { echo "FAIL: shard planner failed"; return 1; }
    [ -n "$assign" ] || { echo "FAIL: shard planner produced no assignment"; return 1; }
    local logdir="/tmp/cobol-shards-$$"
    mkdir -p "$logdir" || return 1
    local pids="" worker_failed=0 pid
    for i in $(seq 0 $((shards - 1))); do
        local shard_suites=""
        # schema_tests also runs here (in worker 0's database) so the shard
        # TAP totals stay comparable with serial runs; it is read-only.
        if [ "$i" -eq 0 ]; then
            shard_suites="tests/db/schema_tests.sh"
        fi
        while IFS= read -r line; do
            case "$line" in
                "$i "*) shard_suites="$shard_suites ${line#* }" ;;
            esac
        done <<EOF
$assign
EOF
        # shellcheck disable=SC2086
        ( export DB_NAME="cobol_db_shard_${i}_$$"
          run_shard_worker "$i" "$logdir/shard-$i.log" $shard_suites ) &
        pids="$pids $!"
    done
    for pid in $pids; do
        if ! wait "$pid"; then
            worker_failed=$((worker_failed + 1))
        fi
    done
    local agg
    agg="$(grep -h '^# pass=' "$logdir"/shard-*.log 2>/dev/null | awk -F'[= ]' '{p+=$3; f+=$5; t+=$7} END{print p+0" "f+0" "t+0}')"
    echo "=== DB SHARDS: $shards workers, ${worker_failed} failed ==="
    echo "=== DB ASSERTIONS: pass=$(echo "$agg" | awk '{print $1}') fail=$(echo "$agg" | awk '{print $2}') total=$(echo "$agg" | awk '{print $3}') ==="
    if [ "$worker_failed" -ne 0 ]; then
        echo "FAIL: suites failed in $worker_failed shard worker(s):"
        cat "$logdir"/shard-*.failed 2>/dev/null | sort -u | sed 's/^/  /'
        for f in "$logdir"/shard-*.failed; do
            [ -s "$f" ] || continue
            echo "--- $(basename "$f" .failed) ---"
            while IFS= read -r s; do
                awk -v n="=== DB SUITE: $s ===" '$0==n{p=1} p{print} /^# pass=/{if(p)exit}' "${f%.failed}" | tail -8
            done <"$f"
        done
        echo "(full shard logs kept in $logdir)"
        return 1
    fi
    rm -rf "$logdir"
    return 0
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
    # Throwaway databases (isolated template + shard workers) are all dropped
    # by one EXIT trap; the isolation block below only records what it made.
    SHARD_DBS=""
    ISOLATED_DB_CREATED=""
    trap cleanup_db_resources EXIT
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
            # Apply migrations through migrate.sh, not by replaying every file:
            # the snapshot already contains the effects of older migrations
            # (e.g. 0015 cannot be replayed on top of it), and migrate.sh
            # skips recorded versions and records what it applies.
            if DB_NAME="$ISOLATED_DB_NAME" database/migrate.sh >/dev/null 2>&1; then
                :
            else
                ISOLATED_OK=0
            fi
            if [ "${ISOLATED_OK:-1}" != "0" ]; then
                export DB_NAME="$ISOLATED_DB_NAME"
                ISOLATED_DB_CREATED="$ISOLATED_DB_NAME"
                echo "=== ISOLATED DB: $ISOLATED_DB_NAME ==="
            else
                echo "=== ISOLATION SKIPPED (migration failed); using $DB_NAME ==="
            fi
        else
            echo "=== ISOLATION SKIPPED (no DDL rights); using $DB_NAME ==="
        fi
    fi
    echo "=== DB PRECHECK + SEED (once per run) ==="
    # Check the database once and seed once; every suite inherits
    # DB_VERIFIED=1 / DB_SEEDED=1 and skips its own precheck/seed
    # (~110ms x 518). COBOL_TEST_SERVE=0 keeps this seed from starting
    # a server in the runner shell (suites start their own).
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/db.sh"
    require_db
    export DB_VERIFIED=1
    COBOL_TEST_SERVE=0 db_seed
    export DB_SEEDED=1
    echo "=== DB SCHEMA TESTS ==="
    tests/db/schema_tests.sh
    # Run every DB suite that exists instead of a hand-maintained list. The
    # old explicit list silently dropped 11 suites (including loan) because
    # adding a domain never touched this file. Sharded by default (DB_SHARDS
    # workers, one database each); serial when DDL rights are missing.
    # Set DB_SHARDS=1 to force serial.
    SHARDS="${DB_SHARDS:-4}"
    case "$SHARDS" in ''|*[!0-9]*) SHARDS=1;; esac
    if [ "$SHARDS" -gt 1 ]; then
        suite_count=0
        for s in tests/db/*_db_tests.sh; do
            [ -f "$s" ] && suite_count=$((suite_count + 1))
        done
        [ "$SHARDS" -gt "$suite_count" ] && SHARDS="$suite_count"
        if [ "$SHARDS" -gt 1 ] && db_have_ddl; then
            shard_rc=0
            run_db_sharded "$SHARDS" || shard_rc=$?
            if [ "$shard_rc" -eq 2 ]; then
                echo "=== continuing serially (sharding unavailable) ==="
                run_db_serial
            elif [ "$shard_rc" -ne 0 ]; then
                exit 1
            fi
        else
            [ "$SHARDS" -gt 1 ] && echo "=== WARN: no DDL rights, cannot create shard DBs (DB_SHARDS=$SHARDS); continuing serially ==="
            run_db_serial
        fi
    else
        run_db_serial
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
