#!/usr/bin/env bash
# Local pre-merge gate.
#
# GitHub branch protection is unavailable on this private/free repository, so
# this script is the local enforcement point. Run it on the exact commit you
# intend to merge:
#
#   bash scripts/ci/premerge.sh [--full] [--probes] [--docs] [--all]
#
#   --full    also run the slow DB/gateway/full suite locally (CI always does)
#   --probes  also run the gate-detection probes (11 mutations x 14 gates;
#             CI runs them in its build job)
#   --docs    also run the docs gate (CI runs it in its build job)
#   --all     --full --probes --docs together
#
# The same toggles exist as env vars for CI-style invocation:
# PREMERGE_FULL=1, PREMERGE_PROBES=1, PREMERGE_DOCS=1. Flags and env vars are
# equivalent; either one enables the section.
#
# Default (no flags) runs only the fast suite: static gates, build, table
# tests, and smoke. DB/gateway/full, probes, and docs are skipped locally and
# reported as skipped; CI covers them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \?//'
}

FULL=0
PROBES=0
DOCS=0
for _arg in "$@"; do
    case "$_arg" in
        --full) FULL=1 ;;
        --probes) PROBES=1 ;;
        --docs) DOCS=1 ;;
        --all) FULL=1; PROBES=1; DOCS=1 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "unknown flag: $_arg (see --help)" >&2; exit 2 ;;
    esac
done
[ "${PREMERGE_FULL:-0}" = "1" ] && FULL=1
[ "${PREMERGE_PROBES:-0}" = "1" ] && PROBES=1
[ "${PREMERGE_DOCS:-0}" = "1" ] && DOCS=1

# tests/run_all.sh fast runs every static gate except check_docs and the
# runtime count gate (syntax, manifest, route dispatch/conflicts/auth, action
# coverage, bind slots, suite inventory, field order, test helpers, case
# actions) plus build, table tests and smoke, so they are not repeated here.
echo "=== PREMERGE: fast suite (includes static gates) ==="
tests/run_all.sh fast

if [ "$DOCS" = "1" ]; then
    echo "=== PREMERGE: docs gate ==="
    node scripts/check_docs.mjs .
else
    echo "=== PREMERGE: docs skipped (CI runs it; pass --docs to run locally) ==="
fi

if [ "$PROBES" = "1" ]; then
    echo "=== PREMERGE: gate-detection probes ==="
    tests/probes/run_probes.sh
else
    echo "=== PREMERGE: probes skipped (CI runs them; pass --probes to run locally) ==="
fi

if [ "$FULL" = "1" ]; then
    echo "=== PREMERGE: full suite ==="
    tests/run_all.sh full
else
    echo "=== PREMERGE: full suite skipped (CI runs it; pass --full to run locally) ==="
fi

echo "=== PREMERGE GREEN ==="
