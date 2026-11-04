#!/usr/bin/env bash
# Merge sharded DB reports and verify the fleet (P1-5).
# Usage: bash scripts/ci/aggregate_shard_reports.sh <parts-dir> <out-dir> <shard-count>
#   parts-dir contains one subdirectory per report source (test-reports from
#   the test job, shard-reports-N from each matrix job), each with report.tsv
#   at its root or under runs/<id>/ (per-run dirs, T-012), plus the test job's
#   gateway JUnit XMLs (junit/gateway/) and logs, which are copied through.
#   Merged TAP logs are converted to junit/db/ XMLs for PR annotations.
# Fails when: a part is missing, any suite failed, a shard ran a different
# suite set than the planner assigns it (missing/duplicated/moved suites),
# or a shard's suites disagree with the expected inventory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Shared report helpers (report_locate_tsv, report_emit_junit). Sourcing is
# side-effect free: it only sets REPORT_DIR/REPORT_TSV defaults and functions.
# shellcheck disable=SC1091
. "$ROOT/tests/lib/report.sh"

PARTS="${1:?usage: $0 <parts-dir> <out-dir> <shard-count>}"
OUT="${2:?usage: $0 <parts-dir> <out-dir> <shard-count>}"
TOTAL="${3:?usage: $0 <parts-dir> <out-dir> <shard-count>}"

case "$TOTAL" in ''|*[!0-9]*|0) echo "FAIL: bad shard count: $TOTAL" >&2; exit 2;; esac

mkdir -p "$OUT/logs"
merged_tsv="$OUT/report.tsv"
printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$merged_tsv"

failed=0

# The test job contributes the non-DB phases (fast/table/smoke/integration/
# gateway rows plus gateway JUnit XMLs); it must be present and green.
# Reports may live at the part root (legacy) or under runs/<id>/ (per-run
# dirs, T-012); report_locate_tsv resolves exactly one, failing otherwise.
test_part_tsv="$(report_locate_tsv "$PARTS/test-reports")" || { failed=1; test_part_tsv=""; }
test_part_dir=""
if [ -n "$test_part_tsv" ]; then
    test_part_dir="$(dirname "$test_part_tsv")"
    tail -n +2 "$test_part_tsv" >> "$merged_tsv"
    if [ "$(wc -l < "$test_part_tsv")" -le 1 ]; then
        echo "FAIL: test job report has no suite rows" >&2
        failed=1
    elif awk -F'\t' 'NR>1 && ($2 != "pass" || $4 != 0) {bad=1} END {exit (bad ? 1 : 0)}' "$test_part_tsv"; then
        :
    else
        echo "FAIL: test job has failing suites" >&2
        failed=1
    fi
    # Gateway JUnit: namespaced layout first, legacy flat files as fallback.
    mkdir -p "$OUT/junit/gateway" 2>/dev/null || true
    if [ -d "$test_part_dir/junit/gateway" ]; then
        cp -f "$test_part_dir"/junit/gateway/*.xml "$OUT/junit/gateway/" 2>/dev/null || true
    else
        cp -f "$test_part_dir"/junit-*.xml "$OUT/junit/gateway/" 2>/dev/null || true
    fi
    cp -rf "$test_part_dir"/logs/. "$OUT/logs/" 2>/dev/null || true
fi

# Expected suite set per shard, straight from the planner both runners use.
expected_for() {
    local idx="$1" line
    if [ "$idx" = "0" ]; then
        echo "schema_tests.sh"
    fi
    while IFS= read -r line; do
        case "$line" in
            "$idx "*) echo "${line#* }" ;;
        esac
    done <<EOF
$(node scripts/shard_suites.mjs "$TOTAL" "$ROOT")
EOF
}

for i in $(seq 0 $((TOTAL - 1))); do
    part_tsv=""
    if ! part_tsv="$(report_locate_tsv "$PARTS/shard-reports-$i")"; then
        echo "FAIL: missing shard $i report (no report.tsv under $PARTS/shard-reports-$i)" >&2
        failed=1
        continue
    fi
    part_dir="$(dirname "$part_tsv")"
    tail -n +2 "$part_tsv" >> "$merged_tsv"
    if awk -F'\t' 'NR>1 && ($2 != "pass" || $4 != 0) {bad=1} END {exit (bad ? 1 : 0)}' "$part_tsv"; then
        :
    else
        echo "FAIL: shard $i has failing suites" >&2
        failed=1
    fi
    # Exact-set match against the planner: catches suites lost in transit,
    # run twice, or migrated to another shard by a planner change.
    actual="$(tail -n +2 "$part_tsv" | awk -F'\t' '{print $1}' | sort)"
    expected="$(expected_for "$i" | xargs -n1 basename | sort)"
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: shard $i suite set differs from planner assignment" >&2
        comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/  missing: /' >&2 || true
        comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/  extra: /' >&2 || true
        failed=1
    fi
    cp -rf "$part_dir"/logs/. "$OUT/logs/" 2>/dev/null || true
    echo "shard $i: $(echo "$actual" | wc -l) suites verified"
done

# Every db suite file must appear in exactly one shard (plus schema_tests on
# shard 0): guards against planner/reporter drift in either direction.
all_expected="$( { echo "schema_tests.sh"; node scripts/shard_suites.mjs "$TOTAL" "$ROOT" | awk '{print $2}' | xargs -n1 basename; } | sort)"
all_actual="$(tail -n +2 "$merged_tsv" | awk -F'\t' '{print $1}' | grep -E '_db_tests\.sh$|schema_tests\.sh' | sort)"
if [ "$all_actual" != "$all_expected" ]; then
    echo "FAIL: fleet-wide suite inventory differs from tests/db" >&2
    comm -23 <(printf '%s\n' "$all_expected") <(printf '%s\n' "$all_actual") | sed 's/^/  missing: /' >&2 || true
    comm -13 <(printf '%s\n' "$all_expected") <(printf '%s\n' "$all_actual") | sed 's/^/  extra: /' >&2 || true
    failed=1
fi
echo "fleet inventory: $(echo "$all_actual" | wc -l) db suites across $TOTAL shards"

if [ "$failed" -ne 0 ]; then
    echo "FAIL: shard aggregation found problems" >&2
    exit 1
fi
# DB/table TAP logs become JUnit under merged/junit/db/ for PR annotations
# (gateway JUnit was already copied to merged/junit/gateway/ above).
report_emit_junit "$OUT" || true
node "$ROOT/scripts/test-report.mjs" --report-dir "$OUT" --json "$OUT/run-all.json" > /dev/null
echo "OK: $TOTAL shards merged, all green"
