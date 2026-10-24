#!/bin/bash
# Emit "table<TAB>rows<TAB>checksum" for every table name read on stdin.
#
# Backup and restore both need the same two measurements per table. Asking the
# server one table at a time spawns two mysql clients per table (~900 for the
# current 454-table schema); this batches them into one COUNT/UNION query and
# one CHECKSUM TABLE statement per chunk, so verification drops from minutes
# to seconds without changing what is compared.
#
# Usage: printf '%s\n' "${TABLES[@]}" | DB_NAME=... ./scripts/db_table_stats.sh
set -euo pipefail

DB_NAME="${DB_NAME:-cobol_db}"
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
CHUNK="${CHUNK:-100}"

mysqlc() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B "$@"; }

mapfile -t TABLES < <(grep -v '^$' || true)
[ "${#TABLES[@]}" -gt 0 ] || exit 0

declare -A ROWS=() SUMS=()
for ((i = 0; i < ${#TABLES[@]}; i += CHUNK)); do
    chunk=("${TABLES[@]:i:CHUNK}")

    query=""
    for t in "${chunk[@]}"; do
        [ -n "$query" ] && query+=" UNION ALL "
        query+="SELECT '$t' AS t, COUNT(*) AS c FROM \`$t\`"
    done
    while IFS=$'\t' read -r t c; do
        [ -n "$t" ] && ROWS[$t]="$c"
    done < <(mysqlc -e "$query;")

    query="CHECKSUM TABLE "
    for t in "${chunk[@]}"; do
        query+="\`$t\`,"
    done
    query="${query%,}"
    # CHECKSUM TABLE returns qualified names ("db.table"); keep the leaf name.
    while IFS=$'\t' read -r full sum; do
        [ -n "$full" ] && SUMS[${full#*.}]="$sum"
    done < <(mysqlc -e "$query;")
done

for t in "${TABLES[@]}"; do
    printf '%s\t%s\t%s\n' "$t" "${ROWS[$t]:-MISSING}" "${SUMS[$t]:-MISSING}"
done
