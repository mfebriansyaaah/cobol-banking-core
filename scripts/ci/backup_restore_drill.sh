#!/usr/bin/env bash
# Logical backup and restore drill with DATA verification (P1-4).
# Dumps the database under test, restores the dump into a throwaway database,
# and proves the restore carries the data: every table's row count must match
# and CHECKSUM TABLE on key tables must agree. migrate.sh --check must also
# pass on the restored copy (the migration ledger survived the round trip).
# Unlike scripts/ci/restore_drill.sh (schema rebuild only: no backup file is
# involved there), this drill proves a dump actually restores data.
#
# The drill target comes ONLY from RESTORE_DRILL_DB (default
# cobol_db_restore_drill); DB_NAME selects the SOURCE and is never dropped.
# Protected names are refused before any DROP (see tests/lib/guard.sh).
# Usage: DB_NAME=cobol_db bash scripts/ci/backup_restore_drill.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
. "$ROOT/tests/lib/guard.sh"

RESTORE_DRILL_DB="${RESTORE_DRILL_DB:-cobol_db_restore_drill}"
db_require_safe_target "$RESTORE_DRILL_DB"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-cobol_db}"
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_pass}"

# Key tables whose CONTENT must be identical (counts alone miss same-size
# swaps). All exist from the baseline schema; row-count comparison covers
# every table anyway.
KEY_TABLES="users accounts ledger schema_migrations currencies exchange_rates verification_logs"

src() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$DB_NAME" "$@"; }
dst() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$RESTORE_DRILL_DB" "$@"; }
admin() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$@"; }

DUMP="$(mktemp "${TMPDIR:-/tmp}/backup-drill.XXXXXX.sql")"
cleanup() {
    admin -e "DROP DATABASE IF EXISTS \`$RESTORE_DRILL_DB\`;" >/dev/null 2>&1 || true
    rm -f "$DUMP"
}
trap cleanup EXIT

echo "=== BACKUP: $DB_NAME -> $DUMP ==="
mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" \
    --single-transaction --routines --triggers "$DB_NAME" > "$DUMP" 2>/dev/null
[ -s "$DUMP" ] || { echo "FAIL: dump is empty" >&2; exit 1; }
echo "dump bytes: $(wc -c < "$DUMP")"

echo "=== RESTORE: $DUMP -> $RESTORE_DRILL_DB ==="
admin -e "DROP DATABASE IF EXISTS \`$RESTORE_DRILL_DB\`; CREATE DATABASE \`$RESTORE_DRILL_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
dst < "$DUMP"

echo "=== VERIFY: row counts (every table) ==="
tables="$(src -N -B -e "SELECT table_name FROM information_schema.tables WHERE table_schema = '$DB_NAME' AND table_type = 'BASE TABLE' ORDER BY table_name;")"
[ -n "$tables" ] || { echo "FAIL: source has no tables" >&2; exit 1; }
drift=0
for t in $tables; do
    a="$(src -N -B -e "SELECT COUNT(*) FROM \`$t\`;" 2>/dev/null || echo "?")"
    b="$(dst -N -B -e "SELECT COUNT(*) FROM \`$t\`;" 2>/dev/null || echo "?")"
    if [ "$a" != "$b" ]; then
        echo "MISMATCH row count $t: source=$a restored=$b"
        drift=1
    fi
done
[ "$drift" = "0" ] || { echo "FAIL: row counts differ" >&2; exit 1; }
echo "row counts match ($(echo "$tables" | wc -w) tables)"

echo "=== VERIFY: checksums (key tables) ==="
for t in $KEY_TABLES; do
    a="$(src -N -B -e "CHECKSUM TABLE \`$t\`;" 2>/dev/null | awk '{print $2}')"
    b="$(dst -N -B -e "CHECKSUM TABLE \`$t\`;" 2>/dev/null | awk '{print $2}')"
    if [ -z "$a" ] || [ "$a" != "$b" ]; then
        echo "MISMATCH checksum $t: source=$a restored=$b"
        drift=1
    fi
done
[ "$drift" = "0" ] || { echo "FAIL: checksums differ" >&2; exit 1; }
echo "checksums match ($KEY_TABLES)"

echo "=== VERIFY: migration ledger ==="
# env (not VAR=x prefix): forwarding outer values self-referentially trips SC2097.
env "DB_NAME=$RESTORE_DRILL_DB" "DB_HOST=$DB_HOST" "DB_PORT=$DB_PORT" \
    "DB_MIGRATE_USER=$DB_MIGRATE_USER" "DB_MIGRATE_PASS=$DB_MIGRATE_PASS" \
    "DB_USER=$DB_MIGRATE_USER" "DB_PASS=$DB_MIGRATE_PASS" \
    ./database/migrate.sh --check

# One-shot environment for the child script: the parent keeps its own
# values (e.g. $DB_NAME still names the source below), so the subshell
# export is intentional, not a lost modification.
# shellcheck disable=SC2030,SC2031
echo "=== BACKUP/RESTORE DRILL GREEN (source: $DB_NAME, restored: $RESTORE_DRILL_DB) ==="
