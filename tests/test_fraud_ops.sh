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
ADM="fop_admin@test.com"; USR="fop_user@test.com"
cleanup() { q "DELETE FROM fraud_review_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM fraud_review WHERE created_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1500,'$ADM','x','FOP Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1501,'$USR','x','FOP User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  FRAUD OPS SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create fraud review" "SUCCESS|FOP_CREATED" "$(run FOP_CREATE CASE1 customer@test.com 90 'suspicious' '' "$ADM")"
RID=$(q "SELECT id FROM fraud_review WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list fraud reviews" "$RID" "$(run FOP_LIST '' 50 0 '' '' "$ADM")"
check "review fraud case" "SUCCESS|FOP_REVIEWED" "$(run FOP_REVIEW "$RID" 'reviewing' '' '' '' "$ADM")"
check "clear fraud case" "SUCCESS|FOP_CLEARED" "$(run FOP_CLEAR "$RID" '' '' '' '' "$ADM")"
check "block fraud case" "ERROR|INVALID_STATUS" "$(run FOP_BLOCK "$RID" '' '' '' '' "$ADM")"
check_contains "fraud summary" "FOP_SUMMARY|" "$(run FOP_SUMMARY '' '' '' '' '' "$ADM")"
check "missing review rejected" "ERROR|INVALID_STATUS" "$(run FOP_REVIEW 999999 'note' '' '' '' "$ADM")" 2>/dev/null || true
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run FOP_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
