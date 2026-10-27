#!/usr/bin/env bash
# Restore / disaster-recovery drill: rebuild a database from schema.sql +
# migrations into an isolated schema and verify it is usable. Never touches
# the primary database (name defaults to cobol_db_restore_drill).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

DB_NAME="${DB_NAME:-cobol_db_restore_drill}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_pass}"

mysqlc() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$@"; }

echo "=== RESTORE DRILL: dropping $DB_NAME ==="
mysqlc -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null || true
mysqlc -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "=== loading baseline schema ==="
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$DB_NAME" < database/schema.sql

echo "=== applying migrations ==="
DB_NAME="$DB_NAME" DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" \
  DB_MIGRATE_USER="$DB_MIGRATE_USER" DB_MIGRATE_PASS="$DB_MIGRATE_PASS" \
  DB_USER="$DB_MIGRATE_USER" DB_PASS="$DB_MIGRATE_PASS" \
  ./database/migrate.sh

echo "=== verifying table count ==="
tables="$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" -N -B "$DB_NAME" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';")"
echo "tables: $tables"
[ "$tables" -ge 400 ] || { echo "FAIL: too few tables ($tables)"; exit 1; }

echo "=== RESTORE DRILL GREEN ==="