#!/usr/bin/env bash
# Code coverage tracking for COBOL and Node gateway.
# Usage: scripts/ci/coverage.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "=== COBOL coverage ==="
# Build with coverage flags
if command -v cobc >/dev/null 2>&1; then
  # Rebuild with --coverage if not already
  if [ ! -f cobol/bin/main_logic.gcno ]; then
    echo "Rebuilding with --coverage..."
    CFLAGS="--coverage" ./build.sh 2>&1 | tail -5 || true
  fi
  # Generate coverage report
  if command -v gcov >/dev/null 2>&1; then
    cd cobol/src
    for f in *_core.cob; do
      gcov -b "$f" 2>/dev/null | tail -2 || true
    done
    cd "$ROOT"
  fi
fi

echo "=== Node gateway coverage ==="
if [ -d middleware ]; then
  cd middleware
  if [ -f package.json ]; then
    npm test -- --experimental-test-coverage 2>&1 | tail -20 || true
  fi
  cd "$ROOT"
fi

echo "Coverage collection complete."