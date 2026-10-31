# Exclusive lock for DB test runs. Sourced by runners, never executed directly.
#
# Two `run_all.sh db` processes against the same database would interleave
# DELETE/reset statements and produce false failures (or false passes).
# flock releases automatically when the holder exits, so a crashed run cannot
# leave a stale lock behind.
#
# Usage:
#   . "$ROOT/tests/lib/lock.sh"
#   db_lock_acquire || exit 1
#   # ... run suites ...
#   db_lock_release
#
# NOTE: never put `2>/dev/null` on a bare `exec` (no command): with no command
# the redirections apply to the current shell permanently, so a stray
# `exec 9>... 2>/dev/null` would silence every later error message. Temporary
# suppression uses a command or a group (`{ ...; } 2>/dev/null`).

DB_LOCK_FILE="${DB_LOCK_FILE:-}"
DB_LOCK_HELD="${DB_LOCK_HELD:-0}"

# Stable key for the current test target database.
db_lock_key() {
    printf '%s:%s:%s' "${DB_HOST:-localhost}" "${DB_PORT:-3306}" "${DB_NAME:-cobol_db}" \
        | md5sum | cut -d' ' -f1
}

# Acquire an exclusive, non-blocking lock for the current DB target.
# Returns 1 when another run holds the lock. Idempotent: a process that
# already holds the lock (e.g. run_integration after run_db in one `full`
# run) keeps it without reopening the lock file.
db_lock_acquire() {
    if [ "${DB_LOCK_HELD:-0}" = "1" ]; then
        return 0
    fi
    if ! command -v flock >/dev/null 2>&1; then
        echo "WARN: flock not available; skipping DB run lock (concurrent runs may interfere)" >&2
        return 0
    fi
    local key lock
    key="$(db_lock_key)"
    lock="${TMPDIR:-/tmp}/cobol-db-run-${key}.lock"
    DB_LOCK_FILE="$lock"
    # Open (append: never truncate another holder's PID record). A failed open
    # keeps the shell's own error message: it means TMPDIR is unwritable and
    # must be visible.
    if ! exec 9>>"$lock"; then
        echo "FAIL: cannot open lock file $lock" >&2
        return 1
    fi
    if ! flock -n 9 2>/dev/null; then
        echo "FAIL: another DB test run holds the lock for ${DB_HOST:-localhost}:${DB_PORT:-3306}/${DB_NAME:-cobol_db}" >&2
        echo "hint: wait for the other run to finish; the lock releases automatically on exit ($lock)" >&2
        { exec 9>&-; } 2>/dev/null || true
        DB_LOCK_HELD=0
        return 1
    fi
    DB_LOCK_HELD=1
    # Record the holder for humans debugging a stuck run. Best effort.
    echo "$$ $(date -u +%FT%TZ)" >&9 2>/dev/null || true
    return 0
}

db_lock_release() {
    if [ "${DB_LOCK_HELD:-0}" = "1" ]; then
        { exec 9>&-; } 2>/dev/null || true
        DB_LOCK_HELD=0
    fi
    return 0
}
