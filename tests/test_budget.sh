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
ADM="bud_admin@test.com"; USR="bud_user@test.com"
cleanup() { q "DELETE FROM budget_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM budget_line WHERE created_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1400,'$ADM','x','BUD Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1401,'$USR','x','BUD User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  BUDGET SUITE (PHASE 1)"
echo "======================================================================"
setup
check "save budget line" "SUCCESS|BUD_LINE_SAVED" "$(run BUD_LINE_SET BUD1 OPS 1000.00 2026 '' "$ADM")"
check_contains "list budget lines" "BUD1" "$(run BUD_LINE_LIST 50 0 '' '' '' "$ADM")"
check "spend budget" "SUCCESS|BUD_SPENT" "$(run BUD_SPEND BUD1 100.00 '' '' '' "$ADM")"
check_contains "budget summary" "BUD_SUMMARY|" "$(run BUD_SUMMARY '' '' '' '' '' "$ADM")"
check "missing budget rejected" "ERROR|NOT_FOUND" "$(run BUD_SPEND BUD9 10.00 '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run BUD_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
