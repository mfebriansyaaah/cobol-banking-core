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
ADM="shl_admin@test.com"; USR="shl_user@test.com"
cleanup() { q "DELETE FROM sanctions_hold_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM sanctions_hold WHERE created_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1480,'$ADM','x','SHL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1481,'$USR','x','SHL User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  SANCTIONS HOLD SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create sanctions hold" "SUCCESS|SHL_HOLD_CREATED" "$(run SHL_HOLD_CREATE customer@test.com 'PEP hit' 'detail' '' '' "$ADM")"
HID=$(q "SELECT id FROM sanctions_hold WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list sanctions holds" "$HID" "$(run SHL_HOLD_LIST ACTIVE 50 0 '' '' "$ADM")"
check "release sanctions hold" "SUCCESS|SHL_RELEASED" "$(run SHL_HOLD_RELEASE "$HID" '' '' '' '' "$ADM")"
check "cannot release again" "ERROR|INVALID_STATUS" "$(run SHL_HOLD_RELEASE "$HID" '' '' '' '' "$ADM")"
check_contains "sanctions summary" "SHL_SUMMARY|" "$(run SHL_SUMMARY '' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run SHL_SUMMARY '' '' '' '' '' "$USR")"
check "sanctions audit rows recorded" "1" "$(q "SELECT COUNT(*) FROM sanctions_hold_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('HOLD_CREATE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
