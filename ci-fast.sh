#!/usr/bin/env bash
# Fast iteration CI: build + smoke + table tests (no DB/gateway).
# Set SELECTIVE=1 to validate only what changed (see run_all.sh affected):
# static gates + build plus the impacted DB/table/node suites.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ "${SELECTIVE:-0}" = "1" ]; then
    tests/run_all.sh affected
else
    tests/run_all.sh fast
fi
echo "=== CI-FAST GREEN ==="
