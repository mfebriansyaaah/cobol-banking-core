#!/bin/bash
# Retain only the last N days of backups in ./backups (logical dumps + manifests).
# Usage: RETENTION_DAYS=14 scripts/backup_retention.sh
#        scripts/backup_retention.sh --print (show what would be removed)
set -e
cd "$(dirname "$0")/.."

RETENTION_DAYS="${RETENTION_DAYS:-7}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

[ -d "$BACKUP_DIR" ] || { echo "no backup dir: $BACKUP_DIR"; exit 0; }

if [ "$1" = "--print" ]; then
    find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -print
    exit 0
fi

removed=0
while IFS= read -r -d '' f; do
    rm -f "$f"
    removed=$((removed+1))
done < <(find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -print0)

echo "backup_retention: removed $removed file(s) older than $RETENTION_DAYS days"
