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
ADM="lpr_admin@test.com"; USR="lpr_user@test.com"
cleanup() { q "DELETE FROM limit_profile_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM limit_profile WHERE created_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1500,'$ADM','x','LPR Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1501,'$USR','x','LPR User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  LIMIT PROFILE SUITE (PHASE 1)"
echo "======================================================================"
setup
check "set limit profile" "SUCCESS|LPR_SAVED" "$(run LPR_SET "$ADM" 1000.00 5000.00 STANDARD '' "$ADM")"
check_contains "get limit profile" "LPR_PROFILE|$ADM" "$(run LPR_GET "$ADM" '' '' '' '' "$ADM")"
check_contains "list limit profiles" "$ADM" "$(run LPR_LIST 50 0 '' '' '' "$ADM")"
check_contains "limit profile summary" "LPR_SUMMARY|" "$(run LPR_SUMMARY '' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run LPR_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
