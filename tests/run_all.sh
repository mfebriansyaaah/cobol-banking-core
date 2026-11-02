#!/usr/bin/env bash
# Unified test runner.
# Usage: tests/run_all.sh [--json] [--no-report] [fast|db|full|probes|affected|integration]   (default: full)
#   --json       print the report path at the end (artifacts/run-all.json)
#   --no-report  skip machine-readable reporting (logs only)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPORT_ENABLED="${REPORT_ENABLED:-1}"
PRINT_JSON=0
MODE=""
for _arg in "$@"; do
    case "$_arg" in
        --json) PRINT_JSON=1 ;;
        --no-report) REPORT_ENABLED=0 ;;
        --help|-h)
            sed -n '2,5p' "$0"
            echo "Modes: fast db db-shard full probes affected integration"
            exit 0
            ;;
        -*) echo "unknown flag: $_arg (see --help)" >&2; exit 2 ;;
        *)
            if [ -z "$MODE" ]; then
                MODE="$_arg"
            else
                echo "unexpected argument: $_arg (see --help)" >&2
                exit 2
            fi
            ;;
    esac
done
MODE="${MODE:-full}"
export REPORT_ENABLED PRINT_JSON

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
# DB_VERIFIED=1 / DB_SEEDED=1 are inherited from the runner. Per-suite results
# go through report_run (progress on stdout, full log under
# $REPORT_DIR/logs/, one TSV row each); the shard log keeps the concatenated
# suite outputs so failure excerpts below keep working.
# Exits non-zero if any suite failed; failed names go to $log.failed.
run_shard_worker() {
    local idx="$1" log="$2"
    shift 2
    local failed=0 s rc
    : >"$log" 2>/dev/null || return 1
    : >"$log.failed" 2>/dev/null || return 1
    for s in "$@"; do
        if report_run "$idx" "$s"; then
            rc=0
        else
            rc=$?
        fi
        {
            echo "=== DB SUITE: $(basename "$s") ==="
            cat "$REPORT_DIR/logs/$(basename "$s").log" 2>/dev/null || true
        } >>"$log" 2>/dev/null || true
        if [ "$rc" -ne 0 ]; then
            basename "$s" >>"$log.failed"
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
        if ! report_run "serial" "$suite"; then
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

# Dump the template schema plus the migration ledger (which schema_tests
# asserts on) for worker DB creation. Prints ONLY the dump path on stdout
# (progress goes to stderr: callers capture stdout). Returns 1 with a
# message when the template cannot be dumped.
dump_template_schema() {
    local template="$1"
    if [ -z "${ISOLATED_DB_CREATED:-}" ]; then
        echo "--- template migration check ---" >&2
        # env (not VAR=x prefix): this runs inside $() at call sites, and a
        # prefix assignment there trips SC2031's lost-modification heuristic.
        if ! env "DB_NAME=$template" database/migrate.sh --check >/dev/null 2>&1; then
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
        echo "FAIL: cannot dump template schema from $template" >&2
        rm -f "$schema_dump"
        return 1
    fi
    # Schema-only misses the migration ledger, which schema_tests asserts on.
    # Append its rows (routines/triggers were already dumped above).
    if mysql_admin -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$template' AND table_name='schema_migrations';" 2>/dev/null | grep -q '^[1-9]'; then
        if ! mysqldump -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
            -u "${DB_MIGRATE_USER:-cobol_user}" -p"${DB_MIGRATE_PASS:-cobol_pass}" \
            --no-create-info --skip-triggers "$template" schema_migrations >>"$schema_dump" 2>/dev/null; then
            echo "FAIL: cannot dump migration ledger from $template" >&2
            rm -f "$schema_dump"
            return 1
        fi
    fi
    printf '%s' "$schema_dump"
}

# Discover the hosts the app account exists on, for worker DB grants. Prints
# the host list. Returns 2 when undiscoverable: callers fall back to serial
# or fail closed instead of guessing hosts.
shard_app_hosts() {
    local app_hosts
    app_hosts="$(mysql_admin -N -B -e "SELECT DISTINCT host FROM mysql.user WHERE user='${DB_USER:-cobol_user}';" 2>/dev/null)" || app_hosts=""
    if [ -z "$app_hosts" ]; then
        echo "WARN: cannot enumerate app-account hosts; sharding needs GRANT-capable migrate credentials" >&2
        return 2
    fi
    printf '%s' "$app_hosts"
}

# Create one worker database from a template dump and seed it, then point
# DB_NAME at it. Appends to SHARD_DBS (dropped by cleanup_db_resources via
# the EXIT trap). Returns 1 with a message on failure. Sets DB_NAME as a
# side effect (instead of printing it) so callers need no $(...) capture,
# which keeps shellcheck's subshell analysis precise.
make_worker_db() {
    local dump="$1" idx="$2" app_hosts="$3"
    local w="cobol_db_shard_${idx}_$$" h
    if ! mysql_admin -e "CREATE DATABASE \`$w\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1; then
        echo "FAIL: cannot create worker DB $w"
        return 1
    fi
    SHARD_DBS="${SHARD_DBS:-} $w"
    # Least privilege: suites keep running as the app account, so the worker
    # DB needs DML grants for exactly the hosts the app account already has.
    for h in $app_hosts; do
        mysql_admin -e "GRANT SELECT, INSERT, UPDATE, DELETE ON \`$w\`.* TO '${DB_USER:-cobol_user}'@'$h';" >/dev/null 2>&1 || true
    done
    if ! mysql_admin "$w" <"$dump" >/dev/null 2>&1; then
        echo "FAIL: cannot load schema into $w"
        return 1
    fi
    if ! DB_NAME="$w" mysql_app <"$ROOT/database/seed_test_data.sql" >/dev/null 2>&1; then
        echo "FAIL: cannot seed $w"
        return 1
    fi
    export DB_NAME="$w"
}

run_db_sharded() {
    local shards="$1"
    local template="$DB_NAME"
    echo "=== DB SHARDING: $shards workers (template: $template) ==="
    local schema_dump
    if ! schema_dump="$(dump_template_schema "$template")"; then
        return 1
    fi
    # Least privilege: suites keep running as the app account, so the worker
    # DBs need DML grants for exactly the hosts the app account already has.
    # Discovery needs read access to mysql.user (root in CI has it); without
    # it we fall back to serial instead of guessing hosts.
    local app_hosts
    if ! app_hosts="$(shard_app_hosts)"; then
        echo "WARN: falling back to serial"
        rm -f "$schema_dump"
        return 2
    fi
    local i
    for i in $(seq 0 $((shards - 1))); do
        make_worker_db "$schema_dump" "$i" "$app_hosts" || { rm -f "$schema_dump"; return 1; }
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
        # shellcheck disable=SC2030
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

# Run exactly one shard of the DB fleet (CI matrix worker). The assignment is
# computed by the same planner (scripts/shard_suites.mjs) that in-job
# sharding uses, so shards 0..N-1 partition every suite exactly once.
# Usage: DB_SHARD_INDEX=0 DB_SHARD_COUNT=4 tests/run_all.sh db-shard
run_db_shard_one() {
    local total="$1" index="$2"
    # False positive: make_worker_db below exports DB_NAME in-process, but the
    # $(...) captures in this function make shellcheck assume it runs in a
    # subshell where that export would be lost. It does not: every call here
    # runs in the main shell.
    # shellcheck disable=SC2031
    local template="$DB_NAME"
    echo "=== DB SHARD: $index of $total (template: $template) ==="
    local schema_dump
    if ! schema_dump="$(dump_template_schema "$template")"; then
        return 1
    fi
    local app_hosts
    if ! app_hosts="$(shard_app_hosts)"; then
        echo "FAIL: cannot create an isolated worker DB without GRANT-capable migrate credentials"
        rm -f "$schema_dump"
        return 1
    fi
    make_worker_db "$schema_dump" "$index" "$app_hosts" || { rm -f "$schema_dump"; return 1; }
    rm -f "$schema_dump"
    # Same planner, one slice. Worker 0 also runs the read-only schema tests,
    # mirroring in-job sharding.
    local shard_suites=""
    if [ "$index" = "0" ]; then
        shard_suites="tests/db/schema_tests.sh"
    fi
    local assign
    assign="$(node scripts/shard_suites.mjs "$total" "$ROOT")"
    while IFS= read -r line; do
        case "$line" in
            "$index "*) shard_suites="$shard_suites ${line#* }" ;;
        esac
    done <<EOF
$assign
EOF
    # The worker was seeded at creation; suites inherit the flags and skip
    # their own precheck/seed, exactly like in-job shard workers.
    # (DB_NAME already points at the worker via make_worker_db.)
    export DB_VERIFIED=1
    export DB_SEEDED=1
    # No run lock: shard workers target private databases (matrix jobs run on
    # separate runners). Concurrent local runs must use distinct REPORT_DIRs.
    local db_failed=0 s
    for s in $shard_suites; do
        if ! report_run "$index" "$s"; then
            db_failed=$((db_failed + 1))
        fi
    done
    echo "=== DB SHARD $index: $db_failed failed ==="
    if [ "$db_failed" -ne 0 ]; then
        echo "FAIL: shard $index has failing suite(s)"
        return 1
    fi
    return 0
}

run_gates() {
    echo "=== JS SYNTAX CHECK ==="
    check_js_syntax
    # The static gates are independent (each reads the tree, none writes),
    # so run them in parallel and print the logs in stable order. Failures
    # still fail the run; the per-gate log names which gate broke.
    echo "=== STATIC GATES (9 parallel) ==="
    gate_pids=""
    gate_failed=0
    for g in check_manifest check_route_dispatch check_route_conflicts check_route_auth check_action_coverage check_bind_slots check_suite_coverage check_field_order check_action_test_coverage; do
        node "scripts/$g.mjs" "$ROOT" >"/tmp/runall-gate-$g-$$.log" 2>&1 &
        gate_pids="$gate_pids $!"
    done
    for pid in $gate_pids; do
        wait "$pid" || gate_failed=1
    done
    for g in check_manifest check_route_dispatch check_route_conflicts check_route_auth check_action_coverage check_bind_slots check_suite_coverage check_field_order check_action_test_coverage; do
        case "$g" in
            check_manifest) echo "=== MANIFEST CHECK ===";;
            check_route_dispatch) echo "=== ROUTE/DISPATCH CONTRACT CHECK ===";;
            check_route_conflicts) echo "=== ROUTE CONFLICT CHECK ===";;
            check_route_auth) echo "=== ROUTE AUTH CHECK ===";;
            check_action_coverage) echo "=== ACTION COVERAGE CHECK ===";;
            check_bind_slots) echo "=== BIND SLOT CHECK ===";;
            check_suite_coverage) echo "=== DB SUITE INVENTORY CHECK ===";;
            check_field_order) echo "=== FIELD ORDER CHECK ===";;
            check_action_test_coverage) echo "=== ACTION TEST COVERAGE CHECK ===";;
        esac
        cat "/tmp/runall-gate-$g-$$.log"
        rm -f "/tmp/runall-gate-$g-$$.log"
    done
    if [ "$gate_failed" -ne 0 ]; then
        echo "FAIL: one or more static gates failed"
        exit 1
    fi
}

run_build() {
    echo "=== BUILD ==="
    if [ "${SKIP_BUILD:-0}" = "1" ]; then
        echo "skipping build (SKIP_BUILD=1)"
    else
        ./build.sh
    fi
}

run_smoke() {
    echo "=== SMOKE ==="
    printf 'PING||||||\n' > input.txt
    ./cobol/bin/main_logic
    out="$(cat output.txt)"
    echo "PING -> $out"
    if echo "$out" | grep -q 'SUCCESS|PONG'; then
        report_record "smoke" "pass" 1 0 1 0 "fast"
    else
        report_record "smoke" "fail" 0 1 1 0 "fast"
        echo "FAIL: smoke failed"
        exit 1
    fi
}

run_fast() {
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/report.sh"
    # shellcheck disable=SC2119
    report_init
    trap report_finalize EXIT
    run_gates
    run_build
    echo "=== COBOL TABLE TESTS ==="
    node scripts/check_case_actions.mjs "$ROOT"
    report_run "table" tests/cobol/table_runner.sh
    run_smoke
}

# Impact-selected run (Fase 5): static gates + build always run; DB suites,
# table cases and node suites are limited to what scripts/select_tests.mjs
# maps from the change set. Anything unrecognized escalates to a full run.
# DB suites run without isolation against the current database (like local
# serial runs); suites reset their own tables and seed idempotently.
# Usage: run_all.sh affected  (SELECT_BASE env selects the base ref,
# SELECT_FILES env bypasses git and passes explicit paths to the planner).
run_affected() {
    echo "=== TEST SELECTION ==="
    local plan base_arg="${SELECT_BASE:-}"
    local files_arg="${SELECT_FILES:-}"
    if [ -n "$files_arg" ]; then
        # shellcheck disable=SC2086
        plan="$(node scripts/select_tests.mjs --files $files_arg)"
    elif [ -n "$base_arg" ]; then
        plan="$(node scripts/select_tests.mjs "$base_arg")"
    else
        plan="$(node scripts/select_tests.mjs)"
    fi
    # shellcheck disable=SC2001
    sed 's/^/  /' <<< "$plan"
    eval "$plan"
    if [ "${SELECT_MODE:-full}" != "selected" ]; then
        echo "=== AFFECTED: full run required (${SELECT_REASON:-unknown}) ==="
        exec "$0" full
    fi
    echo "=== AFFECTED: ${SELECT_REASON:-selected run} ==="
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/report.sh"
    # shellcheck disable=SC2119
    report_init
    trap 'db_lock_release; report_finalize' EXIT
    run_gates
    run_build
    echo "=== COBOL TABLE TESTS (selected) ==="
    node scripts/check_case_actions.mjs "$ROOT"
    local selected_failed=0
    if [ -n "${SELECT_CASE_FILES:-}" ]; then
        # shellcheck disable=SC2086
        report_run "table" tests/cobol/table_runner.sh $SELECT_CASE_FILES || selected_failed=1
    else
        echo "(no case files selected; skipping)"
    fi
    if [ -n "${SELECT_DB_SUITES:-}" ]; then
        echo "=== DB SUITES (selected) ==="
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/db.sh"
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/lock.sh"
        # Default the run target (without .dbenv the analyzer cannot see
        # DB_NAME preset, so it suspects a lost subshell modification; the
        # assignment is intentional).
        # shellcheck disable=SC2031
        DB_NAME="${DB_NAME:-cobol_db}"
        db_lock_acquire || exit 1
        trap 'db_lock_release; report_finalize' EXIT
        require_db
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/report.sh"
        # shellcheck disable=SC2119
        [ -n "${REPORT_TSV:-}" ] || report_init
        local s
        for s in $SELECT_DB_SUITES; do
            report_run "affected" "$s" || selected_failed=1
        done
    else
        echo "(no DB suites selected; skipping)"
    fi
    run_node_selected || selected_failed=1
    run_smoke
    if [ "$selected_failed" -ne 0 ]; then
        echo "=== AFFECTED FAILED ==="
        exit 1
    fi
}

# Node part of an affected run. SELECT_NODE_SUITE is a suite script;
# SELECT_NODE_FILES are exact test files (deduplicated against the suite).
run_node_selected() {
    local suite="${SELECT_NODE_SUITE:-none}" f
    local node_failed=0
    case "$suite" in
        full) ( cd middleware && npm test ) || node_failed=1;;
        gateway) ( cd middleware && npm run test:gateway ) || node_failed=1;;
        fast) ( cd middleware && npm run test:fast ) || node_failed=1;;
        endpoints) ( cd middleware && npm run test:endpoints ) || node_failed=1;;
        none) :;;
        *) echo "FAIL: unknown node suite: $suite" >&2; return 1;;
    esac
    for f in ${SELECT_NODE_FILES:-}; do
        case "$suite:$f" in
            full:*) continue;;
            gateway:middleware/test/gateway.test.js|gateway:middleware/test/endpoints.test.js) continue;;
            fast:middleware/test/gateway.test.js|fast:middleware/test/endpoints.test.js) :;;
            fast:*) continue;;
            endpoints:middleware/test/endpoints.test.js) continue;;
        esac
        local preload="preload.mjs" rel="${f#middleware/}"
        case "$f" in
            middleware/test/gateway.test.js|middleware/test/endpoints.test.js)
                preload="preload.gateway.mjs";;
        esac
        echo "=== NODE TEST: $rel ==="
        ( cd middleware && node --import "./$preload" --test --test-reporter=spec "$rel" ) || node_failed=1
    done
    return "$node_failed"
}

# Isolate the DB-backed part of a run from the primary database so suites
# cannot clobber developer/production data. Opt out with ISOLATED_DB=0
# (explicit serial run against the current database) or ALLOW_DEV_DB=1
# (explicit acknowledgement that the developer database may be modified).
# Without isolation and without ALLOW_DEV_DB=1 the run fails closed.
# On success exports DB_NAME pointing at the throwaway database and records
# it in ISOLATED_DB_CREATED for the EXIT trap. Shared by run_db and
# run_integration (a `full` run isolates once; the second call is a no-op
# because DB_NAME no longer equals cobol_db). Requires guard.sh sourced.
ensure_isolated_db() {
    if [ "${ISOLATED_DB:-1}" = "0" ] || [ "$DB_NAME" != "cobol_db" ]; then
        return 0
    fi
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
            db_require_allow_dev_db "isolation failed (migration error)" || exit 1
        fi
    else
        db_require_allow_dev_db "no DDL rights for isolation" || exit 1
    fi
}

run_db() {
    echo "=== TEST HELPER CHECK ==="
    node scripts/check_test_helpers.mjs "$ROOT"
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/guard.sh"
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/lock.sh"
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/report.sh"
    DB_NAME="${DB_NAME:-cobol_db}"
    # Throwaway databases (isolated template + shard workers) are all dropped
    # by one EXIT trap; the isolation block below only records what it made.
    # The lock is held for the whole run so two runners cannot interleave
    # DELETE/reset statements against the same target.
    SHARD_DBS=""
    ISOLATED_DB_CREATED=""
    trap 'cleanup_db_resources; db_lock_release; report_finalize' EXIT
    db_lock_acquire || exit 1
    # shellcheck disable=SC2119
    report_init
    ensure_isolated_db
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
    report_run "serial" tests/db/schema_tests.sh
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

# Cross-domain integration flows (loan -> collection -> payment -> GL ...).
# Every tests/integration/*.sh runs; a failing flow fails the run. In `full`
# mode the database is already isolated by run_db and the lock is already
# held (db_lock_acquire is idempotent); standalone use isolates and locks the
# same way run_db does.
run_integration() {
    echo "=== INTEGRATION FLOWS ==="
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/guard.sh"
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/lock.sh"
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/report.sh"
    DB_NAME="${DB_NAME:-cobol_db}"
    SHARD_DBS=""
    ISOLATED_DB_CREATED=""
    trap 'cleanup_db_resources; db_lock_release; report_finalize' EXIT
    db_lock_acquire || exit 1
    # shellcheck disable=SC2119
    report_init
    ensure_isolated_db
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/db.sh"
    require_db
    export DB_VERIFIED=1
    COBOL_TEST_SERVE=0 db_seed
    export DB_SEEDED=1
    local int_failed=0 f
    for f in tests/integration/*.sh; do
        [ -f "$f" ] || continue
        echo "=== INTEGRATION: $(basename "$f") ==="
        if ! "$f"; then
            echo "FAIL: $(basename "$f")"
            int_failed=1
        fi
    done
    if [ "$int_failed" -ne 0 ]; then
        echo "FAIL: integration flow(s) failed"
        return 1
    fi
    echo "=== INTEGRATION GREEN ==="
}

run_gateway() {
    echo "=== GATEWAY ENDPOINT SMOKE ==="
    # Route JUnit XMLs into the shared report dir so CI uploads one artifact.
    # endpoint_smoke.sh only uses the :junit suite variants when this is set.
    if [ "${REPORT_ENABLED:-1}" = "1" ] && [ -n "${REPORT_DIR:-}" ]; then
        TEST_REPORT_DIR="${TEST_REPORT_DIR:-$REPORT_DIR}" tests/gateway/endpoint_smoke.sh
    else
        tests/gateway/endpoint_smoke.sh
    fi
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
    db-shard)
        # One CI-matrix worker: DB_SHARD_INDEX=0 DB_SHARD_COUNT=4 run_all.sh db-shard.
        # The template database ($DB_NAME) must already be migrated; the worker
        # is created from it, so this mode never touches the template's data.
        case "${DB_SHARD_COUNT:-}" in ''|*[!0-9]*) echo "usage: DB_SHARD_INDEX=<i> DB_SHARD_COUNT=<n> $0 db-shard" >&2; exit 2;; esac
        case "${DB_SHARD_INDEX:-}" in ''|*[!0-9]*) echo "usage: DB_SHARD_INDEX=<i> DB_SHARD_COUNT=<n> $0 db-shard" >&2; exit 2;; esac
        if [ "$DB_SHARD_INDEX" -ge "$DB_SHARD_COUNT" ]; then
            echo "FAIL: DB_SHARD_INDEX ($DB_SHARD_INDEX) >= DB_SHARD_COUNT ($DB_SHARD_COUNT)" >&2
            exit 2
        fi
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/guard.sh"
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/lock.sh"
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/report.sh"
        DB_NAME="${DB_NAME:-cobol_db}"
        SHARD_DBS=""
        ISOLATED_DB_CREATED=""
        trap 'cleanup_db_resources; db_lock_release; report_finalize' EXIT
        # report_init is env-driven (REPORT_DIR); script args are mode selectors, not its input.
        # shellcheck disable=SC2119
        report_init
        ensure_isolated_db
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/db.sh"
        require_db
        run_db_shard_one "$DB_SHARD_COUNT" "$DB_SHARD_INDEX"
        ;;
    probes)
        run_probes
        ;;
    full)
        run_fast
        # CI runs the DB fleet as a matrix of db-shard jobs instead (better
        # isolation: one database per runner). SKIP_DB=1 is CI-only plumbing,
        # not a general flag; local `full` always includes run_db.
        if [ "${SKIP_DB:-0}" = "1" ]; then
            echo "=== DB SKIPPED (covered by the db-shards matrix) ==="
        else
            run_db
        fi
        run_integration
        run_error_harness
        run_gateway
        ;;
    integration)
        run_integration
        ;;
    affected)
        # Base ref via SELECT_BASE env or `run_all.sh affected` auto-detect;
        # SELECT_FILES env bypasses git with an explicit path list.
        run_affected
        ;;
    *)
        echo "unknown mode: $MODE (fast|db|db-shard|full|probes|affected|integration)" >&2
        exit 2
        ;;
esac

echo "=== RUN_ALL ($MODE) GREEN ==="
