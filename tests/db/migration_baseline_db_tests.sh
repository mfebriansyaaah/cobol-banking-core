#!/usr/bin/env bash
# Baseline v2 tests (maint-10): fresh installs apply schema_v2.sql once and
# record every covered migration as skipped; existing databases verify clean
# before the baseline marker lands; partial databases fail loudly; the
# committed baseline is byte-identical to the build output. Operates only on
# throwaway databases (guarded names) plus the committed files (trap-safe
# restore for the tamper probe), so the runner database is untouched.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/guard.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

FRESH_DB="cobol_db_test_baseline_fresh_$$"
PART_DB="cobol_db_test_baseline_part_$$"
db_require_safe_target "$FRESH_DB"
db_require_safe_target "$PART_DB"
# Invoked only via `trap ... EXIT`, which shellcheck cannot trace.
# shellcheck disable=SC2317
cleanup_dbs() {
    mysql_migrate -e "DROP DATABASE IF EXISTS \`$FRESH_DB\`;" >/dev/null 2>&1 || true
    mysql_migrate -e "DROP DATABASE IF EXISTS \`$PART_DB\`;" >/dev/null 2>&1 || true
}
trap cleanup_dbs EXIT

migrate_as() { # $1=db $2...=migrate args; env (not VAR=x) avoids SC2097
    env "DB_NAME=$1" "DB_HOST=${DB_HOST:-localhost}" "DB_PORT=${DB_PORT:-3306}" \
        "DB_MIGRATE_USER=${DB_MIGRATE_USER:-$DB_USER}" "DB_MIGRATE_PASS=${DB_MIGRATE_PASS:-$DB_PASS}" \
        "DB_USER=${DB_USER:-cobol_user}" "DB_PASS=${DB_PASS:-cobol_pass}" \
        "$ROOT/database/migrate.sh" "${@:2}"
}
mysql_db() { # $1=db, rest=mysql args; positional db selects the database
    local _db="$1"; shift
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_MIGRATE_USER:-$DB_USER}" -p"${DB_MIGRATE_PASS:-$DB_PASS}" \
        "$_db" "$@"
}
db_tables() { # $1=db -> table count
    mysql_migrate -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$1' AND table_type='BASE TABLE';" 2>/dev/null
}
db_routines() { # $1=db -> routines+triggers count
    mysql_migrate -N -B -e "SELECT (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='$1') + (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='$1');" 2>/dev/null
}

LIVE_TABLES="$(db_tables "${DB_NAME:-cobol_db}")"
LIVE_ROUTINES="$(db_routines "${DB_NAME:-cobol_db}")"
N_MIGRATIONS="$(ls "$ROOT/database/migrations/"*.sql | wc -l)"

# 1-7. Fresh install: baseline snapshot applies once, everything recorded.
mysql_migrate -e "DROP DATABASE IF EXISTS \`$FRESH_DB\`; CREATE DATABASE \`$FRESH_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null
out="$(migrate_as "$FRESH_DB" --baseline 2>&1)"; rc=$?
assert_match "fresh --baseline succeeds" "$rc" "^0$"
assert_match "marker recorded" "$(mysql_migrate -N -B -e "SELECT COUNT(*) FROM \`$FRESH_DB\`.schema_migrations WHERE version='baseline_v2';" 2>/dev/null)" "^1$"
assert_match "covered versions recorded" "$(mysql_migrate -N -B -e "SELECT COUNT(*) FROM \`$FRESH_DB\`.schema_migrations WHERE version <> 'baseline_v2';" 2>/dev/null)" "^${N_MIGRATIONS}$"
assert_match "table count matches live" "$(db_tables "$FRESH_DB")" "^${LIVE_TABLES}$"
assert_match "routine count matches live" "$(db_routines "$FRESH_DB")" "^${LIVE_ROUTINES}$"
migrate_as "$FRESH_DB" --check >/dev/null 2>&1
assert_match "fresh db passes --check" "$?" "^0$"
assert_match "second --baseline is a no-op" "$(migrate_as "$FRESH_DB" --baseline 2>&1)" "already baselined"

# 8-13. Partial database fails loudly; completing it heals, with no data loss.
mysql_migrate -e "DROP DATABASE IF EXISTS \`$PART_DB\`; CREATE DATABASE \`$PART_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null
mysql_db "$PART_DB" < "$ROOT/database/schema.sql" >/dev/null
migrate_as "$PART_DB" --up-to 0200_digital_asset >/dev/null 2>&1
out="$(migrate_as "$PART_DB" --baseline 2>&1)"; rc=$?
assert_match "partial --baseline fails" "$rc" "^1$"
assert_match "failure names pending work" "$out" "cannot baseline a partially-migrated database"
mysql_migrate -e "INSERT INTO \`$PART_DB\`.users (email, password_hash, full_name, dob) VALUES ('probe@test.com', 'x', 'Probe', '1990-01-01');" >/dev/null 2>&1
migrate_as "$PART_DB" >/dev/null 2>&1
out="$(migrate_as "$PART_DB" --baseline 2>&1)"; rc=$?
assert_match "completed upgrade baselines" "$rc" "^0$"
assert_match "probe row survived upgrade" "$(mysql_migrate -N -B -e "SELECT COUNT(*) FROM \`$PART_DB\`.users WHERE email='probe@test.com';" 2>/dev/null)" "^1$"
migrate_as "$PART_DB" --check >/dev/null 2>&1
assert_match "upgraded db passes --check" "$?" "^0$"

# 14-16. Tampering with the baseline snapshot trips --check; restore heals.
BASELINE_FILE="$ROOT/database/schema_v2.sql"
BACKUP="$(mktemp "${TMPDIR:-/tmp}/baseline-probe.XXXXXX.sql")"
cp "$BASELINE_FILE" "$BACKUP"
trap 'cp "$BACKUP" "$BASELINE_FILE"; rm -f "$BACKUP"; cleanup_dbs' EXIT
echo "-- probe" >> "$BASELINE_FILE"
out="$(migrate_as "$FRESH_DB" --check 2>&1)"; rc=$?
assert_match "edited baseline fails --check" "$rc" "^1$"
assert_match "failure names the baseline" "$out" "baseline_v2"
cp "$BACKUP" "$BASELINE_FILE"
migrate_as "$FRESH_DB" --check >/dev/null 2>&1
assert_match "restored baseline passes --check" "$?" "^0$"
trap cleanup_dbs EXIT

# 17. Committed baseline is byte-identical to the committed full snapshot
# (Wave-C made no schema change; the drift gate proves build-equality in CI).
assert_match "schema_v2 body equals schema_full body" "$(diff -u <(grep -v "^-- GENERATED\|^-- Regenerate\|^-- Source" "$ROOT/database/schema_v2.sql") <(grep -v "^-- GENERATED\|^-- Regenerate\|^-- Source" "$ROOT/database/schema_full.sql") | wc -l)" "^0$"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
