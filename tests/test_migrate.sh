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
./database/migrate.sh >/dev/null 2>&1
check "all migration files recorded" "$(ls database/migrations/*.sql | wc -l | tr -d ' ')" "$(q "SELECT COUNT(*) FROM schema_migrations;")"
check "re-run is idempotent" "no pending migrations" "$(./database/migrate.sh 2>&1 | tail -1)"
check "check passes when applied" "0" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
q "DELETE FROM schema_migrations WHERE version='0001_pending_transactions_cascade';"
check "check fails when pending" "1" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
./database/migrate.sh >/dev/null 2>&1
check "reapplied after pending" "1" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='0001_pending_transactions_cascade';")"
check "check green after apply" "0" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
