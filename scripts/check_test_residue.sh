#!/usr/bin/env bash
# Fail when a test run leaves user fixtures behind.
#
# Test users always live in a per-file namespace (`<tag>-<stamp>-<rand>`, see
# middleware/test/support.js testNamespace()) and are created through
# uniqueEmail(), so one run's fixtures all match '%-<runid>-%'. Every test
# file cleans only its own namespace; this script verifies nothing from the
# run survived. Seeded users (sender/receiver/admin@test.com) never match a
# namespace pattern and are ignored.
#
# Usage (same shell, so TEST_RUN_ID is shared):
#   TEST_RUN_ID="t$(date +%s%N)" npm --prefix middleware run test:db
#   TEST_RUN_ID="$TEST_RUN_ID" bash scripts/check_test_residue.sh
#
# Without TEST_RUN_ID the script checks explicit namespaces instead:
#   bash scripts/check_test_residue.sh <ns1> [ns2 ...]
#
# On a shared developer database the id form also sees residue from older
# runs; that is expected — run it against a fresh database (CI does).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

mysql_app() {
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" "$@"
}

leftover=0
check_pattern() {
    # $1 = SQL LIKE pattern (already quoted for SQL), $2 = display label
    local pattern="$1" label="$2" count
    count="$(mysql_app -N -B -e "SELECT COUNT(*) FROM users WHERE email LIKE '$pattern';" 2>/dev/null || echo "?")"
    if [ "$count" = "?" ]; then
        echo "FAIL: cannot query the database (mysql unavailable?)" >&2
        exit 1
    fi
    if [ "$count" != "0" ]; then
        echo "FAIL: $count leftover test user(s) matching '$label':"
        mysql_app -N -B -e "SELECT email FROM users WHERE email LIKE '$pattern' ORDER BY email LIMIT 20;" 2>/dev/null || true
        leftover=1
    fi
}

if [ $# -gt 0 ]; then
    # Explicit namespaces: match the namespace prefix exactly.
    for ns in "$@"; do
        case "$ns" in
            *[%_\\]*)
                echo "FAIL: namespace '$ns' contains LIKE metacharacters" >&2
                exit 2
                ;;
        esac
        check_pattern "$ns-%" "$ns-*"
    done
else
    if [ -z "${TEST_RUN_ID:-}" ]; then
        echo "usage: TEST_RUN_ID=<id> $0   (or: $0 <ns1> [ns2 ...])" >&2
        exit 2
    fi
    # Alphanumeric only: the id is interpolated into the LIKE pattern below.
    rid="$(printf '%s' "$TEST_RUN_ID" | tr -cd 'a-zA-Z0-9')"
    if [ -z "$rid" ]; then
        echo "FAIL: TEST_RUN_ID has no alphanumeric characters" >&2
        exit 2
    fi
    check_pattern "%-${rid}-%" "%-${rid}-*"
fi

if [ "$leftover" -ne 0 ]; then
    echo "hint: per-file after() hooks should have removed these via cleanupNamespace()" >&2
    exit 1
fi
echo "OK: no leftover test users"
