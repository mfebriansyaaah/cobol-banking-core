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
# Set PREMERGE_PROBES=1 to also run the gate-detection probes and the docs
# gate locally (CI runs both in its build job).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# tests/run_all.sh fast already runs every static gate except check_docs
# (syntax, manifest, route dispatch/conflicts/auth, action coverage, bind
# slots, suite inventory, test helpers, case actions) plus build, table
# tests and smoke, so they are not repeated here.
echo "=== PREMERGE: fast suite (includes static gates) ==="
tests/run_all.sh fast

# Probes take ~6 min (8 mutations x 12 gates on a throwaway repo copy) and
# only pay off when a gate itself changed; check_docs is likewise covered by
# the CI build job. Run them locally only on request.
if [ "${PREMERGE_PROBES:-0}" = "1" ]; then
    echo "=== PREMERGE: docs gate ==="
    node scripts/check_docs.mjs .
    echo "=== PREMERGE: gate detection probes ==="
    tests/probes/run_probes.sh
else
    echo "=== PREMERGE: docs/probes skipped (CI runs them; set PREMERGE_PROBES=1 to run locally) ==="
fi

if [ "${PREMERGE_FULL:-0}" = "1" ]; then
    echo "=== PREMERGE: full suite ==="
    tests/run_all.sh full
else
    echo "=== PREMERGE: full suite skipped (CI runs it; set PREMERGE_FULL=1 to run locally) ==="
fi

echo "=== PREMERGE GREEN ==="
