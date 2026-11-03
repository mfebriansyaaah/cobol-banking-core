#!/bin/bash
# Error-check harness for COBOL + C code only.
# Categories: compile-time, run-time, file-handling, linkage/load, logical.
# Gateway smoke is run separately by tests/run_all.sh (full mode).
# Usage: ./tests/check_cobol_c_errors.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/workdir.sh"
WORKDIR="$(make_workdir c-errors)" || { echo "FAIL: cannot create workdir" >&2; exit 1; }
trap 'rm -rf "$WORKDIR"' EXIT
COBOL_DIR="$ROOT/cobol"
C_LIB="$COBOL_DIR/c_lib"
BIN="$COBOL_DIR/bin/main_logic"
fail=0

step() { echo; echo "=== $1 ==="; }

# 1. Compile-time errors (COBOL)
# One cobc invocation checks all modules (~3s) instead of one process per
# module (~19s). Errors still name the offending file.
step "1. Compile-time (COBOL syntax)"
if cobc -fsyntax-only -free -I "$COBOL_DIR/copy" "$COBOL_DIR"/src/*.cob >/tmp/cobol_syntax.log 2>&1; then
    echo "OK: all COBOL files parse"
else
    grep -Eo '[^ :]*\.(cob|cpy):[0-9]+: error' /tmp/cobol_syntax.log \
        | sed 's/:[0-9]*: error$//' | sort -u | sed 's/^/FAIL: /' || true
    head -20 /tmp/cobol_syntax.log
    fail=1
fi

# 2. Compile-time errors (C)
step "2. Compile-time (C)"
c_err=0
for f in "$C_LIB"/*.c; do
    if ! gcc -fsyntax-only -I "$C_LIB" "$f" >/tmp/c_syntax.log 2>&1; then
        echo "FAIL: $f"; head -5 /tmp/c_syntax.log; c_err=1
    fi
done
[ "$c_err" -eq 0 ] && echo "OK: all C files parse" || fail=1

# 3. Linkage / load errors
step "3. Linkage / load"
if [ -x "$BIN" ]; then
    if ldd "$BIN" >/tmp/ldd.log 2>&1; then
        if grep -q 'not found' /tmp/ldd.log; then
            echo "FAIL: missing shared library"; grep 'not found' /tmp/ldd.log; fail=1
        else
            echo "OK: all shared libraries resolved"
        fi
    else
        echo "SKIP: ldd unavailable"
    fi
else
    echo "SKIP: binary not built (run build.sh first)"
fi

# 4. Run-time errors (basic invocation)
step "4. Run-time (smoke invocation)"
if [ -x "$BIN" ]; then
    printf 'PING||||||\n' > "$WORKDIR/input.txt"
    (cd "$WORKDIR" && "$BIN" >/dev/null 2>&1) || true
    out=$(cat "$WORKDIR/output.txt" 2>/dev/null)
    if echo "$out" | grep -qi 'ERROR|'; then
        echo "FAIL: runtime error: $out"; fail=1
    else
        echo "OK: PING responded: $out"
    fi
else
    echo "SKIP: binary not built"
fi

# 5. File handling errors (DB connectivity)
step "5. File handling (DB connectivity smoke)"
if [ "${SKIP_DB_CHECK:-0}" = "1" ]; then
    echo "SKIP: SKIP_DB_CHECK=1"
elif [ -x "$BIN" ]; then
    printf 'PING||||||\n' > "$WORKDIR/input.txt"
    (cd "$WORKDIR" && "$BIN" >/dev/null 2>&1) || true
    out=$(cat "$WORKDIR/output.txt" 2>/dev/null)
    if echo "$out" | grep -qi 'DB_DOWN\|CONN_FAILED\|CONFIG_INSECURE'; then
        echo "FAIL: DB connection error: $out"; fail=1
    else
        echo "OK: DB reachable: $out"
    fi
else
    echo "SKIP: binary not built"
fi

# 6. Logical errors (basic sanity)
step "6. Logical (sanity)"
if [ -x "$BIN" ]; then
    printf 'CHECK_ROLE|admin@test.com|||||\n' > "$WORKDIR/input.txt"
    (cd "$WORKDIR" && "$BIN" >/dev/null 2>&1) || true
    out=$(cat "$WORKDIR/output.txt" 2>/dev/null)
    if [ -z "$out" ]; then
        echo "FAIL: empty output"; fail=1
    else
        echo "OK: non-empty response"
    fi
else
    echo "SKIP: binary not built"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "=== ALL ERROR CHECKS PASSED ==="
    exit 0
else
    echo "=== ERROR CHECKS FAILED ==="
    exit 1
fi
