#!/bin/bash
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="gpc_admin@test.com"; USR="gpc_user@test.com"
cleanup() { q "DELETE FROM gl_period_lock_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM gl_period_lock WHERE locked_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1520,'$ADM','x','GPC Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1521,'$USR','x','GPC User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  GL PERIOD CLOSE SUITE (PHASE 1)"
echo "======================================================================"
setup
check "lock period" "SUCCESS|GPC_LOCKED" "$(run GPC_LOCK 2026-10 '' '' '' '' "$ADM")"
check "unlock period" "SUCCESS|GPC_UNLOCKED" "$(run GPC_UNLOCK 2026-10 '' '' '' '' "$ADM")"
check "close period" "SUCCESS|GPC_CLOSED" "$(run GPC_CLOSE 2026-10 '' '' '' '' "$ADM")"
check "cannot close again" "ERROR|INVALID_STATUS" "$(run GPC_CLOSE 2026-10 '' '' '' '' "$ADM")"
check_contains "list periods" "2026-10" "$(run GPC_LIST '' 50 0 '' '' "$ADM")"
check_contains "period summary" "GPC_SUMMARY|" "$(run GPC_SUMMARY '' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run GPC_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
