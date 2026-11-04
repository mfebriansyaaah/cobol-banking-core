#!/usr/bin/env bash
# Regression test for per-run report directories (T-012/T-013).
# Two consecutive report cycles must not contaminate each other: each run
# gets its own artifacts/runs/<ts>-<pid>/ directory with exactly one row per
# suite, artifacts/latest points at the newest run, and report_locate_tsv
# refuses zero or ambiguous report.tsv files instead of guessing.
# No database or build needed (report.sh + tap-to-junit only).
# Usage: tests/scripts/test_report_isolation.sh (or via tests/scripts/run.sh)
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/report-isolation.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# --- 1. two consecutive runs stay isolated ---
(cd "$ROOT" && ROOT="$WORK" bash -c '
    . tests/lib/report.sh
    report_init
    report_record "iso_a" pass 1 0 1 5 fast
    report_finalize
' >/dev/null 2>&1)
(cd "$ROOT" && ROOT="$WORK" bash -c '
    . tests/lib/report.sh
    report_init
    report_record "iso_b" fail 0 1 1 7 fast
    report_finalize
' >/dev/null 2>&1)

RUNS="$(ls "$WORK/artifacts/runs" 2>/dev/null | sort)"
if [ "$(printf '%s\n' "$RUNS" | wc -l)" = "2" ]; then
    ok "two runs created two run directories"
else
    not_ok "two runs created two run directories (got: $RUNS)"
fi

BAD_ROWS=0
for d in "$WORK"/artifacts/runs/*/; do
    [ -f "$d/report.tsv" ] || { BAD_ROWS=1; continue; }
    [ "$(wc -l < "$d/report.tsv")" = "2" ] || BAD_ROWS=1
done
if [ "$BAD_ROWS" = "0" ]; then
    ok "each run has exactly one data row"
else
    not_ok "each run has exactly one data row"
fi

LATEST="$(readlink "$WORK/artifacts/latest" 2>/dev/null || true)"
LAST_RUN="$(printf '%s\n' "$RUNS" | tail -1)"
if [ -n "$LATEST" ] && [ -n "$LAST_RUN" ]; then
    case "$LATEST" in
        *"$LAST_RUN") ok "artifacts/latest points at the newest run" ;;
        *) not_ok "artifacts/latest points at the newest run (got: $LATEST)" ;;
    esac
else
    not_ok "artifacts/latest points at the newest run (got: $LATEST)"
fi

if [ "$(cat "$WORK/artifacts/latest/last-failed.txt" 2>/dev/null)" = "iso_b" ]; then
    ok "last-failed.txt reflects only the latest run"
else
    not_ok "last-failed.txt reflects only the latest run"
fi

TOTAL="$(node -e 'const j=require(process.argv[1]);console.log(j.totals.total)' "$WORK/artifacts/latest/run-all.json" 2>/dev/null || echo "?")"
if [ "$TOTAL" = "1" ]; then
    ok "latest run-all.json holds only the latest run (total=1)"
else
    not_ok "latest run-all.json holds only the latest run (got total=$TOTAL)"
fi

# --- 2. report_locate_tsv: one file ok, zero/many fail ---
TAPLOG="$WORK/artifacts/runs/$LAST_RUN/logs"
LOCATE() { (cd "$ROOT" && ROOT="$WORK" bash -c ". tests/lib/report.sh; report_locate_tsv \"\$0\"" "$1" 2>/dev/null); }

FLAT="$WORK/flat"
mkdir -p "$FLAT"
printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\ns\tpass\t1\t0\t1\t1\tx\n' > "$FLAT/report.tsv"
if [ "$(LOCATE "$FLAT")" = "$FLAT/report.tsv" ]; then
    ok "locate finds a flat report.tsv"
else
    not_ok "locate finds a flat report.tsv"
fi

NEST="$WORK/nested"
mkdir -p "$NEST/runs/20260101T000000Z-1" "$NEST/runs/20260102T000000Z-2"
printf 'h\n' > "$NEST/runs/20260101T000000Z-1/report.tsv"
printf 'h\n' > "$NEST/runs/20260102T000000Z-2/report.tsv"
if LOCATE "$NEST" >/dev/null; then
    not_ok "locate refuses ambiguous nested reports"
else
    ok "locate refuses ambiguous nested reports"
fi

BOTH="$WORK/both"
mkdir -p "$BOTH/runs/20260101T000000Z-1"
printf 'h\n' > "$BOTH/report.tsv"
printf 'h\n' > "$BOTH/runs/20260101T000000Z-1/report.tsv"
if LOCATE "$BOTH" >/dev/null; then
    not_ok "locate refuses flat+nested ambiguity"
else
    ok "locate refuses flat+nested ambiguity"
fi

EMPTY_FIX="$WORK/emptyfix"
mkdir -p "$EMPTY_FIX"
if LOCATE "$EMPTY_FIX" >/dev/null; then
    not_ok "locate refuses a directory with no report"
else
    ok "locate refuses a directory with no report"
fi

# --- 3. TAP logs convert to junit/db (gateway logs untouched) ---
SAMPLE_RUN="$WORK/artifacts/runs/$LAST_RUN"
mkdir -p "$SAMPLE_RUN/logs"
printf '1..2\nok 1 - first\nnot ok 2 - second\n  # expected /x/\n  # got:      y\n# pass=1 fail=1 total=2\n' > "$SAMPLE_RUN/logs/sample_db_tests.sh.log"
printf 'noise, not TAP\n' > "$SAMPLE_RUN/logs/gateway_fast.log"
(cd "$ROOT" && ROOT="$WORK" bash -c ". tests/lib/report.sh; report_emit_junit \"$SAMPLE_RUN\"" >/dev/null 2>&1)
if [ -f "$SAMPLE_RUN/junit/db/sample_db_tests.xml" ] && grep -q '<testsuite' "$SAMPLE_RUN/junit/db/sample_db_tests.xml"; then
    ok "db TAP log converts to junit/db XML"
else
    not_ok "db TAP log converts to junit/db XML"
fi
if [ ! -f "$SAMPLE_RUN/junit/db/gateway_fast.xml" ]; then
    ok "gateway logs are not converted to junit/db"
else
    not_ok "gateway logs are not converted to junit/db"
fi

echo "=== REPORT ISOLATION: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "=== REPORT ISOLATION GREEN ==="
exit 0
