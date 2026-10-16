#!/bin/bash
# Provision least-privilege database accounts for the banking core.
#
# The application runtime must NOT hold DDL rights, so that a bug or an
# injection cannot DROP/ALTER tables. Two accounts are provisioned on the data
# database:
#   app      - SELECT, INSERT, UPDATE, DELETE only (used by the running app)
#   migrate  - full rights, used by database/migrate.sh
#
# Run as a database admin (e.g. root):
#   APP_DB_PASS=... MIGRATE_DB_PASS=... database/grants.sh
# Review the statements without executing anything:
#   database/grants.sh --print
#
# Environment: DB_NAME, APP_USER, APP_HOST, APP_DB_PASS, MIGRATE_USER,
# MIGRATE_HOST, MIGRATE_DB_PASS, plus DB_ADMIN_USER/DB_ADMIN_PASS for the
# admin connection (omit both to use the local root socket).
# Usage: database/grants.sh [--print]

set -e

DB_NAME="${DB_NAME:-cobol_db}"
APP_USER="${APP_USER:-cobol_app}"
APP_HOST="${APP_HOST:-localhost}"
MIGRATE_USER="${MIGRATE_USER:-cobol_migrate}"
MIGRATE_HOST="${MIGRATE_HOST:-localhost}"

statements() {
    cat <<SQL
CREATE USER IF NOT EXISTS '$APP_USER'@'$APP_HOST' IDENTIFIED BY '$APP_DB_PASS';
ALTER USER '$APP_USER'@'$APP_HOST' IDENTIFIED BY '$APP_DB_PASS';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`$DB_NAME\`.* TO '$APP_USER'@'$APP_HOST';

CREATE USER IF NOT EXISTS '$MIGRATE_USER'@'$MIGRATE_HOST' IDENTIFIED BY '$MIGRATE_DB_PASS';
ALTER USER '$MIGRATE_USER'@'$MIGRATE_HOST' IDENTIFIED BY '$MIGRATE_DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$MIGRATE_USER'@'$MIGRATE_HOST';

FLUSH PRIVILEGES;
SQL
}

if [ "$1" = "--print" ]; then
    # Placeholders keep a review from leaking real secrets.
    APP_DB_PASS="${APP_DB_PASS:-<app-password>}"
    MIGRATE_DB_PASS="${MIGRATE_DB_PASS:-<migrate-password>}"
    statements
    exit 0
fi

: "${APP_DB_PASS:?set APP_DB_PASS to the application account password}"
: "${MIGRATE_DB_PASS:?set MIGRATE_DB_PASS to the migration account password}"

admin=(mysql)
[ -n "$DB_ADMIN_USER" ] && admin+=("-u$DB_ADMIN_USER")
[ -n "$DB_ADMIN_PASS" ] && admin+=("-p$DB_ADMIN_PASS")

statements | "${admin[@]}"
echo "grants applied: $APP_USER@$APP_HOST (DML-only) and $MIGRATE_USER@$MIGRATE_HOST (DDL) on $DB_NAME"
