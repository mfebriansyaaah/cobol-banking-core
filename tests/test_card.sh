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
ADM="card_admin@test.com"; USR="card_user@test.com"
cleanup() { q "DELETE FROM card_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM card_account WHERE created_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1360,'$ADM','x','CARD Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1361,'$USR','x','CARD User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  CARD SUITE (PHASE 1)"
echo "======================================================================"
setup
check "issue card" "SUCCESS|CARD_ISSUED" "$(run CARD_ISSUE CARD1 customer@test.com DEBIT 1000.00 USD "$ADM")"
CID=$(q "SELECT id FROM card_account WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get card" "CARD|$CID" "$(run CARD_GET "$CID" '' '' '' '' "$ADM")"
check_contains "list cards" "$CID" "$(run CARD_LIST ACTIVE 50 0 '' '' "$ADM")"
check "block card" "SUCCESS|CARD_BLOCKED" "$(run CARD_BLOCK "$CID" '' '' '' '' "$ADM")"
check "unblock card" "SUCCESS|CARD_UNBLOCKED" "$(run CARD_UNBLOCK "$CID" '' '' '' '' "$ADM")"
check "close card" "SUCCESS|CARD_CLOSED" "$(run CARD_CLOSE "$CID" '' '' '' '' "$ADM")"
check_contains "card summary" "CARD_SUMMARY|" "$(run CARD_SUMMARY '' '' '' '' '' "$ADM")"
check "missing card rejected" "ERROR|NOT_FOUND" "$(run CARD_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run CARD_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
