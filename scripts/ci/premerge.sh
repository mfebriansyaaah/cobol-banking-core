#!/usr/bin/env bash
# Local pre-merge gate.
#
# GitHub branch protection is unavailable on this private/free repository, so
# this script is the local enforcement point. Run it on the exact commit you
# intend to merge:
#
#   bash scripts/ci/premerge.sh
#
# Set PREMERGE_FULL=1 to also run the slow DB/gateway/full suite locally. CI
# always runs the full suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

STATIC_GATES=(
    check_manifest
    check_route_dispatch
    check_route_conflicts
    check_route_auth
    check_action_coverage
    check_bind_slots
    check_suite_coverage
    check_test_helpers
    check_case_actions
)

echo "=== PREMERGE: static gates ==="
for gate in "${STATIC_GATES[@]}"; do
    echo "--- ${gate}"
    node "scripts/${gate}.mjs" .
done

echo "=== PREMERGE: gate detection probes ==="
tests/probes/run_probes.sh

echo "=== PREMERGE: fast suite ==="
tests/run_all.sh fast

if [ "${PREMERGE_FULL:-0}" = "1" ]; then
    echo "=== PREMERGE: full suite ==="
    tests/run_all.sh full
else
    echo "=== PREMERGE: full suite skipped (CI runs it; set PREMERGE_FULL=1 to run locally) ==="
fi

echo "=== PREMERGE GREEN ==="
