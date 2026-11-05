#!/usr/bin/env bash
# Migrated DB snapshot producer (CI-008A).
#
# Dumps an already-migrated database (schema.sql + database/migrate.sh applied
# by the caller, verified here with `migrate.sh --check`) into a gzip snapshot
# for the per-run `db-snapshot` CI artifact. Consumers (CI-008B) restore this
# instead of replaying 657 migrations in every DB job.
#
# Dump flags (decision D5 default): --single-transaction --routines --triggers
# only. --no-tablespaces is deliberately NOT passed: spike S1 could only
# confirm the flag exists in the MariaDB 11.8 client help text, not a live
# dump/restore round trip, so the unverified flag stays out. This also matches
# every existing in-tree dump call site (backup_restore_drill.sh,
# migration_rollback_drill.sh, run_all.sh, generate_schema_snapshot.sh).
#
# Safety model: this script performs NO destructive operation (no DROP, no
# CREATE). It only reads (migrate --check, mysqldump, table count) and writes
# the local snapshot file. System databases (mysql, performance_schema, sys,
# information_schema) are still refused: dumping them would publish credential
# hashes, not test data. cobol_db IS allowed as the dump source — it is the
# CI service database and dumping it is read-only.
#
# Usage: DB_NAME=cobol_db bash scripts/ci/build_db_snapshot.sh /tmp/cobol-snapshot.sql.gz
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-}"
DB_MIGRATE_USER="${DB_MIGRATE_USER:-}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-}"
MIGRATE_SH="${MIGRATE_SH:-$ROOT/database/migrate.sh}"

usage() {
    echo "usage: build_db_snapshot.sh <output.sql.gz>" >&2
    echo "env: DB_HOST DB_PORT DB_NAME DB_MIGRATE_USER DB_MIGRATE_PASS [MIGRATE_SH]" >&2
}

[ "$#" -eq 1 ] || { usage; exit 2; }
OUT="$1"
case "$OUT" in
    *.sql.gz) ;;
    *) echo "FAIL: output must end in .sql.gz (got: $OUT)" >&2; exit 2 ;;
esac

# Refuse empty credentials/names before touching anything (exit 2, fail closed).
[ -n "$DB_NAME" ] || { echo "FAIL: DB_NAME is required" >&2; usage; exit 2; }
[ -n "$DB_MIGRATE_USER" ] || { echo "FAIL: DB_MIGRATE_USER is required" >&2; usage; exit 2; }
[ -n "$DB_MIGRATE_PASS" ] || { echo "FAIL: DB_MIGRATE_PASS is required" >&2; usage; exit 2; }

# Refuse system databases: their dumps would carry credential hashes.
case "$DB_NAME" in
    mysql | performance_schema | sys | information_schema)
        echo "FAIL: refusing to snapshot system database '$DB_NAME'" >&2
        exit 2
        ;;
esac

echo "=== SNAPSHOT: verifying migration ledger ($DB_NAME) ==="
# env (not VAR=x prefix): forwarding outer values self-referentially trips SC2097.
env "DB_NAME=$DB_NAME" "DB_HOST=$DB_HOST" "DB_PORT=$DB_PORT" \
    "DB_MIGRATE_USER=$DB_MIGRATE_USER" "DB_MIGRATE_PASS=$DB_MIGRATE_PASS" \
    "DB_USER=$DB_MIGRATE_USER" "DB_PASS=$DB_MIGRATE_PASS" \
    "$MIGRATE_SH" --check

TMP_OUT="$OUT.tmp.$$"
cleanup() {
    rm -f "$TMP_OUT"
}
trap cleanup EXIT

echo "=== SNAPSHOT: dumping $DB_NAME ==="
mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" \
    --single-transaction --routines --triggers "$DB_NAME" 2>/dev/null | gzip > "$TMP_OUT"
[ -s "$TMP_OUT" ] || { echo "FAIL: dump is empty" >&2; exit 1; }
mv "$TMP_OUT" "$OUT"
trap - EXIT

SIZE="$(wc -c < "$OUT")"
# One-shot environment for the child query; the parent keeps its own values.
# shellcheck disable=SC2030,SC2031
TABLES="$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" \
    -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';")"
echo "snapshot bytes: $SIZE"
echo "snapshot tables: $TABLES"
[ "${TABLES:-0}" -gt 0 ] 2>/dev/null || { echo "FAIL: source has no tables" >&2; exit 1; }

echo "=== SNAPSHOT GREEN: $OUT (bytes=$SIZE tables=$TABLES source=$DB_NAME) ==="
