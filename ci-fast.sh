#!/usr/bin/env bash
# Fast iteration CI: build + smoke + table tests (no DB/gateway).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

tests/run_all.sh fast
echo "=== CI-FAST GREEN ==="
