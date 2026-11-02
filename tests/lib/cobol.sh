# shellcheck shell=bash
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

# Persistent COBOL server (Fase 2.1). The binary supports `--serve`: one
# request line on stdin, one result line on stdout, until QUIT/EOF. Keeping
# one server per suite replaces ~13 process spawns (mktemp + timeout +
# binary + rm) per assertion with one pipe write/read (~8ms vs ~16ms).
# DB round-trips are unchanged; what goes away is process churn.
#
# Set COBOL_TEST_SERVE=0 to force the legacy file mode (one process per
# call). run_cobol falls back to file mode automatically when no server is
# running (e.g. a caller that never started one).
COBOL_TEST_SERVE="${COBOL_TEST_SERVE:-1}"
COBOL_SERVER_PID="${COBOL_SERVER_PID:-}"

# Start the persistent server. Idempotent: a live server is reused. Must be
# called from the suite's main shell (NOT inside $(...) — a coproc started
# in a subshell is unusable from the parent). The usual hook is db_seed(),
# which every DB suite calls once in its main shell.
start_cobol_server() {
    if [ -n "${COBOL_SERVER_PID:-}" ] && kill -0 "$COBOL_SERVER_PID" 2>/dev/null; then
        return 0
    fi
    stop_cobol_server 2>/dev/null || true
    # shellcheck disable=SC2009
    coproc COBOL_SRV { "$BIN" --serve 2>/dev/null; } 2>/dev/null || return 1
    COBOL_SERVER_PID="${COBOL_SRV_PID:-}"
    [ -n "$COBOL_SERVER_PID" ] || return 1
    kill -0 "$COBOL_SERVER_PID" 2>/dev/null || return 1
    exec 3>&"${COBOL_SRV[1]}" 4<&"${COBOL_SRV[0]}" 2>/dev/null || {
        stop_cobol_server 2>/dev/null || true
        return 1
    }
    # A write to a dead server's pipe would SIGKILL the suite (141). Ignore
    # SIGPIPE suite-wide so a crashed server fails the assertion, not the run.
    trap '' PIPE
    trap stop_cobol_server EXIT
    return 0
}

stop_cobol_server() {
    if [ -n "${COBOL_SERVER_PID:-}" ]; then
        printf 'QUIT\n' >&3 2>/dev/null || true
        exec 3>&- 4<&- 2>/dev/null || true
        # Give it a moment to exit cleanly, then SIGKILL a wedged server.
        # A bare `wait` here would hang forever on a server that ignores QUIT.
        local i=0
        while kill -0 "$COBOL_SERVER_PID" 2>/dev/null && [ "$i" -lt 20 ]; do
            sleep 0.1
            i=$((i + 1))
        done
        kill -KILL "$COBOL_SERVER_PID" 2>/dev/null || true
        wait "$COBOL_SERVER_PID" 2>/dev/null || true
        COBOL_SERVER_PID=""
    fi
    return 0
}

# Run one COBOL request and print the response to stdout.
# Server mode (default): pipe write/read against the persistent server.
# File mode (COBOL_TEST_SERVE=0, or no server running): the legacy isolated
# temp workdir. Returns the binary/timeout status (0 on a response read).
# Usage: run_cobol "INPUT_LINE" [timeout_seconds]
run_cobol() {
    local input="$1"
    local timeout_sec="${2:-30}"
    if [ "${COBOL_TEST_SERVE:-1}" = "1" ] && start_cobol_server 2>/dev/null; then
        if printf '%s\n' "$input" >&3 2>/dev/null; then
            # Responses are framed: skip non-result chatter on stdout until the
            # SUCCESS|/ERROR| result line. Every table/DB expectation starts
            # with one of those prefixes, so this matches file-mode grep
            # semantics without consuming the next request's response.
            local out="" line="" tries=0
            while [ "$tries" -lt 10 ] && IFS= read -r -t "$timeout_sec" line <&4; do
                tries=$((tries + 1))
                case "$line" in
                    SUCCESS\|*|ERROR\|*) out="$line"; break ;;
                esac
            done
            if [ -n "$out" ]; then
                printf '%s' "$out"
                return 0
            fi
        fi
        # Timeout, dead pipe, or unreadable response: fail closed. Drop the
        # wedged server so the next call starts a fresh one.
        stop_cobol_server 2>/dev/null || true
        return 1
    fi
    local workdir
    workdir="$(mktemp -d "${TMPDIR:-/tmp}/cobol-test.XXXXXX")"
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
