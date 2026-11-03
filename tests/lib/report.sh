# shellcheck shell=bash
# Machine-readable test report collector. Sourced by runners, never executed
# directly. Every DB/table suite record becomes one TSV row:
#   suite<TAB>status<TAB>pass<TAB>fail<TAB>total<TAB>duration_ms<TAB>shard
# where status is pass|fail|missing (missing = exited 0 without a TAP summary).
#
# Fragments are appended under $REPORT_DIR/report.tsv; concurrent shard workers
# serialize appends with flock when available (rows are single short writes, so
# a plain append is already atomic on POSIX, the lock is belt and braces).
#
# Usage:
#   . "$ROOT/tests/lib/report.sh"
#   report_init [dir]            # default: $ROOT/artifacts
#   report_run <shard> <suite> [args...]   # run, time, parse, record; echoes progress
#   report_record <suite> <status> <pass> <fail> <total> <duration_ms> <shard>

REPORT_DIR="${REPORT_DIR:-}"
REPORT_TSV=""

report_init() {
    if [ "${REPORT_ENABLED:-1}" != "1" ]; then
        REPORT_DIR=""
        REPORT_TSV=""
        export REPORT_DIR REPORT_TSV
        return 0
    fi
    local root="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    REPORT_DIR="${1:-${REPORT_DIR:-$root/artifacts}}"
    mkdir -p "$REPORT_DIR" || return 1
    REPORT_TSV="$REPORT_DIR/report.tsv"
    if [ ! -f "$REPORT_TSV" ]; then
        printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$REPORT_TSV"
    fi
    export REPORT_DIR REPORT_TSV
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
    local root="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    node "$root/scripts/test-report.mjs" --report-dir "$REPORT_DIR" \
        --json "$REPORT_DIR/run-all.json" >/dev/null 2>&1 || true
    rm -f "$REPORT_TSV.lock" 2>/dev/null || true
    # Failed-suite reruns: record basenames of failing suites so a later
    # run with --failed picks exactly these up. Always rewritten (a green run
    # clears it); lives under artifacts/ which is gitignored, never committed.
    awk -F'\t' 'NR>1 && $2 == "fail" {print $1}' "$REPORT_TSV" 2>/dev/null | sort -u \
        > "$REPORT_DIR/last-failed.txt" 2>/dev/null || true
    if [ "${PRINT_JSON:-0}" = "1" ] && [ -f "$REPORT_DIR/run-all.json" ]; then
        echo "=== REPORT: $REPORT_DIR/run-all.json ==="
    fi
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
