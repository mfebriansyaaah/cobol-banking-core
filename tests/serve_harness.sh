#!/bin/bash
# Shared long-running COBOL harness for shell suites.
#
# The default invocation model is one process per request. That is faithful but
# slow: every assertion pays a fork/exec and a fresh database connection. This
# harness starts `main_logic --serve` once and multiplexes request lines over
# its stdin/stdout, which is the same protocol the gateway worker pool uses
# (ADR-0010). A suite keeps its own assertion helpers; only process startup
# changes.
#
# Usage (after the suite has set BIN and sourced tests/.dbenv):
#
#     . ./tests/serve_harness.sh
#     core_start
#     trap core_stop EXIT
#     run() { core_run "$@"; }
#
# A suite that needs a fresh process per call (crash injection, per-call
# environment, file-mode assertions) must keep its own run() instead: the
# serve process reads its environment once at startup and keeps its
# working-storage between requests.

CORE_PID=""
CORE_IN=""
CORE_OUT=""
CORE_DIR=""

core_start() {
    local bin="${BIN:-./cobol/bin/main_logic}"
    [ -x "$bin" ] || { echo "serve harness: binary not found: $bin" >&2; exit 1; }
    CORE_DIR="$(mktemp -d)"
    mkfifo "$CORE_DIR/in" "$CORE_DIR/out"
    # Open both ends read-write first: the opens never block and the fds stay
    # usable in subshells (command substitutions and pipelines), unlike the
    # coproc fds.
    exec 8<>"$CORE_DIR/in"
    exec 9<>"$CORE_DIR/out"
    "$bin" --serve <"$CORE_DIR/in" >"$CORE_DIR/out" 2>/dev/null &
    CORE_PID=$!
    CORE_IN=8
    CORE_OUT=9
}

core_stop() {
    [ -n "$CORE_PID" ] || return 0
    printf 'QUIT\n' >&8 2>/dev/null || true
    wait "$CORE_PID" 2>/dev/null || true
    exec 8>&- 2>/dev/null || true
    exec 9<&- 2>/dev/null || true
    [ -n "$CORE_DIR" ] && rm -rf "$CORE_DIR"
    CORE_PID=""
}

# Send one request and return its result line (stdout only; the bridge's
# diagnostics go to stderr and are discarded by core_start). A hung request
# fails the harness instead of hanging CI forever.
core_run() {
    local line="$1"
    shift
    if [ "$#" -gt 0 ]; then
        local IFS='|'
        line="$line|$*"
    fi
    printf '%s\n' "$line" >&8 || { echo "serve harness: core is not running" >&2; return 1; }
    local result=""
    if ! IFS= read -r -t 30 result <&9; then
        echo "serve harness: no result within 30s for: $line" >&2
        return 1
    fi
    printf '%s\n' "$result"
}
