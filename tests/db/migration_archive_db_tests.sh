#!/usr/bin/env bash
# Migration archive guards (maint-11): pre-baseline migrations live in
# database/migrations/archive/ and must never apply again. Fresh installs
# record them as covered; existing databases keep verifying their hashes;
# explicit version operations on archived versions fail loudly; a missing
# archived row fails the apply loop instead of silently skipping; new files
# below the baseline cutoff are rejected. Throwaway databases only, plus
# trap-safe temp files (never the repo tree, except the synthetic
# below-baseline probe which is removed by trap).
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

ARCH_DB="cobol_db_test_archive_$$"
db_require_safe_target "$ARCH_DB"
# shellcheck disable=SC2317
cleanup_dbs() {
    mysql_migrate -e "DROP DATABASE IF EXISTS \`$ARCH_DB\`;" >/dev/null 2>&1 || true
}
trap cleanup_dbs EXIT

migrate_as() { # $1=db $2...=migrate args
    env "DB_NAME=$1" "DB_HOST=${DB_HOST:-localhost}" "DB_PORT=${DB_PORT:-3306}" \
        "DB_MIGRATE_USER=${DB_MIGRATE_USER:-$DB_USER}" "DB_MIGRATE_PASS=${DB_MIGRATE_PASS:-$DB_PASS}" \
        "DB_USER=${DB_USER:-cobol_user}" "DB_PASS=${DB_PASS:-cobol_pass}" \
        "$ROOT/database/migrate.sh" "${@:2}"
}
mysql_db() { # $1=db, rest=mysql args
    local _db="$1"; shift
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_MIGRATE_USER:-$DB_USER}" -p"${DB_MIGRATE_PASS:-$DB_PASS}" \
        "$_db" "$@"
}

N_ARCHIVED="$(find "$ROOT/database/migrations/archive" -maxdepth 1 -name '*.sql' | wc -l)"
assert_match "archive holds the pre-baseline set" "$N_ARCHIVED" "^677$"
latest_archived="$(ls "$ROOT/database/migrations/archive/"*.sql | sort | tail -1 | xargs -n1 basename)"
for f in "$ROOT/database/migrations/"*.sql; do
    [ -e "$f" ] || break
    v="$(basename "$f")"
    if [ "$v" \< "$latest_archived" ]; then below="$below $v"; fi
done
assert_match "no active version below the baseline cutoff" "${below:-none}" "^none$"

mysql_migrate -e "DROP DATABASE IF EXISTS \`$ARCH_DB\`; CREATE DATABASE \`$ARCH_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null
out="$(migrate_as "$ARCH_DB" --baseline 2>&1)"; rc=$?
assert_match "fresh --baseline succeeds with archive" "$rc" "^0$"
assert_match "covered count equals archive" "$(mysql_db "$ARCH_DB" -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version <> 'baseline_v2';")" "^${N_ARCHIVED}$"
migrate_as "$ARCH_DB" --check >/dev/null 2>&1
assert_match "fresh db passes --check" "$?" "^0$"

first_archived="$(ls "$ROOT/database/migrations/archive/"*.sql | sort | head -1 | xargs -n1 basename .sql)"
out="$(migrate_as "$ARCH_DB" --only "$first_archived" 2>&1)"; rc=$?
assert_match "explicit archived --only is refused" "$rc" "^2$"
assert_match "refusal names the baseline" "$out" "baseline"
out="$(migrate_as "$ARCH_DB" --up-to "$first_archived" 2>&1)"; rc=$?
assert_match "archived --up-to is refused" "$rc" "^2$"

mysql_db "$ARCH_DB" -e "DELETE FROM schema_migrations WHERE version = '$first_archived';" >/dev/null
out="$(migrate_as "$ARCH_DB" 2>&1)"; rc=$?
assert_match "missing archived row fails loudly" "$rc" "^1$"
assert_match "failure names the version" "$out" "$first_archived"
mysql_db "$ARCH_DB" -e "INSERT INTO schema_migrations (version, checksum) VALUES ('$first_archived', '$(sha256sum "$ROOT/database/migrations/archive/$first_archived.sql" | awk "{print \$1}")');" >/dev/null
migrate_as "$ARCH_DB" >/dev/null 2>&1
assert_match "healed db applies cleanly" "$?" "^0$"

FAKE="$ROOT/database/migrations/0001_aaa_below_baseline.sql"
trap 'rm -f "$FAKE"; cleanup_dbs' EXIT
printf -- '-- fake below-baseline probe (removed by trap)\n' > "$FAKE"
out="$(migrate_as "$ARCH_DB" 2>&1)"; rc=$?
assert_match "below-baseline file is refused" "$rc" "^1$"
assert_match "refusal names the file" "$out" "0001_aaa_below_baseline"
rm -f "$FAKE"
trap cleanup_dbs EXIT

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
