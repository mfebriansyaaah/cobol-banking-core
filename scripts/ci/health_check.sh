#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "=== HEALTH CHECK ==="
echo "1) Build"
./build.sh >/tmp/health_build.log 2>&1
echo "build OK"

echo "2) Warning ratchet"
./scripts/check_warnings.sh /tmp/health_build.log

echo "3) SAST"
./scripts/ci/sast.sh

echo "4) DB tests (run_all)"
bash tests/run_all.sh >/tmp/health_runall.log 2>&1
echo "run_all OK"

echo "HEALTH CHECK PASSED"
