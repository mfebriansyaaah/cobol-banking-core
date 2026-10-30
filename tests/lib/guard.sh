# Database safety guards for tests and drills. Sourced by runners, never executed directly.
#
# The test fleet creates and drops throwaway databases (cobol_db_test_*,
# cobol_db_shard_*). A typo or a bad default must never drop the developer
# database (cobol_db) or a system database. These helpers fail closed.
#
# Usage:
#   . "$ROOT/tests/lib/guard.sh"
#   db_require_safe_target "$DB_NAME"   # exit 2 when the name is protected
#   db_is_protected_name "$name"        # 0 when protected, 1 when safe

# Exact database names that must never be dropped or used as throwaway targets.
# Throwaway names (cobol_db_test_*, cobol_db_shard_*, cobol_db_restore_drill*)
# are NOT in this list; they are matched by the cleanup script instead.
db_is_protected_name() {
    case "${1:-}" in
        ""|cobol_db|mysql|performance_schema|sys|information_schema|cobol_wallet)
            return 0
            ;;
    esac
    return 1
}

# Exit 2 when $1 is a protected name. Prints the reason to stderr.
db_require_safe_target() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        echo "FAIL: refusing to operate on an empty database name" >&2
        return 2
    fi
    if db_is_protected_name "$name"; then
        echo "FAIL: refusing to operate on protected database '$name'" >&2
        echo "hint: use a throwaway database (e.g. cobol_db_restore_drill) or set RESTORE_DRILL_DB" >&2
        return 2
    fi
    return 0
}

# Fail closed when isolation was requested but is unavailable. Call this from
# run_all.sh db instead of silently falling back to the developer database.
# Pass the reason (e.g. "no DDL rights", "migration failed").
# Succeeds only when ALLOW_DEV_DB=1 is explicitly set.
db_require_allow_dev_db() {
    local reason="${1:-isolation unavailable}"
    if [ "${ALLOW_DEV_DB:-0}" = "1" ]; then
        echo "WARN: $reason; continuing on $DB_NAME because ALLOW_DEV_DB=1 (developer data may be modified)" >&2
        return 0
    fi
    echo "FAIL: $reason; refusing to run DB suites against '$DB_NAME'" >&2
    echo "hint: provision a DDL-capable migrate user (scripts/dev/setup-test-db.sh)," >&2
    echo "      or set ALLOW_DEV_DB=1 explicitly to run against the developer database." >&2
    return 1
}
