#!/bin/bash
# Build Script for COBOL MySQL Backend (Simulated DB Executable)
# Usage: ./build.sh [make-target]
#
# Single build path: incremental parallel build via cobol/Makefile (see that
# file for details). JOBS controls parallelism (default: nproc).
# cobol/Makefile compiles every cobol/src/*.cob via wildcard, so adding or
# removing a module needs no build.sh change. The BUILD_LEGACY single-shot
# fallback was removed: its hardcoded source list rotted (it referenced
# long-deleted modules), and check_manifest.mjs now verifies the Makefile
# path instead.

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

COBOL_BIN="cobol/bin/main_logic"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
echo "=========================================="
echo "  Building COBOL MySQL Backend (SIM)"
echo "=========================================="

mkdir -p cobol/bin

make -f cobol/Makefile -j"$JOBS" "$@"

if [ -f "$COBOL_BIN" ]; then
    echo "SUCCESS: Binary created at $COBOL_BIN"
    chmod +x "$COBOL_BIN"
else
    echo "ERROR: Compilation failed"
    exit 1
fi

echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
