#!/usr/bin/env bash
# Restore a migrated DB snapshot (CI-008B): drop/recreate the CI database,
# load a gzip snapshot produced by scripts/ci/build_db_snapshot.sh, verify
# table + migration counts, and confirm the migration ledger is clean.
#
# CI-only: refuses to run without CI=true / GITHUB_ACTIONS=true unless
# ALLOW_CI_DB=1 is set. Only cobol_db / cobol_db_* targets are allowed;
# system databases are always refused. Fails closed on any mismatch and
# never prints the DB password.
#
# Usage: bash scripts/ci/restore_db_snapshot.sh <snapshot.sql.gz>
# Env: DB_HOST, DB_PORT, DB_NAME, DB_MIGRATE_USER, DB_MIGRATE_PASS,
#   MIGRATE_SH (default database/migrate.sh, for --check),
#   SCHEMA_SNAPSHOT (default database/schema_full.sql, expected table count).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

SNAP="${1:?usage: restore_db_snapshot.sh <snapshot.sql.gz}"
MIGRATE_SH="${MIGRATE_SH:-$ROOT/database/migrate.sh}"
SCHEMA_SNAPSHOT="${SCHEMA_SNAPSHOT:-$ROOT/database/schema_full.sql}"

if [ "${CI:-}" != "true" ] && [ "${GITHUB_ACTIONS:-}" != "true" ] && [ "${ALLOW_CI_DB:-0}" != "1" ]; then
    echo "FAIL: refusing to DROP/CREATE a database outside CI (set ALLOW_CI_DB=1 to override)" >&2
    exit 2
fi

case "${DB_NAME:-}" in
    ''|mysql|performance_schema|sys|information_schema)
        echo "FAIL: refusing protected database name '${DB_NAME:-<empty>}'" >&2
        exit 2
        ;;
    cobol_db|cobol_db_*) ;;
    *)
        echo "FAIL: refusing unexpected database name '$DB_NAME' (expected cobol_db or cobol_db_*)" >&2
        exit 2
        ;;
esac

[ -f "$SNAP" ] || { echo "FAIL: snapshot not found: $SNAP" >&2; exit 1; }
[ -n "${DB_MIGRATE_PASS:-}" ] || { echo "FAIL: DB_MIGRATE_PASS is required" >&2; exit 2; }
[ -x "$MIGRATE_SH" ] || { echo "FAIL: migrate script not executable: $MIGRATE_SH" >&2; exit 2; }
[ -f "$SCHEMA_SNAPSHOT" ] || { echo "FAIL: schema snapshot not found: $SCHEMA_SNAPSHOT" >&2; exit 2; }

mysql_root() {
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_MIGRATE_USER:-cobol_user}" -p"$DB_MIGRATE_PASS" "$@"
}

echo "=== restoring $DB_NAME from $SNAP ==="
mysql_root -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
mysql_root -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
gunzip -c "$SNAP" | mysql_root "$DB_NAME"

TABLES="$(mysql_root -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';")"
MIGS="$(mysql_root -N -B -e "SELECT COUNT(*) FROM \`$DB_NAME\`.schema_migrations;")"
case "$TABLES" in ''|*[!0-9]*) echo "FAIL: bad table count from database: '$TABLES'" >&2; exit 1 ;; esac
case "$MIGS" in ''|*[!0-9]*) echo "FAIL: bad migration count from database: '$MIGS'" >&2; exit 1 ;; esac
[ "$TABLES" -gt 0 ] || { echo "FAIL: restored database has no tables" >&2; exit 1; }
[ "$MIGS" -gt 0 ] || { echo "FAIL: restored database has no recorded migrations" >&2; exit 1; }
EXPECTED="$(grep -c '^CREATE TABLE' "$SCHEMA_SNAPSHOT")"
if [ "$TABLES" -ne "$EXPECTED" ]; then
    echo "FAIL: restored table count $TABLES != schema snapshot $EXPECTED ($SCHEMA_SNAPSHOT)" >&2
    exit 1
fi

# Ledger check through the real migrate script (env-driven, like CI):
# the snapshot must match exactly what migrate.sh would produce.
export DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}" DB_NAME="$DB_NAME"
export DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}" DB_MIGRATE_PASS="$DB_MIGRATE_PASS"
DB_NAME="$DB_NAME" "$MIGRATE_SH" --check

echo "=== DB SNAPSHOT RESTORED: $TABLES tables, $MIGS migrations ($DB_NAME) ==="
