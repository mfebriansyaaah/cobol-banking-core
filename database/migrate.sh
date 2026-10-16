#!/bin/bash
# Apply pending database migrations once each, recording them in
# schema_migrations. Idempotent: already-applied migrations are skipped.
# Usage: database/migrate.sh

set -e
cd "$(dirname "$0")/.."

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

# Migrations create/alter/drop schema objects, so they need DDL rights. Run
# them under a dedicated privileged account (see database/grants.sh) instead of
# the DML-only application account; defaults to the app credentials for
# backward compatibility.
DB_MIGRATE_USER="${DB_MIGRATE_USER:-$DB_USER}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-$DB_PASS}"

mysqlc() { mysql -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$DB_NAME" "$@"; }

mysqlc -e "CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(64) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;" 2>/dev/null

if [ "$1" = "--check" ]; then
    pending=""
    for f in database/migrations/*.sql; do
        [ -e "$f" ] || continue
        v="$(basename "$f" .sql)"
        c="$(mysqlc -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version='$v';" 2>/dev/null)"
        [ "$c" = "1" ] || pending="$pending $v"
    done
    if [ -n "$pending" ]; then
        echo "pending migrations:$pending"
        exit 1
    fi
    echo "all migrations applied"
    exit 0
fi

applied_any=0
for f in database/migrations/*.sql; do
    [ -e "$f" ] || continue
    v="$(basename "$f" .sql)"
    already="$(mysqlc -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version='$v';" 2>/dev/null)"
    if [ "$already" = "1" ]; then
        echo "already applied: $v"
    else
        echo "applying: $v"
        mysqlc < "$f" 2>/dev/null
        mysqlc -e "INSERT INTO schema_migrations (version) VALUES ('$v');" 2>/dev/null
        applied_any=1
    fi
done

if [ "$applied_any" = "1" ]; then
    echo "migrations applied"
else
    echo "no pending migrations"
fi
