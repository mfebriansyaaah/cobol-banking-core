#!/usr/bin/env bash
# Minimal full CI: build, then run the existing COBOL/C error harness (which
# also runs the gateway endpoint suite and DB connectivity checks).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "=== MANIFEST CHECK ==="
node scripts/check_manifest.mjs "$ROOT"

echo "=== BUILD ==="
./build.sh

echo "=== COBOL TABLE TESTS ==="
tests/cobol_table_tests.sh "$ROOT"

echo "=== COBOL/C ERROR HARNESS ==="
tests/check_cobol_c_errors.sh

echo "=== CI GREEN ==="
