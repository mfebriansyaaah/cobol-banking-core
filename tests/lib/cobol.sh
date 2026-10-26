# Shared helpers for COBOL test runners.
# Sourced by other test scripts; do not execute directly.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/cobol/bin/main_logic"

# Load dev DB credentials (tests/.dbenv) if present.
if [ -f "$ROOT/tests/.dbenv" ]; then
    # shellcheck disable=SC1091
    . "$ROOT/tests/.dbenv"
fi
export DB_HOST DB_PORT DB_USER DB_PASS DB_NAME

# Run one COBOL request in an isolated temp workdir.
# Usage: run_cobol "INPUT_LINE"  -> prints the response (output.txt) to stdout.
# Returns the binary exit code.
run_cobol() {
    local input="$1"
    local timeout_sec="${2:-30}"
    local workdir
    workdir="$(mktemp -d /tmp/opencode/cobol-test.XXXXXX)"
    printf '%s\n' "$input" > "$workdir/input.txt"
    (
        cd "$workdir" || exit 1
        timeout "${timeout_sec}s" "$BIN" >/dev/null 2>&1
    )
    local rc=$?
    local out=""
    if [ -f "$workdir/output.txt" ]; then
        out="$(cat "$workdir/output.txt")"
    fi
    printf '%s' "$out"
    rm -rf "$workdir"
    return "$rc"
}
