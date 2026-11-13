#!/usr/bin/env bash
# Migration checksum tests: the tamper-evident ledger (P1-4) must notice when
# an applied migration file changes and must heal through --backfill-checksums.
# Operates on the runner's database (already migrated) and restores every file
# and row it touches, so the suite leaves no trace. One assertion line per
# check so the static counter equals the runtime total.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

PROBE_VERSION="0666_schema_migrations_checksum"
# Post-PR-011 the file lives in the archive (still applied + checksummed).
PROBE_FILE="$ROOT/database/migrations/archive/$PROBE_VERSION.sql"
BACKUP="$(mktemp "${TMPDIR:-/tmp}/checksum-probe.XXXXXX.sql")"
cp "$PROBE_FILE" "$BACKUP"
# Invoked only via `trap ... EXIT`, which shellcheck cannot trace.
# shellcheck disable=SC2317
restore_probe() {
    cp "$BACKUP" "$PROBE_FILE"
    mysql_migrate -e "UPDATE schema_migrations SET checksum = '$(sha256sum "$PROBE_FILE" | awk '{print $1}')' WHERE version = '$PROBE_VERSION';" >/dev/null 2>&1 || true
    rm -f "$BACKUP"
}
trap restore_probe EXIT

migrate_here() {
    # env (not VAR=x prefix): forwarding outer values self-referentially trips SC2097.
    env "DB_NAME=${DB_NAME:-cobol_db}" "DB_HOST=${DB_HOST:-localhost}" "DB_PORT=${DB_PORT:-3306}" \
        "DB_MIGRATE_USER=${DB_MIGRATE_USER:-$DB_USER}" "DB_MIGRATE_PASS=${DB_MIGRATE_PASS:-$DB_PASS}" \
        "DB_USER=${DB_USER:-cobol_user}" "DB_PASS=${DB_PASS:-cobol_pass}" \
        "$ROOT/database/migrate.sh" "$@"
}

migrate_here --check >/dev/null 2>&1
assert_match "untampered tree passes --check" "$?" "^0$"

echo "-- probe" >> "$PROBE_FILE"
out="$(migrate_here --check 2>&1)"; rc=$?
assert_match "edited applied file fails --check" "$rc" "^1$"
assert_match "failure names the edited version" "$out" "$PROBE_VERSION"
cp "$BACKUP" "$PROBE_FILE"

mysql_migrate -e "UPDATE schema_migrations SET checksum = NULL WHERE version = '$PROBE_VERSION';" >/dev/null 2>&1
out="$(migrate_here --check 2>&1)"; rc=$?
assert_match "missing checksum fails --check" "$rc" "^1$"
migrate_here --backfill-checksums >/dev/null 2>&1
migrate_here --check >/dev/null 2>&1
assert_match "backfill heals --check" "$?" "^0$"

migrate_here --up-to no_such_version >/dev/null 2>&1
assert_match "unknown --up-to version exits 2" "$?" "^2$"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
