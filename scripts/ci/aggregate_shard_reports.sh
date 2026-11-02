#!/usr/bin/env bash
# Merge sharded DB reports and verify the fleet (P1-5).
# Usage: bash scripts/ci/aggregate_shard_reports.sh <parts-dir> <out-dir> <shard-count>
#   parts-dir contains one subdirectory per report source (test-reports from
#   the test job, shard-reports-N from each matrix job), each with report.tsv
#   (and the test job's JUnit XMLs/logs, which are copied through).
# Fails when: a part is missing, any suite failed, a shard ran a different
# suite set than the planner assigns it (missing/duplicated/moved suites),
# or a shard's suites disagree with the expected inventory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PARTS="${1:?usage: $0 <parts-dir> <out-dir> <shard-count>}"
OUT="${2:?usage: $0 <parts-dir> <out-dir> <shard-count>}"
TOTAL="${3:?usage: $0 <parts-dir> <out-dir> <shard-count>}"

case "$TOTAL" in ''|*[!0-9]*|0) echo "FAIL: bad shard count: $TOTAL" >&2; exit 2;; esac

mkdir -p "$OUT/logs"
merged_tsv="$OUT/report.tsv"
printf 'suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard\n' > "$merged_tsv"

failed=0

# The test job contributes the non-DB phases (fast/table/smoke/integration/
# gateway rows plus JUnit XMLs); it must be present and green.
if [ ! -f "$PARTS/test-reports/report.tsv" ]; then
    echo "FAIL: missing test job report ($PARTS/test-reports/report.tsv)" >&2
    failed=1
else
    tail -n +2 "$PARTS/test-reports/report.tsv" >> "$merged_tsv"
    if [ "$(wc -l < "$PARTS/test-reports/report.tsv")" -le 1 ]; then
        echo "FAIL: test job report has no suite rows" >&2
        failed=1
    elif awk -F'\t' 'NR>1 && ($2 != "pass" || $4 != 0) {bad=1} END {exit (bad ? 1 : 0)}' "$PARTS/test-reports/report.tsv"; then
        :
    else
        echo "FAIL: test job has failing suites" >&2
        failed=1
    fi
    cp -f "$PARTS"/test-reports/junit-*.xml "$OUT"/ 2>/dev/null || true
    cp -rf "$PARTS"/test-reports/logs/. "$OUT/logs/" 2>/dev/null || true
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
    part="$PARTS/shard-reports-$i/report.tsv"
    if [ ! -f "$part" ]; then
        echo "FAIL: missing shard $i report ($part)" >&2
        failed=1
        continue
    fi
    tail -n +2 "$part" >> "$merged_tsv"
    if awk -F'\t' 'NR>1 && ($2 != "pass" || $4 != 0) {bad=1} END {exit (bad ? 1 : 0)}' "$part"; then
        :
    else
        echo "FAIL: shard $i has failing suites" >&2
        failed=1
    fi
    # Exact-set match against the planner: catches suites lost in transit,
    # run twice, or migrated to another shard by a planner change.
    actual="$(tail -n +2 "$part" | awk -F'\t' '{print $1}' | sort)"
    expected="$(expected_for "$i" | xargs -n1 basename | sort)"
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: shard $i suite set differs from planner assignment" >&2
        comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/  missing: /' >&2 || true
        comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/  extra: /' >&2 || true
        failed=1
    fi
    cp -rf "$PARTS"/shard-reports-"$i"/logs/. "$OUT/logs/" 2>/dev/null || true
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
node "$ROOT/scripts/test-report.mjs" --report-dir "$OUT" --json "$OUT/run-all.json" > /dev/null
echo "OK: $TOTAL shards merged, all green"
