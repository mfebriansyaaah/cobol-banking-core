# shellcheck shell=bash
# Machine-readable test report collector. Sourced by runners, never executed
# directly. Every DB/table suite record becomes one TSV row:
#   suite<TAB>status<TAB>pass<TAB>fail<TAB>total<TAB>duration_ms<TAB>shard
# where status is pass|fail|missing (missing = exited 0 without a TAP summary).
#
# Layout (T-012): every invocation gets its own run directory so repeated runs
# can never contaminate each other:
#   artifacts/runs/<UTC-timestamp>-<pid>/
#     report.tsv  run-all.json  last-failed.txt  build.log
#     logs/       junit/gateway/  junit/db/
#   artifacts/latest -> runs/<UTC-timestamp>-<pid>   (local convenience pointer)
#
# Fragments are appended under the run's report.tsv; concurrent shard workers
# serialize appends with flock when available (rows are single short writes, so
# a plain append is already atomic on POSIX, the lock is belt and braces).
#
# Usage:
#   . "$ROOT/tests/lib/report.sh"
#   report_init [dir]            # default: a fresh $ROOT/artifacts/runs/... dir
#                                # explicit dir (or preset $REPORT_DIR): use as-is, fresh header
#                                # repeat calls in one process reuse the first directory
#   report_run <shard> <suite> [args...]   # run, time, parse, record; echoes progress
#   report_record <suite> <status> <pass> <fail> <total> <duration_ms> <shard>
#   report_locate_tsv <dir>      # print the single report.tsv under <dir>
#                                # (flat or runs/*/); fail when zero or many
#   report_emit_junit [dir]      # convert TAP logs to junit/db/*.xml (best effort)

REPORT_DIR="${REPORT_DIR:-}"
REPORT_TSV=""
REPORT_INITIALIZED="${REPORT_INITIALIZED:-0}"

# Directory this library lives in (stable even when callers override $ROOT
# to redirect artifacts elsewhere, e.g. in tests).
_REPORT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
_REPORT_REPO_ROOT="$(cd "$_REPORT_LIB_DIR/../.." 2>/dev/null && pwd)"

report_init() {
    if [ "${REPORT_ENABLED:-1}" != "1" ]; then
        REPORT_DIR=""
        REPORT_TSV=""
        export REPORT_DIR REPORT_TSV
        return 0
    fi
    if [ "${REPORT_INITIALIZED:-0}" = "1" ] && [ -n "${REPORT_TSV:-}" ]; then
        return 0
    fi
    local root="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    if [ $# -gt 0 ] || [ -n "${REPORT_DIR:-}" ]; then
        # Explicit directory (CI jobs, nightly runs, --report-dir callers):
        # use as-is with a fresh header. Callers that need isolation must
        # pass distinct directories (concurrent local runs do).
        REPORT_DIR="${1:-$REPORT_DIR}"
        mkdir -p "$REPORT_DIR" || return 1
        printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$REPORT_DIR/report.tsv"
    else
        REPORT_DIR="$root/artifacts/runs/$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)-$$"
        mkdir -p "$REPORT_DIR" || return 1
        printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$REPORT_DIR/report.tsv"
        ln -sfn "$REPORT_DIR" "$root/artifacts/latest" 2>/dev/null || \
            echo "WARN: cannot update artifacts/latest pointer" >&2
    fi
    REPORT_TSV="$REPORT_DIR/report.tsv"
    REPORT_INITIALIZED=1
    export REPORT_DIR REPORT_TSV REPORT_INITIALIZED
    return 0
}

# Append one row. Arguments must already be integers except suite/shard/status.
report_record() {
    local suite="$1" status="$2" pass="$3" fail="$4" total="$5" duration_ms="$6" shard="$7"
    [ -n "$REPORT_TSV" ] || return 0
    suite="$(printf '%s' "$suite" | tr '\t\n\r' '___')"
    shard="$(printf '%s' "$shard" | tr '\t\n\r' '___')"
    case "$status" in
        pass|fail|missing) ;;
        *) status="fail" ;;
    esac
    local row
    row="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$suite" "$status" "$pass" "$fail" "$total" "$duration_ms" "$shard")"
    if command -v flock >/dev/null 2>&1; then
        { flock -x 200; printf '%s\n' "$row" >> "$REPORT_TSV"; } 200>"$REPORT_TSV.lock" 2>/dev/null || \
            printf '%s\n' "$row" >> "$REPORT_TSV"
    else
        printf '%s\n' "$row" >> "$REPORT_TSV"
    fi
    return 0
}

# Write artifacts/run-all.json from the TSV (best effort, never fails the run).
# Called from an EXIT trap so failure runs also produce a report.
report_finalize() {
    [ "${REPORT_ENABLED:-1}" = "1" ] || return 0
    [ -n "${REPORT_TSV:-}" ] || return 0
    [ -f "$REPORT_TSV" ] || return 0
    command -v node >/dev/null 2>&1 || return 0
    node "$_REPORT_REPO_ROOT/scripts/test-report.mjs" --report-dir "$REPORT_DIR" \
        --json "$REPORT_DIR/run-all.json" >/dev/null 2>&1 || true
    rm -f "$REPORT_TSV.lock" 2>/dev/null || true
    # Failed-suite reruns: record basenames of failing suites so a later
    # run with --failed picks exactly these up. Always rewritten (a green run
    # clears it); lives next to report.tsv, never committed.
    awk -F'\t' 'NR>1 && $2 == "fail" {print $1}' "$REPORT_TSV" 2>/dev/null | sort -u \
        > "$REPORT_DIR/last-failed.txt" 2>/dev/null || true
    # DB/table TAP logs become JUnit for PR annotations (WP-1.5 consumes
    # junit/db/; gateway JUnit already lands in junit/gateway/).
    report_emit_junit "$REPORT_DIR" || true
    if [ "${PRINT_JSON:-0}" = "1" ] && [ -f "$REPORT_DIR/run-all.json" ]; then
        echo "=== REPORT: $REPORT_DIR/run-all.json ==="
    fi
    return 0
}

# Locate the single report.tsv under a directory: the flat file or exactly
# one runs/*/report.tsv. Prints the path; fails when there is none (nothing
# ran there) or more than one (ambiguous: point at one run or clean up).
# Used by offline checks and scripts/ci/aggregate_shard_reports.sh.
report_locate_tsv() {
    local dir="${1:?usage: report_locate_tsv <dir>}"
    local cands="" f
    [ -f "$dir/report.tsv" ] && cands="${cands}${dir}/report.tsv
"
    for f in "$dir"/runs/*/report.tsv; do
        [ -f "$f" ] || continue
        cands="${cands}${f}
"
    done
    cands="$(printf '%s' "$cands" | sed '/^$/d')"
    local n=0
    [ -n "$cands" ] && n="$(printf '%s\n' "$cands" | wc -l)"
    if [ "$n" -eq 0 ]; then
        echo "FAIL: no report.tsv under $dir (run a test mode first)" >&2
        return 1
    fi
    if [ "$n" -gt 1 ]; then
        echo "FAIL: $n report.tsv files under $dir; point at one run instead:" >&2
        printf '%s\n' "$cands" | sed 's/^/  /' >&2
        return 1
    fi
    printf '%s\n' "$cands"
    return 0
}

# Convert TAP suite logs to JUnit XML under <dir>/junit/db/ (best effort,
# never fails the run). Only DB/table/schema logs are converted; gateway
# suites already produce real JUnit under junit/gateway/.
report_emit_junit() {
    local dir="${1:-${REPORT_DIR:-}}"
    [ -n "$dir" ] || return 0
    [ -d "$dir/logs" ] || return 0
    command -v node >/dev/null 2>&1 || return 0
    local tap="$_REPORT_REPO_ROOT/scripts/tap-to-junit.mjs"
    [ -f "$tap" ] || return 0
    mkdir -p "$dir/junit/db" 2>/dev/null || return 0
    local log base name
    for log in "$dir"/logs/*.log; do
        [ -f "$log" ] || continue
        base="$(basename "$log" .log)"
        case "$base" in
            *_db_tests.sh|schema_tests.sh|table_runner.sh) ;;
            *) continue ;;
        esac
        name="${base%.sh}"
        node "$tap" --suite "$name" \
            --output "$dir/junit/db/$name.xml" "$log" >/dev/null 2>&1 || true
    done
    return 0
}

# Now in milliseconds. Date +%s%N is Linux-only; fall back to seconds.
_now_ms() {
    local ns
    ns="$(date +%s%N 2>/dev/null || echo "")"
    case "$ns" in
        ''|*[!0-9]*) date +%s | awk '{print $1 * 1000}' ;;
        *) echo "$((ns / 1000000))" ;;
    esac
}

# Run one suite script, record the result, echo a one-line progress summary.
# Returns the suite's exit status, except a suite that exits 0 without a TAP
# summary is reported as `missing` and returns 1 (P0-3 gates on this).
report_run() {
    local shard="$1"
    shift
    local suite="$1"
    # Reporting disabled: run the suite directly with no recording.
    if [ "${REPORT_ENABLED:-1}" != "1" ] || [ -z "${REPORT_TSV:-}" ]; then
        "$@"
        return $?
    fi
    local name
    name="$(basename "$suite")"
    local log="$REPORT_DIR/logs/$name.log"
    mkdir -p "$REPORT_DIR/logs" 2>/dev/null || true
    local start end duration_ms rc=0
    start="$(_now_ms)"
    if "$@" >"$log" 2>&1; then
        rc=0
    else
        rc=$?
    fi
    end="$(_now_ms)"
    duration_ms=$((end - start))
    [ "$duration_ms" -ge 0 ] 2>/dev/null || duration_ms=0
    local summary pass fail total status
    summary="$(grep -E '^# pass=' "$log" 2>/dev/null | tail -1 || echo "")"
    if [ -z "$summary" ]; then
        status="missing"
        pass=0; fail=0; total=0
        rc=1
    else
        pass="$(printf '%s' "$summary" | sed -n 's/.*pass=\([0-9][0-9]*\).*/\1/p')"
        fail="$(printf '%s' "$summary" | sed -n 's/.*fail=\([0-9][0-9]*\).*/\1/p')"
        total="$(printf '%s' "$summary" | sed -n 's/.*total=\([0-9][0-9]*\).*/\1/p')"
        : "${pass:=0}" "${fail:=0}" "${total:=0}"
        if [ "$rc" -eq 0 ] && [ "$fail" = "0" ] && [ "$total" != "0" ]; then
            status="pass"
        elif [ "$total" = "0" ]; then
            # A suite that ran zero assertions proves nothing: treat it like
            # a missing summary so the run fails instead of looking green.
            status="missing"
            rc=1
        else
            status="fail"
            rc=1
        fi
    fi
    report_record "$name" "$status" "$pass" "$fail" "$total" "$duration_ms" "$shard"
    echo "[$status] [shard $shard] $name (pass=$pass fail=$fail total=$total ${duration_ms}ms)"
    return "$rc"
}
