#!/bin/bash
# Physical (MariaBackup) backup: copies raw InnoDB files for fast restore.
# Requires the mariadb-backup package and an account with BACKUP ADMIN rights
# (typically the DB admin, not the DML-only app account).
#
# Usage:
#   DB_ADMIN_USER=root DB_ADMIN_PASS=secret scripts/backup_physical.sh
#   DB_ADMIN_USER=root DB_ADMIN_PASS=secret scripts/backup_physical.sh --incremental /path/to/full
# Review without executing:
#   scripts/backup_physical.sh --print
set -e
cd "$(dirname "$0")/.."

BACKUP_ROOT="${BACKUP_ROOT:-backups/physical}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$BACKUP_ROOT/full-$STAMP"
MODE="full"

if [ "${1:-}" = "--print" ]; then
    echo "mariabackup --backup --target-dir=$BACKUP_ROOT/full-<stamp> --user=\${DB_ADMIN_USER} ..."
    exit 0
fi
if [ "${1:-}" = "--incremental" ]; then
    [ -n "${2:-}" ] || { echo "usage: $0 --incremental <full-or-incr-dir>" >&2; exit 2; }
    OUT_DIR="$BACKUP_ROOT/incr-$STAMP"
    MODE="incremental"
    INCR_BASE="$2"
fi

mkdir -p "$OUT_DIR"

ADMIN_USER="${DB_ADMIN_USER:-root}"
ADMIN_PASS="${DB_ADMIN_PASS:-}"
SOCKET="${DB_SOCKET:-/var/run/mysqld/mysqld.sock}"

ARGS=(--backup --target-dir="$OUT_DIR" --user="$ADMIN_USER")
[ -n "$ADMIN_PASS" ] && ARGS+=(--password="$ADMIN_PASS")
[ -S "$SOCKET" ] && ARGS+=(--socket="$SOCKET")
[ "$MODE" = "incremental" ] && ARGS+=(--incremental-basedir="$INCR_BASE")

echo "backup_physical: starting $MODE backup -> $OUT_DIR"
mariabackup "${ARGS[@]}"
echo "backup_physical: done ($MODE)"
