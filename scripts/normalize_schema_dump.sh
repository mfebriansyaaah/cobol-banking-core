#!/usr/bin/env bash
# Normalize a mysqldump --no-data stream so schema snapshots and drift checks
# are deterministic: strip DEFINER clauses (user@host varies), AUTO_INCREMENT
# counters, and the concrete throwaway database name. Reads stdin, writes
# stdout. Idempotent: normalizing twice changes nothing.
# Usage: mysqldump ... | bash scripts/normalize_schema_dump.sh [db-name]
set -euo pipefail
DB_NAME="${1:-${SNAP_DB:-}}"
if [ -n "$DB_NAME" ]; then
    sed -e 's/DEFINER=`[^`]*`@`[^`]*`//g' -e 's/ AUTO_INCREMENT=[0-9]*//g' \
        -e "s/${DB_NAME}/SNAPSHOT_DB/g"
else
    sed -e 's/DEFINER=`[^`]*`@`[^`]*`//g' -e 's/ AUTO_INCREMENT=[0-9]*//g'
fi
