#!/usr/bin/env bash
# Snapshot-based migration rollback drill (P1-4): prove the database can be
# returned to the previous migration version, with data intact.
# Applies migrations up to N-1 into a throwaway database, snapshots it,
# applies N, restores the snapshot, then verifies the ledger and a marker row
# are back at N-1 (and that migrate.sh --check reports exactly N pending).
# This replaces the old apply-twice idempotency drill: re-applying never
# proved anything could go BACKWARD.
#
# The drill target comes ONLY from ROLLBACK_DRILL_DB (default
# cobol_db_rollback_drill). Protected names are refused before any DROP.
# Usage: bash scripts/ci/migration_rollback_drill.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
. "$ROOT/tests/lib/guard.sh"

ROLLBACK_DRILL_DB="${ROLLBACK_DRILL_DB:-cobol_db_rollback_drill}"
db_require_safe_target "$ROLLBACK_DRILL_DB"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_pass}"

versions="$(cd database/migrations && printf '%s\n' *.sql | sed 's/\.sql$//' | sort)"
N="$(echo "$versions" | tail -1)"
PREV="$(echo "$versions" | tail -2 | head -1)"
if [ -z "$N" ] || [ -z "$PREV" ] || [ "$N" = "$PREV" ]; then
    echo "FAIL: need at least two migrations" >&2
    exit 2
fi
echo "=== ROLLBACK DRILL: $PREV <- $N (target: $ROLLBACK_DRILL_DB) ==="

migrate_here() {
    # env (not VAR=x prefix): forwarding outer values self-referentially trips SC2097.
    env "DB_NAME=$ROLLBACK_DRILL_DB" "DB_HOST=$DB_HOST" "DB_PORT=$DB_PORT" \
        "DB_MIGRATE_USER=$DB_MIGRATE_USER" "DB_MIGRATE_PASS=$DB_MIGRATE_PASS" \
        "DB_USER=$DB_MIGRATE_USER" "DB_PASS=$DB_MIGRATE_PASS" \
        ./database/migrate.sh "$@"
}
drill() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$ROLLBACK_DRILL_DB" "$@"; }
admin() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$@"; }

SNAP="$(mktemp "${TMPDIR:-/tmp}/rollback-drill.XXXXXX.sql")"
cleanup() {
    admin -e "DROP DATABASE IF EXISTS \`$ROLLBACK_DRILL_DB\`;" >/dev/null 2>&1 || true
    rm -f "$SNAP"
}
trap cleanup EXIT

echo "--- step 1: build at $PREV ---"
admin -e "DROP DATABASE IF EXISTS \`$ROLLBACK_DRILL_DB\`; CREATE DATABASE \`$ROLLBACK_DRILL_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$ROLLBACK_DRILL_DB" < database/schema.sql
migrate_here --up-to "$PREV" > /dev/null
[ "$(drill -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version = '$N';")" = "0" ] \
    || { echo "FAIL: $N already applied at snapshot time" >&2; exit 1; }

echo "--- step 2: marker row + snapshot ---"
drill -e "CREATE TABLE drill_marker (id INT PRIMARY KEY, note VARCHAR(64)); INSERT INTO drill_marker VALUES (1, 'rollback-$PREV');"
mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" \
    --single-transaction --routines --triggers "$ROLLBACK_DRILL_DB" > "$SNAP" 2>/dev/null
[ -s "$SNAP" ] || { echo "FAIL: snapshot is empty" >&2; exit 1; }

echo "--- step 3: apply $N ---"
migrate_here > /dev/null
[ "$(drill -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version = '$N';")" = "1" ] \
    || { echo "FAIL: $N did not apply" >&2; exit 1; }

echo "--- step 4: restore snapshot ---"
admin -e "DROP DATABASE \`$ROLLBACK_DRILL_DB\`; CREATE DATABASE \`$ROLLBACK_DRILL_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
drill < "$SNAP"

echo "--- step 5: verify rollback to $PREV ---"
[ "$(drill -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version = '$N';")" = "0" ] \
    || { echo "FAIL: $N still recorded after restore" >&2; exit 1; }
[ "$(drill -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version = '$PREV';")" = "1" ] \
    || { echo "FAIL: $PREV missing after restore" >&2; exit 1; }
[ "$(drill -N -B -e "SELECT note FROM drill_marker WHERE id = 1;")" = "rollback-$PREV" ] \
    || { echo "FAIL: marker row lost in restore" >&2; exit 1; }
if migrate_here --check > /dev/null 2>&1; then
    echo "FAIL: --check passes after rollback (expected $N pending)" >&2
    exit 1
fi
pending="$(migrate_here --check 2>&1 || true)"
case "$pending" in
    *"$N"*) echo "ledger back at $PREV (pending: $N)" ;;
    *) echo "FAIL: pending is not $N: $pending" >&2; exit 1 ;;
esac

echo "=== ROLLBACK DRILL GREEN (restored to $PREV, marker intact) ==="
