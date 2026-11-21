#!/usr/bin/env bash
# Tests for run_all.sh CLI parsing and tests/lib/workdir.sh (P1-7).
# Offline parts always run. The live part (one real shard) runs only when
# the current database is migrated AND the migrate user can create databases;
# otherwise it SKIPBypasses with a reason (same convention as db_available).
# Usage: tests/scripts/test_run_all_cli.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

RUNALL="bash tests/run_all.sh"

# --- --help lists every flag and mode -------------------------------------
help_out="$($RUNALL --help 2>&1)"
help_rc=$?
if [ "$help_rc" = "0" ]; then
    ok "--help exits 0"
else
    not_ok "--help exits 0 (got $help_rc)"
fi
for token in --mode --only --failed --repeat --keep-logs --no-build --allow-dev-db --json --no-report --case-file --node-suite --node-file --integration-flow "fast db db-shard db-selected full probes affected integration gates ci-test"; do
    case "$help_out" in
        *"$token"*) ok "help mentions $token" ;;
        *) not_ok "help mentions $token" ;;
    esac
done

# --- validation matrix: every bad invocation exits 2 ---------------------
check_rc2() {
    # $1 = description, rest = args
    local desc="$1"
    shift
    rc=0
    # shellcheck disable=SC2086
    $RUNALL "$@" >/dev/null 2>&1 || rc=$?
    if [ "$rc" = "2" ]; then
        ok "$desc exits 2"
    else
        not_ok "$desc exits 2 (got $rc)"
    fi
}
check_rc2 "unknown flag" --bogus
check_rc2 "extra positional" db extra
check_rc2 "missing --mode value" --mode
check_rc2 "missing --only value" --only
check_rc2 "missing --repeat value" --repeat
check_rc2 "repeat zero" --repeat 0 db
check_rc2 "repeat non-numeric" --repeat x db
check_rc2 "bad mode" frobnicate
check_rc2 "--only=empty" --only= db
check_rc2 "missing --case-file value" --case-file
check_rc2 "missing --node-suite value" --node-suite
check_rc2 "missing --node-file value" --node-file
check_rc2 "missing --integration-flow value" --integration-flow
check_rc2 "bad --node-suite" --node-suite bogus ci-test
check_rc2 "nonexistent --case-file" --case-file tests/cobol/cases/nope.cases ci-test
check_rc2 "nonexistent --node-file" --node-file middleware/test/nope.test.js ci-test
check_rc2 "nonexistent --integration-flow" --integration-flow nope ci-test

# --- --failed without a last-failed file fails closed ---------------------
rm -f artifacts/last-failed.txt artifacts/latest/last-failed.txt
rc=0
$RUNALL --failed db >/dev/null 2>&1 || rc=$?
if [ "$rc" = "2" ]; then
    ok "--failed without last-failed.txt exits 2"
else
    not_ok "--failed without last-failed.txt exits 2 (got $rc)"
fi

# --- workdir helper --------------------------------------------------------
# shellcheck disable=SC1091
. "$ROOT/tests/lib/workdir.sh"
wd="$(make_workdir cli-test)" || { not_ok "make_workdir creates a directory"; wd=""; }
if [ -n "${wd:-}" ] && [ -d "$wd" ]; then
    ok "make_workdir creates a directory"
    rm -rf "$wd"
else
    not_ok "make_workdir creates a directory"
fi
evil="$(make_workdir '../../evil-cli-test')" || evil=""
case "$evil" in
    "${TMPDIR:-/tmp}"/*) ok "make_workdir sanitizes tags (stays in TMPDIR: $evil)" ;;
    *) not_ok "make_workdir sanitizes tags (got: $evil)" ;;
esac
if [ -n "${evil:-}" ] && [ -d "$evil" ]; then
    rm -rf "$evil"
fi
if [ -e /tmp/evil-cli-test ] || [ -e "${TMPDIR:-/tmp}/evil-cli-test" ]; then
    not_ok "no escape from TMPDIR"
else
    ok "no escape from TMPDIR"
fi

# --- last-failed recording via report.sh (offline) -------------------------
# shellcheck disable=SC1091
. "$ROOT/tests/lib/report.sh"
TMPREP="$(mktemp -d "${TMPDIR:-/tmp}/cli-report.XXXXXX")"
printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$TMPREP/report.tsv"
printf 'a_db_tests.sh\tfail\t0\t1\t1\t10\tserial\n' >> "$TMPREP/report.tsv"
printf 'b_db_tests.sh\tpass\t5\t0\t5\t20\tserial\n' >> "$TMPREP/report.tsv"
REPORT_DIR="$TMPREP" REPORT_TSV="$TMPREP/report.tsv" REPORT_ENABLED=1 PRINT_JSON=0 report_finalize
if [ "$(cat "$TMPREP/last-failed.txt" 2>/dev/null)" = "a_db_tests.sh" ]; then
    ok "report_finalize records failing suites"
else
    not_ok "report_finalize records failing suites"
fi
printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$TMPREP/report.tsv"
printf 'a_db_tests.sh\tpass\t1\t0\t1\t10\tserial\n' >> "$TMPREP/report.tsv"
REPORT_DIR="$TMPREP" REPORT_TSV="$TMPREP/report.tsv" REPORT_ENABLED=1 PRINT_JSON=0 report_finalize
if [ ! -s "$TMPREP/last-failed.txt" ]; then
    ok "report_finalize clears last-failed on green runs"
else
    not_ok "report_finalize clears last-failed on green runs"
fi
rm -rf "$TMPREP"

# --- live single shard (only when the environment supports it) ------------
live_ready() {
    command -v mysql >/dev/null 2>&1 || return 1
    DB_NAME="${DB_NAME:-cobol_db}" DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}" \
        DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}" DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_pass}" \
        ./database/migrate.sh --check >/dev/null 2>&1 || return 1
    local probe="cobol_db_cli_probe_$$"
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_MIGRATE_USER:-cobol_user}" -p"${DB_MIGRATE_PASS:-cobol_pass}" \
        -e "CREATE DATABASE \`$probe\`; DROP DATABASE \`$probe\`;" >/dev/null 2>&1 || return 1
    return 0
}
# --- ci-test selection (needs the built binary; flows need the DB too) -----
if [ -x cobol/bin/main_logic ]; then
    TMPCT="$(mktemp -d "${TMPDIR:-/tmp}/ci-test.XXXXXX")"
    if REPORT_DIR="$TMPCT" SELECT_INTEGRATION_MODE=none \
        bash tests/run_all.sh ci-test --case-file tests/cobol/cases/loan.cases > "$TMPCT/out.log" 2>&1; then
        if grep -q '^table_runner.sh[[:space:]]*pass' "$TMPCT/report.tsv" 2>/dev/null \
            && grep -q 'COBOL TABLE TESTS (selected)' "$TMPCT/out.log" 2>/dev/null; then
            ok "ci-test runs the selected case file"
        else
            not_ok "ci-test runs the selected case file"; tail -5 "$TMPCT/out.log"
        fi
    else
        not_ok "ci-test runs the selected case file (exit $?)"; tail -5 "$TMPCT/out.log"
    fi
    rm -rf "$TMPCT"

    TMPCT2="$(mktemp -d "${TMPDIR:-/tmp}/ci-test-node.XXXXXX")"
    if REPORT_DIR="$TMPCT2" SELECT_INTEGRATION_MODE=none \
        bash tests/run_all.sh ci-test --node-file middleware/test/contract.test.js > "$TMPCT2/out.log" 2>&1; then
        if grep -q 'NODE TEST: test/contract.test.js' "$TMPCT2/out.log" 2>/dev/null \
            && ! grep -q 'NODE TEST: test/gateway.test.js' "$TMPCT2/out.log" 2>/dev/null; then
            ok "ci-test runs only the selected node file"
        else
            not_ok "ci-test runs only the selected node file"; tail -5 "$TMPCT2/out.log"
        fi
    else
        not_ok "ci-test runs only the selected node file (exit $?)"; tail -5 "$TMPCT2/out.log"
    fi
    rm -rf "$TMPCT2"

    if live_ready; then
        first_flow="$(basename "$(printf "%s\n" tests/integration/*.sh | head -n 1)" .sh)"
        if [ -n "$first_flow" ]; then
            if REPORT_DIR=/tmp/cli-ci-flow SELECT_INTEGRATION_MODE=selected \
                SELECT_INTEGRATION_FLOWS="$first_flow" \
                bash tests/run_all.sh ci-test > /tmp/cli-ci-flow.log 2>&1; then
                if grep -q "INTEGRATION: $first_flow.sh" /tmp/cli-ci-flow.log 2>/dev/null; then
                    ok "ci-test runs only the selected integration flow"
                else
                    not_ok "ci-test runs only the selected integration flow"; tail -5 /tmp/cli-ci-flow.log
                fi
            else
                not_ok "ci-test runs only the selected integration flow (exit $?)"; tail -5 /tmp/cli-ci-flow.log
            fi
            rm -rf /tmp/cli-ci-flow /tmp/cli-ci-flow.log
        fi
    else
        ok "SKIP ci-test integration flow (no migrated database with DDL rights here)"
    fi
else
    ok "SKIP ci-test selected (binary not built here)"
fi

if live_ready; then
    total="$(printf "%s\n" tests/db/*_db_tests.sh | wc -l)"
    if DB_SHARD_INDEX=0 DB_SHARD_COUNT="$total" REPORT_DIR=/tmp/cli-live \
        bash tests/run_all.sh db-shard --only schema_tests > /tmp/cli-live.log 2>&1; then
        if grep -q "^schema_tests.sh\s*pass" /tmp/cli-live/report.tsv 2>/dev/null \
            && [ "$(grep -c . /tmp/cli-live/report.tsv)" = "2" ]; then
            ok "live shard runs exactly the selected suite"
        else
            not_ok "live shard runs exactly the selected suite"; tail -3 /tmp/cli-live.log
        fi
    else
        not_ok "live shard runs exactly the selected suite (exit $?)"; tail -3 /tmp/cli-live.log
    fi
    rm -rf /tmp/cli-live /tmp/cli-live.log
else
    ok "SKIP live shard (no migrated database with DDL rights here)"
fi

echo "=== RUN_ALL CLI: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
