#!/usr/bin/env bash
# Provision a local test database for the DB test fleet.
#
# Creates two accounts on the test database host:
#   app     - SELECT, INSERT, UPDATE, DELETE only (used by the running tests)
#   migrate - DDL-capable (used by migrate.sh, isolation, and sharding)
#
# The app account also gets DML on the throwaway databases created by
# tests/run_all.sh db (cobol_db_test_*, cobol_db_shard_*, cobol_db_restore_drill*),
# so isolation and sharding work without falling back to the developer database.
# The migrate account needs global CREATE/DROP DATABASE to provision those.
#
# This script is idempotent. Production credentials must never be used here.
#
# Env (all optional, see tests/.dbenv.example):
#   DB_HOST (default 127.0.0.1), DB_PORT (default 3307),
#   DB_NAME (default cobol_db),
#   DB_USER/DB_PASS (app account, default cobol_app/cobol_pass),
#   DB_MIGRATE_USER/DB_MIGRATE_PASS (migrate account, default cobol_migrate/cobol_migrate_pass),
#   DB_ROOT_PASS (root password for provisioning, default root),
#   SKIP_SEED=1 to skip loading seed fixtures.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ -f tests/.dbenv ]; then
    # shellcheck disable=SC1091
    . tests/.dbenv
fi

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3307}"
DB_NAME="${DB_NAME:-cobol_db}"
DB_USER="${DB_USER:-cobol_app}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_migrate}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_migrate_pass}"
DB_ROOT_PASS="${DB_ROOT_PASS:-root}"

echo "=== TEST DB SETUP: $DB_HOST:$DB_PORT/$DB_NAME ==="

# Wait for the database to accept connections (compose needs ~10s on first start).
echo "--- waiting for database ---"
tries=0
until mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$DB_ROOT_PASS" -e "SELECT 1;" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
        echo "FAIL: database at $DB_HOST:$DB_PORT did not become ready" >&2
        echo "hint: docker compose -f docker-compose.test.yml up -d" >&2
        exit 1
    fi
    sleep 2
done

echo "--- provisioning app + migrate accounts ---"
mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$DB_ROOT_PASS" <<SQL
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$DB_USER'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`cobol_db_test_%\`.* TO '$DB_USER'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`cobol_db_shard_%\`.* TO '$DB_USER'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`cobol_db_restore_drill%\`.* TO '$DB_USER'@'%';

CREATE USER IF NOT EXISTS '$DB_MIGRATE_USER'@'%' IDENTIFIED BY '$DB_MIGRATE_PASS';
ALTER USER '$DB_MIGRATE_USER'@'%' IDENTIFIED BY '$DB_MIGRATE_PASS';
GRANT ALL PRIVILEGES ON *.* TO '$DB_MIGRATE_USER'@'%' WITH GRANT OPTION;

-- Localhost variants: the mysql client may resolve 127.0.0.1 via socket as localhost.
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$DB_USER'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`cobol_db_test_%\`.* TO '$DB_USER'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`cobol_db_shard_%\`.* TO '$DB_USER'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`cobol_db_restore_drill%\`.* TO '$DB_USER'@'localhost';

CREATE USER IF NOT EXISTS '$DB_MIGRATE_USER'@'localhost' IDENTIFIED BY '$DB_MIGRATE_PASS';
ALTER USER '$DB_MIGRATE_USER'@'localhost' IDENTIFIED BY '$DB_MIGRATE_PASS';
GRANT ALL PRIVILEGES ON *.* TO '$DB_MIGRATE_USER'@'localhost' WITH GRANT OPTION;

FLUSH PRIVILEGES;
SQL

echo "--- verifying least privilege ---"
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE cobol_db_privcheck_$$;" "$DB_NAME" >/dev/null 2>&1; then
    echo "FAIL: app account can CREATE DATABASE; grants are too wide" >&2
    exit 1
fi
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" -e "CREATE DATABASE IF NOT EXISTS cobol_db_privcheck_$$; DROP DATABASE cobol_db_privcheck_$$;" >/dev/null 2>&1 || {
    echo "FAIL: migrate account cannot CREATE/DROP DATABASE" >&2
    exit 1
}
echo "privilege check OK (app: DML-only, migrate: DDL-capable)"

echo "--- loading baseline schema + migrations ---"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$DB_NAME" < database/schema.sql
DB_NAME="$DB_NAME" DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" \
    DB_USER="$DB_USER" DB_PASS="$DB_PASS" \
    DB_MIGRATE_USER="$DB_MIGRATE_USER" DB_MIGRATE_PASS="$DB_MIGRATE_PASS" \
    ./database/migrate.sh

if [ "${SKIP_SEED:-0}" != "1" ]; then
    echo "--- seeding test fixtures ---"
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < database/seed_test_data.sql
fi

echo "=== TEST DB READY ==="
echo "credentials: see tests/.dbenv (DB_HOST=$DB_HOST DB_PORT=$DB_PORT DB_NAME=$DB_NAME)"
