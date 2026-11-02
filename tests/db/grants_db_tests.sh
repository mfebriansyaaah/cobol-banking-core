#!/usr/bin/env bash
# DB grants tests: the application account is DML-only while the migration
# account can do DDL. Least privilege is load-bearing (a SQL bug through the
# app path must not DROP/ALTER tables), so the grants are asserted, not
# assumed. Uses a per-run probe table and always cleans it up.
#
# One assertion line per check (no if/else branches): the static assertion
# counter must equal the runtime total.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

PROBE="grants_probe_$$"

mysql_as_app() {
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_USER:-cobol_user}" -p"${DB_PASS:-cobol_pass}" \
        "${DB_NAME:-cobol_db}" "$@" >/dev/null 2>&1
}

# Invoked only via `trap ... EXIT`, which shellcheck cannot trace.
# shellcheck disable=SC2317
cleanup() {
    mysql_migrate -e "DROP TABLE IF EXISTS \`$PROBE\`; DROP TABLE IF EXISTS \`${PROBE}_app\`;" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mysql_migrate -e "DROP TABLE IF EXISTS \`$PROBE\`; DROP TABLE IF EXISTS \`${PROBE}_app\`;" >/dev/null 2>&1

# Migrate account: CREATE then DROP succeed.
mysql_migrate -e "CREATE TABLE \`$PROBE\` (id INT PRIMARY KEY);"
assert_match "migrate account can CREATE TABLE" "$?" "^0$"

# App account: DROP of a migrate-created table fails.
mysql_as_app -e "DROP TABLE \`$PROBE\`;"
assert_match "app account cannot DROP TABLE" "$?" "^1$"

# App account: CREATE TABLE fails.
mysql_as_app -e "CREATE TABLE \`${PROBE}_app\` (id INT PRIMARY KEY);"
assert_match "app account cannot CREATE TABLE" "$?" "^1$"

# App account: ALTER TABLE fails.
mysql_as_app -e "ALTER TABLE \`$PROBE\` ADD COLUMN v INT;"
assert_match "app account cannot ALTER TABLE" "$?" "^1$"

# Migrate account: DROP succeeds and the table is gone.
mysql_migrate -e "DROP TABLE \`$PROBE\`;"
assert_match "migrate account DROP TABLE exit" "$?" "^0$"
left="$(db_query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = '$PROBE';")"
assert_match "migrate account dropped table is gone" "$left" "^0$"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
