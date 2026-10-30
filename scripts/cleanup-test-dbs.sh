#!/usr/bin/env bash
# Drop orphaned throwaway test databases left by failed or killed runs.
#
# Matches ONLY these prefixes:
#   cobol_db_test_*            isolated templates from tests/run_all.sh db
#   cobol_db_shard_*           shard workers from tests/run_all.sh db
#   cobol_db_restore_drill*    restore drill targets
#
# Default is dry-run: print what would be dropped, drop nothing.
# Apply with --apply. Every candidate is re-checked against the protected-name
# guard, so a prefix change can never escalate to dropping cobol_db.
#
# --older-than N (days) keeps schemas whose newest table was created within
# the last N days. MariaDB does not record schema creation time, so the newest
# table CREATE_TIME is used as a proxy; schemas with no tables at all are
# always listed (they are failed half-built runs). Schemas whose name ends in
# the PID of a currently running process are always skipped: they may belong
# to a live run.
#
# Env: DB_HOST, DB_PORT, DB_MIGRATE_USER, DB_MIGRATE_PASS (need DROP).
# Usage:
#   scripts/cleanup-test-dbs.sh [--apply] [--older-than N] [--quiet]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
. "$ROOT/tests/lib/guard.sh"

APPLY=0
OLDER_THAN_DAYS=""
QUIET=0
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1; shift ;;
        --quiet) QUIET=1; shift ;;
        --older-than)
            [ $# -ge 2 ] || { echo "error: --older-than requires a value: --older-than N" >&2; exit 2; }
            OLDER_THAN_DAYS="$2"; shift 2 ;;
        --older-than=*)
            OLDER_THAN_DAYS="${1#--older-than=}"; shift ;;
        -h|--help)
            sed -n '1,26p' "$0"
            exit 0
            ;;
        *)
            echo "unknown argument: $1 (see --help)" >&2
            exit 2
            ;;
    esac
done
if [ -n "$OLDER_THAN_DAYS" ]; then
    case "$OLDER_THAN_DAYS" in
        ''|*[!0-9]*) echo "error: --older-than needs a non-negative integer (days)" >&2; exit 2 ;;
    esac
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_user}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_pass}"

mysql_admin() {
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$@"
}

log() {
    [ "$QUIET" = "1" ] || echo "$@"
}

# Candidate schemas: exact-prefix match only (LIKE with _ escaped).
candidates="$(mysql_admin -N -B -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'cobol\\_db\\_test\\_%' ESCAPE '\\\\' OR schema_name LIKE 'cobol\\_db\\_shard\\_%' ESCAPE '\\\\' OR schema_name LIKE 'cobol\\_db\\_restore\\_drill%' ESCAPE '\\\\' ORDER BY schema_name;" 2>/dev/null)" || {
    echo "FAIL: cannot list schemata (need DROP-capable migrate credentials)" >&2
    exit 1
}

if [ -z "$candidates" ]; then
    log "no orphaned test databases found"
    exit 0
fi

# Newest table creation time per schema (empty when the schema has no tables).
newest_table_time() {
    mysql_admin -N -B -e "SELECT COALESCE(MAX(create_time), '') FROM information_schema.tables WHERE table_schema='$1';" 2>/dev/null || echo ""
}

now_epoch="$(date +%s)"
selected=""
skipped_live=0
skipped_fresh=0
for db in $candidates; do
    # Never drop the primary or system databases, even if a prefix ever overlaps.
    if ! db_require_safe_target "$db" >/dev/null 2>&1; then
        log "SKIP (protected): $db"
        continue
    fi
    # Live-run protection: a throwaway database ends in _<pid>. Skip it while
    # that PID exists.
    pid_suffix="${db##*_}"
    case "$pid_suffix" in
        ''|*[!0-9]*) ;;
        *)
            if kill -0 "$pid_suffix" 2>/dev/null; then
                log "SKIP (live PID $pid_suffix): $db"
                skipped_live=$((skipped_live + 1))
                continue
            fi
            ;;
    esac
    if [ -n "$OLDER_THAN_DAYS" ]; then
        newest="$(newest_table_time "$db")"
        if [ -n "$newest" ]; then
            newest_epoch="$(date -d "$newest" +%s 2>/dev/null || echo "")"
            if [ -n "$newest_epoch" ]; then
                age_days=$(( (now_epoch - newest_epoch) / 86400 ))
                if [ "$age_days" -lt "$OLDER_THAN_DAYS" ]; then
                    log "SKIP (newest table ${age_days}d old): $db"
                    skipped_fresh=$((skipped_fresh + 1))
                    continue
                fi
            fi
        fi
        # No tables (or unknown time): list it, it is most likely a failed run.
    fi
    selected="$selected $db"
done

selected="$(echo "$selected" | xargs 2>/dev/null || echo "")"
if [ -z "$selected" ]; then
    log "no orphaned test databases selected (skipped live: $skipped_live, fresh: $skipped_fresh)"
    exit 0
fi

count=0
for db in $selected; do count=$((count + 1)); done
if [ "$APPLY" = "1" ]; then
    log "dropping $count database(s):"
    for db in $selected; do
        log "  DROP DATABASE \`$db\`"
        mysql_admin -e "DROP DATABASE IF EXISTS \`$db\`;" >/dev/null 2>&1 || {
            echo "FAIL: could not drop $db" >&2
            exit 1
        }
    done
    log "dropped $count database(s)"
else
    log "dry-run: $count database(s) would be dropped (re-run with --apply):"
    for db in $selected; do
        log "  $db"
    done
fi
