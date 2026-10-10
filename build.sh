#!/bin/bash
# Build Script for COBOL MySQL Backend (Simulated DB Executable)
# Usage: ./build.sh

set -e

COBOL_BIN="cobol/bin/main_logic"

echo "=========================================="
echo "  Building COBOL MySQL Backend (SIM)"
echo "=========================================="

mkdir -p cobol/bin

# Compile as a single executable including all core modules and the C bridge
cobc -free -x -o "$COBOL_BIN" \
    cobol/src/main_logic.cob \
    cobol/src/user_core.cob \
    cobol/src/wallet_core.cob \
    cobol/src/sql_bridge.c \
    -L/usr/lib/x86_64-linux-gnu -lmysqlclient -Wall -Wextra -O2

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
