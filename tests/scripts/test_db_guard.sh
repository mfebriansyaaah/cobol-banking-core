#!/usr/bin/env bash
# Unit tests for tests/lib/guard.sh. No database needed.
# Usage: tests/scripts/test_db_guard.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/guard.sh"

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL + 1))
        echo "not ok - $desc"
    fi
}

check_not() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        echo "not ok - $desc (expected failure, got success)"
    else
        PASS=$((PASS + 1))
        echo "ok - $desc"
    fi
}

# Protected names must be detected.
check "cobol_db is protected" db_is_protected_name "cobol_db"
check "mysql is protected" db_is_protected_name "mysql"
check "performance_schema is protected" db_is_protected_name "performance_schema"
check "sys is protected" db_is_protected_name "sys"
check "information_schema is protected" db_is_protected_name "information_schema"
check "cobol_wallet is protected" db_is_protected_name "cobol_wallet"
check "empty name is protected" db_is_protected_name ""

# Throwaway names must be safe.
check_not "isolated template is safe" db_is_protected_name "cobol_db_test_123"
check_not "shard db is safe" db_is_protected_name "cobol_db_shard_0_456"
check_not "restore drill db is safe" db_is_protected_name "cobol_db_restore_drill"
check_not "other db is safe" db_is_protected_name "myapp"

# db_require_safe_target exits 2 on protected names.
check_not "require rejects cobol_db" db_require_safe_target "cobol_db"
check_not "require rejects empty" db_require_safe_target ""
check "require accepts throwaway" db_require_safe_target "cobol_db_test_1"

# db_require_allow_dev_db fails closed without ALLOW_DEV_DB=1.
# NOTE: the helper is a shell function, so it must run in a subshell --
# `env VAR=1 helper` cannot work because env only executes external programs.
# The bash -c bodies below are intentionally single-quoted: $GUARD_LIB must
# expand in the INNER shell, not here (SC2016 does not apply).
export GUARD_LIB="$ROOT/tests/lib/guard.sh"
# shellcheck disable=SC2016
check_not "allow_dev_db fails closed by default" bash -c 'unset ALLOW_DEV_DB; . "$GUARD_LIB"; db_require_allow_dev_db "no DDL"'
# shellcheck disable=SC2016
check_not "allow_dev_db fails closed when 0" bash -c 'ALLOW_DEV_DB=0; . "$GUARD_LIB"; db_require_allow_dev_db "no DDL"'
# shellcheck disable=SC2016
check "allow_dev_db passes when 1" bash -c 'ALLOW_DEV_DB=1; . "$GUARD_LIB"; db_require_allow_dev_db "no DDL"'

echo "# pass=$PASS fail=$FAIL total=$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
