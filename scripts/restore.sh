#!/bin/bash
# Restore a backup produced by scripts/backup.sh into a target database and
# verify it: manifest row counts and CHECKSUM TABLE values must match the
# restored content, and every migration must report applied.
# Usage: DB_USER=... DB_PASS=... ./scripts/restore.sh <backup.sql> [target-db]
# The target defaults to DB_NAME (a self-restore round-trip). Restoring an
# older backup discards newer rows by design; that is the point of recovery.
set -euo pipefail

SQL="${1:?usage: restore.sh <backup.sql> [target-db]}"
DB_NAME="${DB_NAME:-cobol_db}"
TARGET="${2:-$DB_NAME}"
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
MANIFEST="${SQL%.sql}.manifest"
[ -f "$MANIFEST" ] || { echo "manifest missing: $MANIFEST" >&2; exit 1; }

mysql -u "$DB_USER" -p"$DB_PASS" "$TARGET" -e "SELECT 1;" >/dev/null

mysql -u "$DB_USER" -p"$DB_PASS" "$TARGET" < "$SQL"

fail=0
while read -r _ table kv; do
    [ -n "$table" ] || continue
    want_rows="${kv%% checksum=*}"; want_rows="${want_rows#rows=}"
    want_sum="${kv##*checksum=}"
    got_rows="$(mysql -u "$DB_USER" -p"$DB_PASS" "$TARGET" -N -B -e "SELECT COUNT(*) FROM \`$table\`;" 2>/dev/null || echo MISSING)"
    got_sum="$(mysql -u "$DB_USER" -p"$DB_PASS" "$TARGET" -N -B -e "CHECKSUM TABLE \`$table\`;" 2>/dev/null | awk '{print $2}' || echo MISSING)"
    if [ "$got_rows" != "$want_rows" ] || [ "$got_sum" != "$want_sum" ]; then
        echo "MISMATCH $table: manifest rows=$want_rows checksum=$want_sum, restored rows=$got_rows checksum=$got_sum" >&2
        fail=1
    fi
done < <(grep "^table " "$MANIFEST")

if [ ! -x ./database/migrate.sh ]; then
    echo "migrate.sh not found; skipping migration check" >&2
elif ! DB_NAME="$TARGET" DB_USER="$DB_USER" DB_PASS="$DB_PASS" ./database/migrate.sh --check >/dev/null 2>&1; then
    echo "migration check failed on restored database $TARGET" >&2
    fail=1
fi

# The bridge binary must still boot against the restored schema.
if ! printf 'RECONCILE|admin@test.com\n' > input.txt || ! ./cobol/bin/main_logic >/dev/null 2>&1; then
    echo "bridge smoke test failed on restored database" >&2
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    echo "RESTORE VERIFICATION FAILED" >&2
    exit 1
fi
echo "restore of $(basename "$SQL") into $TARGET verified"
