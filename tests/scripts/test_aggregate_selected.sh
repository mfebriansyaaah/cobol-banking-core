#!/usr/bin/env bash
# Offline fixture for the impact-selected aggregate path.
# Verifies selected-reports are merged and missing selected artifacts fail.
# Usage: tests/scripts/test_aggregate_selected.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aggregate-selected.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PARTS="$WORK/parts"
OUT="$WORK/out"
mkdir -p "$PARTS/test-reports" "$PARTS/coverage-reports" "$PARTS/selected-reports"
printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$PARTS/test-reports/report.tsv"
printf 'smoke\tpass\t1\t0\t1\t0\tfast\n' >> "$PARTS/test-reports/report.tsv"
printf '<testsuites tests="1"><testcase name="gw"/></testsuites>\n' > "$PARTS/coverage-reports/junit.xml"
printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$PARTS/selected-reports/report.tsv"
printf 'account_db_tests.sh\tpass\t42\t0\t42\t100\tselected\n' >> "$PARTS/selected-reports/report.tsv"

if ! SELECT_MODE=selected SELECTED_DB_SUITES='tests/db/account_db_tests.sh' \
    bash "$ROOT/scripts/ci/aggregate_shard_reports.sh" "$PARTS" "$OUT" 2 >/dev/null 2>&1; then
    echo "not ok - selected aggregate should pass"
    exit 1
fi
if ! grep -q '^account_db_tests.sh' "$OUT/report.tsv"; then
    echo "not ok - selected suite missing from merged report"
    exit 1
fi
echo "ok - selected aggregate merges the selected report"

rm -rf "$PARTS/selected-reports"
if SELECT_MODE=selected SELECTED_DB_SUITES='tests/db/account_db_tests.sh' \
    bash "$ROOT/scripts/ci/aggregate_shard_reports.sh" "$PARTS" "$OUT" 2 >/dev/null 2>&1; then
    echo "not ok - missing selected-reports must fail"
    exit 1
fi
echo "ok - missing selected-reports fails closed"

# Selected mode without suites (e.g. middleware-only change): test and
# coverage reports merge with no DB part.
rm -rf "$PARTS/selected-reports"
if ! SELECT_MODE=selected SELECTED_DB_SUITES='' \
    bash "$ROOT/scripts/ci/aggregate_shard_reports.sh" "$PARTS" "$OUT" 2 >/dev/null 2>&1; then
    echo "not ok - selected aggregate without suites should pass"
    exit 1
fi
if ! grep -q '^smoke' "$OUT/report.tsv"; then
    echo "not ok - test rows missing from suite-less merged report"
    exit 1
fi
echo "ok - selected aggregate passes without DB suites"

# Missing test-reports must fail even in selected mode.
rm -rf "$PARTS/test-reports"
if SELECT_MODE=selected SELECTED_DB_SUITES='' \
    bash "$ROOT/scripts/ci/aggregate_shard_reports.sh" "$PARTS" "$OUT" 2 >/dev/null 2>&1; then
    echo "not ok - missing test-reports must fail"
    exit 1
fi
echo "ok - missing test-reports fails closed"
