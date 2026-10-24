#!/bin/bash
# Back up the application database to a timestamped dump plus a manifest.
# The manifest records the git revision, per-table row counts, and live
# CHECKSUM TABLE values so a restore can prove it reproduced the backup.
# Backups contain password hashes and MFA secrets: the file is chmod 600
# and must be moved to owner-approved encrypted storage (see the runbook).
# Usage: DB_NAME=cobol_db DB_USER=cobol_user DB_PASS=cobol_pass
#        ./scripts/backup.sh [output-dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${1:-./backups}"
DB_NAME="${DB_NAME:-cobol_db}"
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"

mkdir -p "$OUT_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
STAMP="cobol-${DB_NAME}-${TS}"
SQL="$OUT_DIR/${STAMP}.sql"
MANIFEST="$OUT_DIR/${STAMP}.manifest"

# BACKUP_TABLES restricts the dump to a representative subset (the merge gate
# uses this); unset means every base table (the nightly/release path).
if [ -n "${BACKUP_TABLES:-}" ]; then
    TABLES="$BACKUP_TABLES"
else
    TABLES="$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e \
        "SELECT table_name FROM information_schema.tables
          WHERE table_schema = '$DB_NAME' AND table_type = 'BASE TABLE'
          ORDER BY table_name;" 2>/dev/null)"
fi
if [ -z "$TABLES" ]; then
    echo "backup: no base tables found for $DB_NAME" >&2
    exit 1
fi
if [ -n "${BACKUP_TABLES:-}" ]; then
    read -r -a TABLES_ARR <<< "$BACKUP_TABLES"
else
    mapfile -t TABLES_ARR <<< "$TABLES"
fi

# Retry a few times: a freshly populated InnoDB table can raise 1412
# ("Table definition has changed") under --single-transaction.
for attempt in 1 2 3 4 5; do
    if mysqldump -u "$DB_USER" -p"$DB_PASS" \
        --single-transaction --routines --triggers --events \
        --skip-disable-keys \
        --result-file="$SQL" \
        "$DB_NAME" "${TABLES_ARR[@]}" 2>/dev/null; then
        break
    fi
    sleep 1
done
chmod 600 "$SQL"

STATS="$(mktemp)"
trap 'rm -f "$STATS"' EXIT
printf '%s\n' "${TABLES_ARR[@]}" | \
    DB_NAME="$DB_NAME" DB_USER="$DB_USER" DB_PASS="$DB_PASS" \
    "$SCRIPT_DIR/db_table_stats.sh" > "$STATS"

{
    echo "backup: $STAMP"
    echo "db: $DB_NAME"
    echo "created_utc: $TS"
    echo "git_rev: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    while IFS=$'\t' read -r t row sum; do
        echo "table $t rows=$row checksum=$sum"
    done < "$STATS"
} > "$MANIFEST"
chmod 600 "$MANIFEST"

# Automatic completeness check: the manifest must cover every enumerated base
# table, so a forgotten table cannot silently drop out of a backup.
DB_TABLE_COUNT="${#TABLES_ARR[@]}"
MANIFEST_TABLE_COUNT="$(grep -c '^table ' "$MANIFEST")"
if [ "$DB_TABLE_COUNT" != "$MANIFEST_TABLE_COUNT" ]; then
    echo "manifest incomplete: db has $DB_TABLE_COUNT base tables, manifest has $MANIFEST_TABLE_COUNT" >&2
    exit 1
fi

echo "wrote $SQL"
echo "wrote $MANIFEST"
