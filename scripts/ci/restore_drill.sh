#!/usr/bin/env bash
# Schema rebuild drill: rebuild a database from schema.sql + migrations into
# an isolated schema and verify it is usable. Never touches the primary
# database.
#
# NOTE: this is NOT a backup restore: no backup file is involved. A real
# backup/restore drill (dump -> restore -> data verification) is P1-4
# (migration & backup tooling).
#
# The drill target comes ONLY from RESTORE_DRILL_DB (default
# cobol_db_restore_drill). DB_NAME is deliberately ignored: an earlier version
# of this script read DB_NAME, so in CI (DB_NAME=cobol_db) it dropped the
# database under test. Protected names (cobol_db, mysql, ...) are rejected
# before any DROP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
. "$ROOT/tests/lib/guard.sh"

RESTORE_DRILL_DB="${RESTORE_DRILL_DB:-cobol_db_restore_drill}"
db_require_safe_target "$RESTORE_DRILL_DB"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_pass}"

mysqlc() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$@"; }

echo "=== SCHEMA REBUILD DRILL: target $RESTORE_DRILL_DB (DB_NAME is ignored) ==="
mysqlc -e "DROP DATABASE IF EXISTS \`$RESTORE_DRILL_DB\`;" 2>/dev/null || true
mysqlc -e "CREATE DATABASE \`$RESTORE_DRILL_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "=== loading baseline schema ==="
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$RESTORE_DRILL_DB" < database/schema.sql

echo "=== applying migrations ==="
# env (not VAR=x prefix): forwarding outer values self-referentially trips SC2097.
env "DB_NAME=$RESTORE_DRILL_DB" "DB_HOST=$DB_HOST" "DB_PORT=$DB_PORT" \
    "DB_MIGRATE_USER=$DB_MIGRATE_USER" "DB_MIGRATE_PASS=$DB_MIGRATE_PASS" \
    "DB_USER=$DB_MIGRATE_USER" "DB_PASS=$DB_MIGRATE_PASS" \
    ./database/migrate.sh

echo "=== verifying table count ==="
# One-shot environment for the child script: the parent keeps its own
# values (e.g. $DB_NAME still names the source below), so the subshell
# export is intentional, not a lost modification.
# shellcheck disable=SC2030,SC2031
tables="$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" -N -B "$RESTORE_DRILL_DB" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$RESTORE_DRILL_DB';")"
echo "tables: $tables"
[ "$tables" -ge 400 ] || { echo "FAIL: too few tables ($tables)" >&2; exit 1; }

echo "=== SCHEMA REBUILD DRILL GREEN (target: $RESTORE_DRILL_DB) ==="
