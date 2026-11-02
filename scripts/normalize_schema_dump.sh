#!/usr/bin/env bash
# Normalize a mysqldump --no-data stream so schema snapshots and drift checks
# are deterministic across mysqldump versions: strip DEFINER clauses
# (user@host varies), AUTO_INCREMENT counters, the concrete throwaway
# database name, and dump-client boilerplate (banner, server version, and the
# NOTE_VERBOSITY/SQL_NOTES session lines, whose spelling depends on the
# client release). Reads stdin, writes stdout. Idempotent: normalizing twice
# changes nothing.
# Usage: mysqldump ... | bash scripts/normalize_schema_dump.sh [db-name]
set -euo pipefail
DB_NAME="${1:-${SNAP_DB:-}}"
if [ -n "$DB_NAME" ]; then
    # Backticks are literal here: they match DEFINER=`user`@`host` clauses in
    # dump output, nothing is executed (SC2016 does not apply).
    # shellcheck disable=SC2016
    sed -e 's/DEFINER=`[^`]*`@`[^`]*`//g' -e 's/ AUTO_INCREMENT=[0-9]*//g' \
        -e "s/${DB_NAME}/SNAPSHOT_DB/g" \
        -e '/^-- MariaDB dump/d' -e '/^-- Host:/d' -e '/^-- Server version/d' \
        -e '/NOTE_VERBOSITY/d' -e '/SQL_NOTES/d' \
        -e '/^END $/{N;s/END \n\*\/;;/END *\/;;/}'
else
    # Backticks are literal here: they match DEFINER=`user`@`host` clauses in
    # dump output, nothing is executed (SC2016 does not apply).
    # shellcheck disable=SC2016
    sed -e 's/DEFINER=`[^`]*`@`[^`]*`//g' -e 's/ AUTO_INCREMENT=[0-9]*//g' \
        -e '/^-- MariaDB dump/d' -e '/^-- Host:/d' -e '/^-- Server version/d' \
        -e '/NOTE_VERBOSITY/d' -e '/SQL_NOTES/d' \
        -e '/^END $/{N;s/END \n\*\/;;/END *\/;;/}'
fi
