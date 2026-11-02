#!/usr/bin/env bash
# Strict C gate for the crypto helpers (P1-6): cobol/c_lib must compile
# warning-free and pass cppcheck. The files are self-contained (libc only),
# which is also why the CodeQL workflow can trace them without mysql headers.
# Usage: bash scripts/ci/c_strict.sh (needs gcc and cppcheck).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

command -v gcc >/dev/null 2>&1 || { echo "FAIL: gcc not found" >&2; exit 2; }
command -v cppcheck >/dev/null 2>&1 || { echo "FAIL: cppcheck not found (apt install cppcheck)" >&2; exit 2; }

echo "=== strict compile (-Wall -Wextra -Werror, syntax only) ==="
gcc -Wall -Wextra -Werror -fsyntax-only -I cobol/c_lib cobol/c_lib/*.c
echo "strict compile clean"

echo "=== cppcheck (warning,performance,portability) ==="
cppcheck --error-exitcode=1 --quiet --enable=warning,performance,portability \
    -I cobol/c_lib cobol/c_lib/
echo "cppcheck clean"
