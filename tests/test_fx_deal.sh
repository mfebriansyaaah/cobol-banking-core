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
ADM="fxd_admin@test.com"; USR="fxd_user@test.com"
cleanup() {
    q "DELETE FROM fx_deal_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM fx_deal WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1340,'$ADM','x','FXD Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1341,'$USR','x','FXD User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  FX DEAL SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create fx deal" "SUCCESS|FXD_CREATED" \
    "$(run FXD_CREATE FXD-1 USD BUY 1000.00 15000.00 "$ADM")"
DID=$(q "SELECT id FROM fx_deal WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get fx deal" "FX_DEAL|$DID" \
    "$(run FXD_GET "$DID" '' '' '' '' "$ADM")"
check_contains "list fx deals" "$DID" \
    "$(run FXD_LIST PENDING 50 0 '' '' "$ADM")"
check "confirm fx deal" "SUCCESS|FXD_CONFIRMED" \
    "$(run FXD_CONFIRM "$DID" '' '' '' '' "$ADM")"
check "settle fx deal" "SUCCESS|FXD_SETTLED" \
    "$(run FXD_SETTLE "$DID" '' '' '' '' "$ADM")"
check_contains "fx summary" "FXD_SUMMARY|" \
    "$(run FXD_SUMMARY '' '' '' '' '' "$ADM")"
check "missing deal rejected" "ERROR|NOT_FOUND" \
    "$(run FXD_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run FXD_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
