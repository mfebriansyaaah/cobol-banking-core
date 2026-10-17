#!/bin/bash
# Migration tooling suite: runner is idempotent and --check detects pending work.
# Usage: ./tests/test_migrate.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q(){ mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
check(){ if [ "$2" = "$3" ]; then echo -e "${GREEN}PASS${NC} $1"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $1 (expected [$2] got [$3])"; failed=$((failed+1)); fi; }
echo "======================================================================"
echo "  MIGRATION TOOLING SUITE"
echo "======================================================================"

# --- failing migration: loud, attributed, and unrecorded -----------------
TMP_MIGRATION="database/migrations/9999_zz_tmp_fail.sql"
trap 'rm -f "$TMP_MIGRATION"' EXIT
echo "THIS IS NOT VALID SQL;" > "$TMP_MIGRATION"
fail_out="$(./database/migrate.sh 2>&1; echo "rc=$?")"
if echo "$fail_out" | grep -q "migration FAILED: 9999_zz_tmp_fail" && echo "$fail_out" | grep -q "rc=[1-9]"; then
    check "failing migration aborts with attribution" "loud" "loud"
else
    check "failing migration aborts with attribution" "loud" "quiet rc=$? out: $(echo "$fail_out" | tail -2 | tr '\n' ' ')"
fi
check "failed migration is not recorded" "0" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='9999_zz_tmp_fail';")"
rm -f "$TMP_MIGRATION"
trap - EXIT

./database/migrate.sh >/dev/null 2>&1
check "all migration files recorded" "$(ls database/migrations/*.sql | wc -l | tr -d ' ')" "$(q "SELECT COUNT(*) FROM schema_migrations;")"
check "re-run is idempotent" "no pending migrations" "$(./database/migrate.sh 2>&1 | tail -1)"
check "check passes when applied" "0" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
q "DELETE FROM schema_migrations WHERE version='0001_pending_transactions_cascade';"
check "check fails when pending" "1" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
./database/migrate.sh >/dev/null 2>&1
check "reapplied after pending" "1" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='0001_pending_transactions_cascade';")"
check "check green after apply" "0" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
check "users.balance/verification_code dropped" "0" "$(q "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$DB_NAME' AND table_name='users' AND column_name IN ('balance','verification_code');")"
check "exchange_rates table present (FX)" "1" "$(q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='exchange_rates';")"
check "FX pair lookup index present" "1" "$(q "SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics WHERE table_schema='$DB_NAME' AND table_name='exchange_rates' AND index_name='idx_exchange_lookup';")"

# --- migration baseline (fresh installs start from schema.sql) ------------
base_list="$(grep -oE "'00[0-9]{2}_[a-z0-9_]+'" database/schema.sql | tr -d "'" | sort -u)"
file_list="$(for f in database/migrations/*.sql; do basename "$f" .sql; done | sort -u)"
check "baseline lists every migration file" "$file_list" "$base_list"
orphans="$(q "SELECT version FROM schema_migrations;" | sort -u | comm -23 - <(echo "$file_list"))"
check "no orphan migration records" "" "$orphans"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
