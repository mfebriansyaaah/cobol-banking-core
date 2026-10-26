#!/usr/bin/env bash
# Full CI: manifest + build + all tests (table, DB, gateway, error harness).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

tests/run_all.sh full
echo "=== CI GREEN ==="
